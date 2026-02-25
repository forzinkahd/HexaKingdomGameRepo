class_name VoxelGenerator

var map : Array[Voxel]
var map_dict : Dictionary[Vector3i, Voxel]
const sides = 6
var settings : GenerationSettings
var surface_voxels : Array[Voxel]
var theme: WorldTheme					# 1.2.2026

var _road_by_xz: Dictionary = {}
var _river_by_xz: Dictionary = {}
var _has_mountain_by_xz: Dictionary = {}

const ATLAS_RES   = Vector2i(512, 512)	# full atlas resolution in pixels
const TILE_SIZE   = Vector2i(16, 16)	# usable area of one tile
const TILE_STRIDE = Vector2i(18, 18)	# includes padding
const TILE_MARGIN = Vector2i(5, 5)		# margin before first tile, always +1 of the actual padded border

# Define base hexagon
const base_vertices = [
	Vector3(0.5, 0.0, -0.866),  # Left
	Vector3(1.0, 0.0, 0.0),  # Top-right
	Vector3(0.5, 0.0, 0.866),  # Bottom-right
	Vector3(-0.5, 0.0, 0.866),  # Bottom-left
	Vector3(-1.0, 0.0, 0.0),  # Left
	Vector3(-0.5, 0.0, -0.866)  # Top-left
	]


func generate_chunk(_map : Array[Voxel], interval) -> Chunk:
	
	surface_voxels.clear()
	map_dict.clear() # good hygiene, avoids stale lookups
	
	map = _map
	settings = WorldMap.world_settings
	var verts = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	
	var process_vector = process_voxels()
	print("Correction passes: ", process_vector.x, ". Total voxels removed: ", process_vector.y)
	interval["Processing Voxels total -- "] = Time.get_ticks_msec()
	
	for voxel in map:
		assign_type(voxel)
		var prism = build_hex_prism(voxel)
		var v_offset = verts.size() # start at last indice to not overwrite old ones
		verts.append_array(prism.verts)
		uvs.append_array(prism.uvs)
		for indice in prism.indices:
			indices.append(indice + v_offset)

	interval["Build voxels -- "] = Time.get_ticks_msec()

	## Create surface
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for v_index in range(verts.size()):
		surface.set_uv(uvs[v_index])
		surface.set_smooth_group(settings.shading)
		surface.add_vertex(verts[v_index])

	for i in indices:
		surface.add_index(i)

	surface.optimize_indices_for_cache()
	surface.generate_normals()
	surface.generate_tangents()
	_build_xz_lookup()
	WorldMap.set_map(map, surface_voxels)
	
	return prepared_chunk(surface)


func prepared_chunk(surface) -> Chunk:
	var chunk = Chunk.new()
	chunk.mesh = surface.commit()
	chunk.voxels = map
	chunk.material_override = settings.material
	
	chunk.set_meta("voxel_generator", self)		# debug
	
	var surface_tiles: Array[Voxel] = _build_surface_from_map()
	surface_voxels = surface_tiles
	WorldMap.set_map(map, surface_voxels)
	print("Surface voxels:", surface_voxels.size(), " total voxels:", map.size())
	
	# Spawn custom visuals
	_spawn_columns(chunk)		# bottom geometry
	_spawn_surface_tiles(chunk)	# top caps
	_spawn_mountains(chunk)
	_spawn_forests(chunk)
	
	return chunk


func process_voxels() -> Vector2i:
	# Prepare counters
	var passes = 0
	var total_removed = 0
	
	for voxel in map: # do this once
		normalize_voxel_noise(voxel)
		assign_air_probability(voxel)
		map_dict[voxel.grid_position_xyz] = voxel
	
	while passes < 20:
		var removed = 0
		for i in range(map.size()):
			var voxel = map[i]
			if voxel.type != VoxelData.voxel_type.AIR:
				if shape_geometry(voxel):
					removed += 1
		if removed < 1:
			break
		total_removed += removed
		passes += 1
	
	return Vector2i(passes, total_removed)


func normalize_voxel_noise(voxel: Voxel):
	# Normalize noise to [0,1] based on min/max
	var n = voxel.noise
	var min_n = WorldMap.noise_range.x
	var max_n = WorldMap.noise_range.y
	var normalized = clamp((n - min_n) / (max_n - min_n), 0.0, 0.9999)
	voxel.noise = normalized


func assign_air_probability(voxel: Voxel) -> void:
	var noise_contribution : float = voxel.noise
	var y : float = voxel.grid_position_xyz.y
	var normalized_height : float = clampf(y / settings.max_height, 0.0, 1.0)

	var combined_probability : float = (1.0 - settings.noise_height_bias) * noise_contribution \
									 + settings.noise_height_bias * normalized_height
	voxel.air_probability = clampf(combined_probability, 0.0, 1.0)


func shape_geometry(prism) -> bool:
	# Ensure solid first layer
	if settings.solid_first_layer and prism.grid_position_xyz.y == 0:
		prism.type = VoxelData.voxel_type.BEDROCK
		return false
	
	# Convert to air
	if prism.air_probability > settings.ground_to_air_ratio:
		prism.type = VoxelData.voxel_type.AIR
		return true
	
	# Flatten buffer
	if prism.buffer and settings.flat_buffer:
		prism.type = VoxelData.voxel_type.AIR
		return true
	
	# Remove overhang
	if settings.remove_overhang:
		var below = prism.grid_position_xyz
		below.y -= 1
		if below.y >= 1 and air_at_pos(below):
			prism.type = VoxelData.voxel_type.AIR
			return true
	
	# Terrace shaping
	if settings.terrace_steps >= 1:
		push_warning("Terrace shaping code is disabled and may be obsolete")
		var table = VoxelData.get_tile_neighbor_table(prism.grid_position_xz.x)
		for dir in table:
			var neighbor_pos = Vector3i(prism.grid_position_xyz.x + dir.x,
										prism.grid_position_xyz.y - settings.terrace_steps,
										prism.grid_position_xyz.z + dir.y)
			if air_at_pos(neighbor_pos):
				prism.type = VoxelData.voxel_type.AIR
				return true
	
	return false


func assign_type(voxel: Voxel):
	if voxel.type == VoxelData.voxel_type.AIR or voxel.type == VoxelData.voxel_type.BEDROCK:
		return

	var tiles = VoxelData.tile_map.size()
	var n = voxel.noise

	var enum_index = int(floor(n * float(tiles)))
	if enum_index == 0: # turn air into something else
		enum_index = 5 # Sand, could also be randomized
	elif enum_index == 1 and voxel.grid_position_xyz.y != 0: #turn bedrock into something else
		enum_index = 5
	
	# surface replacement
	var neighbor_above: Vector3i = voxel.grid_position_xyz + Vector3i(0,1,0)
	var neighbor: Voxel = map_dict.get(neighbor_above)
	var tile_dict : Dictionary = VoxelData.tile_map.get(enum_index as VoxelData.voxel_type)
	if tile_dict.has("surface"):
		if neighbor:
			if neighbor.type == VoxelData.voxel_type.AIR:
				enum_index = tile_dict["surface"]
	if tile_dict.has("underground"):
		if neighbor:
			if neighbor.type != VoxelData.voxel_type.AIR:
				enum_index = tile_dict["underground"]
	
	voxel.type = enum_index as VoxelData.voxel_type


func draw_face_towards(neighbor_pos : Vector3i) -> bool:
	var neighbor = map_dict.get(neighbor_pos)
	if neighbor:
		if neighbor.type == VoxelData.voxel_type.AIR:
			return true
		else:
			return false
	return true


func air_at_pos(pos) -> bool:
	var neighbor : Voxel = map_dict.get(pos)
	if neighbor and neighbor.type == VoxelData.voxel_type.AIR:
		return true
	return false


# Returns verts indices and uvs for a voxel
func build_hex_prism(voxel: Voxel) -> Dictionary:
	var verts = PackedVector3Array()
	var uvs   = PackedVector2Array()
	var indices = PackedInt32Array()
	if voxel.type == VoxelData.voxel_type.AIR:
		return {"verts": verts, "uvs": uvs, "indices": indices}

	var top_start = verts.size()
	var size = settings.voxel_size
	var height = settings.voxel_height
	var pos = voxel.world_position
	var top_offset = Vector3(0, height, 0)
	var tiles : Dictionary = VoxelData.tile_map.get(voxel.type)
	var top_tile = tiles["top"]
	var side_tile = tiles["side"]
	var bottom_tile = tiles.get("bottom", top_tile)
	var dirs = VoxelData.get_tile_neighbor_table(voxel.grid_position_xyz.x)
	var neighbor : Vector3i
	
	## TOP!
	neighbor = voxel.grid_position_xyz
	neighbor.y += 1
	if draw_face_towards(neighbor):
		voxel.surface_voxel = true
		surface_voxels.append(voxel)
		for i in range(sides):
			var angle = TAU * float(i) / float(sides)
			var x = cos(angle) * size
			var z = sin(angle) * size
			verts.append(pos + Vector3(x, height, z))
			# map inside [0,1] as circle
			uvs.append(atlas_uv(Vector2(0.5 + cos(angle)*0.5, 0.5 + sin(angle)*0.5), top_tile))
		# center vertex
		verts.append(pos + top_offset)
		uvs.append(atlas_uv(Vector2(0.5, 0.5), top_tile))
		# top triangles
		for i in range(sides):
			indices.append(top_start + i)
			indices.append(top_start + ((i + 1) % sides))
			indices.append(top_start + sides)  # center
	
	## BOTTOM
	neighbor = voxel.grid_position_xyz
	neighbor.y -= 1
	if draw_face_towards(neighbor) and settings.draw_bottom:
		var bottom_start = verts.size()
		for i in range(sides):
			var angle = TAU * float(i) / float(sides)
			var x = cos(angle) * size
			var z = sin(angle) * size
			verts.append(pos + Vector3(x, 0, z))
			uvs.append(atlas_uv(Vector2(0.5 + cos(angle)*0.5, 0.5 + sin(angle)*0.5), bottom_tile))
		verts.append(pos) # center
		uvs.append(atlas_uv(Vector2(0.5,0.5), bottom_tile))
		# triangles (note: winding reversed so normal faces down)
		for i in range(sides):
			indices.append(bottom_start + sides)  # center
			indices.append(bottom_start + ((i + 1) % sides))
			indices.append(bottom_start + i)

	# Sides
	for i in range(sides):
		neighbor = Vector3i(voxel.grid_position_xyz.x + dirs[i].x,
							voxel.grid_position_xyz.y,
							voxel.grid_position_xyz.z + dirs[i].y)
		if not draw_face_towards(neighbor):
			continue  # skip this side entirely
			
		# base_vertices ensure correct ordering
		var bv0 = base_vertices[i]   * size
		var bv1 = base_vertices[(i + 1) % sides] * size

		var p0 = Vector3(bv0.x, 0.0, bv0.z) + pos
		var p1 = Vector3(bv1.x, 0.0, bv1.z) + pos
		var p2 = p0 + top_offset
		var p3 = p1 + top_offset

		var side_start = verts.size()
		verts.append(p0); uvs.append(atlas_uv(Vector2(0,0), side_tile))
		verts.append(p1); uvs.append(atlas_uv(Vector2(1,0), side_tile))
		verts.append(p2); uvs.append(atlas_uv(Vector2(0,1), side_tile))
		verts.append(p3); uvs.append(atlas_uv(Vector2(1,1), side_tile))

		indices.append(side_start + 0)
		indices.append(side_start + 1)
		indices.append(side_start + 2)
		indices.append(side_start + 1)
		indices.append(side_start + 3)
		indices.append(side_start + 2)
	
	# Debug: check UV ranges
	for u in uvs:
		if u.x < 0 or u.x > 1 or u.y < 0 or u.y > 1:
			push_warning("UV out of range: ", u, " for voxel type ", voxel.type)
	#print("Voxel type: ", voxel.type, " → Tile: ", tile, " → Sample UVs: ", uvs.slice(0, 4))

	return {
		"verts": verts,
		"uvs": uvs,
		"indices": indices
	}


func atlas_uv(local_uv: Vector2, tile: Vector2i) -> Vector2:
	# Pixel bounds of usable tile
	var pixel_min: Vector2i = TILE_MARGIN + tile * TILE_STRIDE
	var pixel_max: Vector2i = pixel_min + TILE_SIZE
	
	# Convert to normalized [0..1] UVs
	var uv_min: Vector2 = Vector2(pixel_min) / Vector2(ATLAS_RES)
	var uv_max: Vector2 = Vector2(pixel_max) / Vector2(ATLAS_RES)
	
	# Map local_uv [0..1] into this rectangle
	return uv_min + local_uv * (uv_max - uv_min)

#################################################################

var _cap_by_xz := {}
var _bottom_by_xz := {}

func _spawn_surface_tiles(chunk: Chunk) -> void:
	_cap_by_xz.clear()
	var half_step_h := settings.voxel_height * 0.5

	for v: Voxel in map:
		var scene := _top_scene_for_voxel_type(v.type)
		if scene == null:
			continue
		
		v.is_base_grass_cap = (scene == theme.grass_top_scene)
		
		var cap := scene.instantiate() as Node3D
		var cap_y := float(v.height_units) * half_step_h
		cap.position = Vector3(v.world_position.x, cap_y, v.world_position.z)
		_tag_tile_nodes(cap, v.grid_position_xz)
		chunk.add_child(cap)
		_cap_by_xz[v.grid_position_xz] = cap


func _tag_tile_nodes(root: Node, xz: Vector2i) -> void:
	if root == null:
		return
	
	root.set_meta("xz", xz)
	
	# Tag any collision objects so raycasts can read it
	for n in root.get_children():
		_tag_tile_nodes(n, xz)
	
	if root is CollisionObject3D:
		(root as CollisionObject3D).set_meta("xz", xz)

# Replace caps with the roads or rivers
func _replace_cap_at(chunk: Chunk, v: Voxel, new_scene: PackedScene) -> void:
	var key: Vector2i = v.grid_position_xz
	var old_cap: Node3D = _cap_by_xz.get(key)

	# remove old cap
	var pos: Vector3
	var rot: Vector3
	var have_old := old_cap != null and is_instance_valid(old_cap)

	if have_old:
		pos = old_cap.position
		rot = old_cap.rotation
		old_cap.queue_free()
	else:
		var half_step_h := settings.voxel_height * 0.5
		var cap_y := float(v.height_units) * half_step_h
		pos = Vector3(v.world_position.x, cap_y, v.world_position.z)
		rot = Vector3.ZERO

	# clear record if no replacement requested
	if new_scene == null:
		_cap_by_xz.erase(key)
		# if we're restoring later, this will be set in _spawn_surface_tiles or _apply_cap_variant_for_overlay
		v.is_base_grass_cap = false
		return

	# spawn replacement cap
	var inst := new_scene.instantiate() as Node3D
	if inst == null:
		_cap_by_xz.erase(key)
		v.is_base_grass_cap = false
		return

	inst.position = pos
	inst.rotation = rot
	_tag_tile_nodes(inst, v.grid_position_xz)
	chunk.add_child(inst)
	_cap_by_xz[key] = inst
	_play_place_bounce(inst, chunk)

	# update "is base grass cap" flag deterministically
	v.is_base_grass_cap = (new_scene == theme.grass_top_scene)


func _spawn_columns(chunk: Chunk) -> void:
	_bottom_by_xz.clear()
	var half_step_h := settings.voxel_height * 0.5

	for v: Voxel in map:
		if v.height_units <= 0:
			continue

		var scene := _bottom_scene_for_voxel_type(v.type)
		if scene == null:
			continue

		var bottom := scene.instantiate() as Node3D

		# height in world units
		var height_world := float(v.height_units - 2) * half_step_h

		# If bottom mesh is 1.0 world unit tall at scale.y=1, scale directly:
		bottom.scale.y = height_world

		# Base at y=0
		bottom.position = Vector3(v.world_position.x, 0.0, v.world_position.z)

		chunk.add_child(bottom)
		_bottom_by_xz[v.grid_position_xz] = bottom


func _build_surface_from_map() -> Array[Voxel]:
	var surface := {} # Dictionary: Vector2i -> Voxel (topmost)

	for v: Voxel in map:
		if v.type == VoxelData.voxel_type.AIR:
			continue
		var key: Vector2i = v.grid_position_xz
		if not surface.has(key) or v.grid_position_xyz.y > (surface[key] as Voxel).grid_position_xyz.y:
			surface[key] = v

	# convert dict values to array
	var out: Array[Voxel] = []
	for k in surface.keys():
		out.append(surface[k] as Voxel)
	return out


func _spawn_padding(chunk: Chunk) -> void:
	if theme == null or theme.grass_padding_scene == null:
		return

	var half_step_h := settings.voxel_height * 0.5

	for v: Voxel in map:
		var table = VoxelData.get_tile_neighbor_table(v.grid_position_xz.x)

		for i in range(6):
			var nx: int = v.grid_position_xz.x + int(table[i].x)
			var nz: int = v.grid_position_xz.y + int(table[i].y)

			# You need a lookup by xz. Build it once:
			# map_xz[key] = voxel
			# (see note below)

			var n: Voxel = _map_xz.get(Vector2i(nx, nz))
			if n == null:
				continue

			if v.height_units - n.height_units == 1:
				var pad_scene := _padding_scene_for_voxel_type(v.type)
				if pad_scene == null:
					continue

				var pad := pad_scene.instantiate() as Node3D

				var a: Vector3 = base_vertices[i] * settings.voxel_size
				var b: Vector3 = base_vertices[(i + 1) % 6] * settings.voxel_size
				var mid: Vector3 = (a + b) * 0.5

				# place at the “half step” between the two
				var pad_y := float(n.height_units) * half_step_h
				pad.position = Vector3(v.world_position.x + mid.x, pad_y, v.world_position.z + mid.z)

				pad.rotation.y = atan2(mid.z, mid.x)
				chunk.add_child(pad)


func refresh_overlay_at(chunk: Chunk, v: Voxel) -> void:
	_apply_cap_variant_for_overlay(chunk, v)


func _apply_cap_variant_for_overlay(chunk: Chunk, v: Voxel) -> void:
	if theme == null:
		return

	# no overlay -> restore normal terrain cap
	if v.overlay == Voxel.Overlay.NONE:
		var scene := _top_scene_for_voxel_type(v.type)
		_replace_cap_at(chunk, v, _top_scene_for_voxel_type(v.type))
		v.is_base_grass_cap = (scene == theme.grass_top_scene)
		return

	var is_road := v.overlay == Voxel.Overlay.ROAD
	var mask := v.road_mask if is_road else v.river_mask

	var letter := VoxelData.variant_letter_from_mask(mask)
	var idx: int = (
		VoxelData.ROAD_LETTER_TO_INDEX[letter]
		if is_road
		else VoxelData.RIVER_LETTER_TO_INDEX[letter]
	)

	var variants: Array[PackedScene] = theme.road_variants if is_road else theme.river_variants
	if idx < 0 or idx >= variants.size():
		push_warning("Overlay cap idx out of range letter=%s idx=%s size=%s" % [letter, idx, variants.size()])
		return

	var scene: PackedScene = variants[idx]
	_replace_cap_at(chunk, v, scene)

	# rotate the replacement cap
	var cap: Node3D = _cap_by_xz.get(v.grid_position_xz)
	if cap != null and is_instance_valid(cap):
		cap.rotation.y = _overlay_yaw_from_mask(mask)


func _update_overlay_for_voxel(chunk: Chunk, v: Voxel) -> void:
	var key := v.grid_position_xz

	# remove existing overlay nodes if overlay type changed
	if v.overlay != Voxel.Overlay.ROAD and _road_by_xz.has(key):
		var n: Node = _road_by_xz[key]
		if n != null: n.queue_free()
		_road_by_xz.erase(key)

	if v.overlay != Voxel.Overlay.RIVER and _river_by_xz.has(key):
		var n2: Node = _river_by_xz[key]
		if n2 != null: n2.queue_free()
		_river_by_xz.erase(key)

	var half_step_h := settings.voxel_height * 0.5
	var y := float(v.height_units) * half_step_h + 0.02

	if v.overlay == Voxel.Overlay.ROAD:
		_apply_overlay_variant(chunk, v, true, Vector3(v.world_position.x, y, v.world_position.z))

	if v.overlay == Voxel.Overlay.RIVER:
		_apply_overlay_variant(chunk, v, false, Vector3(v.world_position.x, y, v.world_position.z))


func _apply_overlay_variant(chunk: Chunk, v: Voxel, is_road: bool, pos: Vector3) -> void:
	if theme == null:
		return

	var key := v.grid_position_xz
	var mask := v.road_mask if is_road else v.river_mask

	# pick variant index by mask
	var letter := VoxelData.variant_letter_from_mask(mask)
	var idx: int = (VoxelData.ROAD_LETTER_TO_INDEX[letter] if is_road else VoxelData.RIVER_LETTER_TO_INDEX[letter])

	var variants := theme.road_variants if is_road else theme.river_variants
	if idx < 0 or idx >= variants.size():
		push_warning("Overlay variant idx out of range (%s) idx=%s size=%s" % [letter, idx, variants.size()])
		return

	var dict := _road_by_xz if is_road else _river_by_xz
	var existing: Node3D = dict.get(key)

	# if exists but wrong variant, replace
	var desired_scene: PackedScene = variants[idx]
	var desired_path := desired_scene.resource_path

	if existing != null and is_instance_valid(existing):
		# if you want strict match by scene path, store it in metadata
		var existing_path := str(existing.get_meta("variant_path", ""))
		if existing_path != desired_path:
			existing.queue_free()
			dict.erase(key)
			existing = null

	# spawn if missing
	if existing == null:
		var inst := desired_scene.instantiate() as Node3D
		inst.position = pos
		inst.set_meta("variant_path", desired_path)
		chunk.add_child(inst)
		dict[key] = inst
		existing = inst

	# rotation so the same A/B/C... can align with which edges are connected
	existing.rotation.y = _overlay_yaw_from_mask(mask)


func _overlay_yaw_from_mask(mask: int) -> float:
	# Find the first set bit (0..5) and rotate so that bit aligns with your base mesh direction.
	# Assumption: your meshes are authored with "connection on edge 0" as their default orientation.
	# If not, add an offset (see below).
	var first := -1
	for i in range(6):
		if (mask & (1 << i)) != 0:
			first = i
			break

	if first == -1:
		return 0.0

	var step := TAU / 6.0
	const EDGE_OFFSET_STEPS := 1 # change this if your asset's "edge 0" isn't Godot's edge 0
	return float(first + EDGE_OFFSET_STEPS) * step


func _play_place_bounce(node: Node3D, chunk: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if chunk == null or not is_instance_valid(chunk):
		return
	
	node.scale = Vector3.ONE
	
	var tween: Tween = chunk.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	# Step 1: squish + dip (parallel)
	tween.tween_property(node, "scale", Vector3(1.1, 0.6, 1.1), 0.16)
	
	# Step 2: bounce + rise (parallel)
	tween.tween_property(node, "scale", Vector3(0.95, 1.15, 0.95), 0.20)
	
	# Step 3: settle (parallel)
	tween.tween_property(node, "scale", Vector3.ONE, 0.14)


func _spawn_mountains(chunk: Chunk) -> void:
	if theme == null:
		return
	if theme.mountain_scenes.is_empty():
		return

	var half_step_h: float = settings.voxel_height * 0.5

	for v: Voxel in surface_voxels:
		# Only above threshold
		if v.height_units < theme.mountain_min_height_units:
			continue

		# Optional chance
		if theme.mountain_chance < 1.0:
			var rng_chance := RandomNumberGenerator.new()
			rng_chance.seed = _tile_seed(v, 912367) # salt
			if rng_chance.randf() > theme.mountain_chance:
				continue

		# Pick one of the 3 variants deterministically
		var rng := RandomNumberGenerator.new()
		rng.seed = _tile_seed(v, 44519) # different salt
		var idx := rng.randi_range(0, theme.mountain_scenes.size() - 1)

		var scene := theme.mountain_scenes[idx]
		if scene == null:
			continue

		var m := scene.instantiate() as Node3D

		# Put it on the cap surface of this tile
		var cap_y := float(v.height_units) * half_step_h
		m.position = Vector3(v.world_position.x, cap_y, v.world_position.z)

		# If your tile caps already have a fixed yaw baked in, do nothing here.
		# If you need per-tile random yaw:
		m.rotation.y = rng.randi_range(0, 5) * PI / 3

		chunk.add_child(m)
		_has_mountain_by_xz[v.grid_position_xz] = true
		
		v.resource_id = &"mountain"
		
		# replace foundation of mountain tile
		if theme.mountain_foundation_scene != null:
			var key: Vector2i = v.grid_position_xz
			var old_cap: Node3D = _cap_by_xz.get(key)
			
			if old_cap != null:
				var pos := old_cap.position
				var rot := old_cap.rotation
				old_cap.queue_free()
				
				var new_cap := theme.mountain_foundation_scene.instantiate() as Node3D
				new_cap.position = pos
				new_cap.rotation = rot
				chunk.add_child(new_cap)
				_cap_by_xz[key] = new_cap
		
		# replace bottom column of mountain tile
		if theme.mountain_foundation_bottom_scene != null:
			var key: Vector2i = v.grid_position_xz
			var old_bottom: Node3D = _bottom_by_xz.get(key)

			if old_bottom != null:
				var pos_b := old_bottom.position
				var rot_b := old_bottom.rotation
				var scale_b := old_bottom.scale
				old_bottom.queue_free()

				var new_bottom := theme.mountain_foundation_bottom_scene.instantiate() as Node3D
				new_bottom.position = pos_b
				new_bottom.rotation = rot_b
				new_bottom.scale = scale_b # IMPORTANT: keep same height scaling
				chunk.add_child(new_bottom)
				_bottom_by_xz[key] = new_bottom


func _spawn_forests(chunk: Chunk) -> void:
	if theme == null:
		return
	if theme.tree_cluster_scenes.is_empty():
		return

	var half_step_h: float = settings.voxel_height * 0.5

	for v: Voxel in surface_voxels:
		if v.buffer:
			continue

		# height band
		if v.height_units < theme.forest_min_height_units:
			continue
		if v.height_units > theme.forest_max_height_units:
			continue

		# don't place on mountain tiles
		if theme.forest_avoid_mountains and _has_mountain_by_xz.has(v.grid_position_xz):
			continue

		# chance (deterministic)
		var rng := RandomNumberGenerator.new()
		rng.seed = _tile_seed(v, 771231) # salt
		if rng.randf() > theme.forest_chance:
			continue

		# pick variant
		var idx := rng.randi_range(0, theme.tree_cluster_scenes.size() - 1)
		var scene := theme.tree_cluster_scenes[idx]
		if scene == null:
			continue

		var inst := scene.instantiate() as TreeCluster		# possibly return to Node3D

		# place on cap height
		var y := float(v.height_units) * half_step_h
		inst.position = Vector3(v.world_position.x, y, v.world_position.z)

		# small random rotation looks nice
		inst.rotation.y = rng.randf_range(0.0, TAU)

		chunk.add_child(inst)
		
		inst.home_voxel = v			# possibly delete
		v.resource_id = &"tree_cluster"

		# mark tile unplaceable for villages/units if you want
		#v.placeable = false


# -------------------------------------------------------------------
# PREVIEW CAP API (used by RoadTool to show a "real tile" preview)
# -------------------------------------------------------------------

var _preview_keys: Dictionary = {} # Vector2i -> bool

func preview_cap_at(chunk: Chunk, v: Voxel, new_scene: PackedScene) -> void:
	if v == null:
		return
	_preview_keys[v.grid_position_xz] = true
	_replace_cap_at(chunk, v, new_scene)


func preview_cap_rotate(key: Vector2i, yaw: float) -> void:
	var cap: Node3D = _cap_by_xz.get(key)
	if cap != null and is_instance_valid(cap):
		cap.rotation.y = yaw


func clear_preview_cap(chunk: Chunk, v: Voxel) -> void:
	if v == null:
		return

	var key := v.grid_position_xz
	if not _preview_keys.has(key):
		return

	_preview_keys.erase(key)

	# restore to normal terrain cap (based on voxel.type)
	var scene := _top_scene_for_voxel_type(v.type)
	_replace_cap_at(chunk, v, scene)


func _tile_seed(v: Voxel, salt: int) -> int:
	# Deterministic per tile, also stable across runs if your world seed is stable
	# Mix world seed + x/z + salt.
	# (If map_seed can be 0, you can also use settings.noise.seed.)
	var s: int = int(settings.map_seed)
	var x: int = v.grid_position_xz.x
	var z: int = v.grid_position_xz.y
	return hash(Vector3i(x, s + salt, z))


var _map_xz: Dictionary = {}

func _build_xz_lookup() -> void:
	_map_xz.clear()
	for v: Voxel in map:
		_map_xz[v.grid_position_xz] = v


func _top_scene_for_voxel_type(t) -> PackedScene:
	match t:
		VoxelData.voxel_type.STONE:
			return theme.stone_top_scene
		_:
			return theme.grass_top_scene


func _bottom_scene_for_voxel_type(t) -> PackedScene:
	match t:
		VoxelData.voxel_type.STONE:
			return theme.stone_bottom_scene
		_:
			return theme.grass_bottom_scene


func _padding_scene_for_voxel_type(t) -> PackedScene:
	match t:
		VoxelData.voxel_type.STONE:
			return theme.stone_padding_scene
		_:
			return theme.grass_padding_scene


func _step_h() -> float:
	return settings.voxel_height * 0.5
