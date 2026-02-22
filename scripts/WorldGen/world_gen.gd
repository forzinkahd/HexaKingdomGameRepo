extends Node

# Dependencies
@export var settings : GenerationSettings
@export_category("Dependencies")
@export var object_placer : ObjectPlacer
@onready var interaction_tracker: Node3D = $"../Interaction_tracker"
@onready var chunks: Node3D = $"../../Chunks"
@export var world_theme: WorldTheme
@export var overlay_visuals: OverlayVisuals		# mainly debug
@export var road_tool: RoadTool
#UI
@onready var label: RichTextLabel = $"../../Control/VBoxContainer/RichTextLabel"


var _vg: VoxelGenerator
var _chunk: Chunk

## Starting point: Generate a random seed, create the tiles, place POI's
func _ready() -> void:
	WorldMap.clear_map()
	WorldMap.world_settings = settings
	init_seed()
	var children = chunks.get_children() + get_children()
	for c in children:
		c.free()
	object_placer.clear_objects()
	call_deferred("generate_world")

# Randomize if no seed has been set
func init_seed():
	if settings.map_seed == 0 or settings.map_seed == null:
		settings.noise.seed = randi()
	else:
		settings.noise.seed = settings.map_seed


## Start of world_generation, time each step
func generate_world():
	var starttime = Time.get_ticks_msec()
	var interval = {"Start of Generation!" : starttime}
	
	## Get all positions through the gridmapper
	var mapper = GridMapper.new()
	var voxels = mapper.calculate_map_positions()
	interval["Calculate Map Positions -- "] = Time.get_ticks_msec()

	_vg = VoxelGenerator.new()
	_vg.theme = world_theme
	_chunk = _vg.generate_chunk(voxels, interval)
	chunks.add_child(_chunk)
	_chunk.init_chunk()
	interval["Create Voxel Mesh -- "] = Time.get_ticks_msec()
	#print("World theme is: ", world_theme)
	
	print_generation_results(starttime, interval)
	interaction_tracker.init()
	
	# Configure road tool runtime references
	if road_tool != null:
		road_tool.world_theme = world_theme
		road_tool.configure_runtime(_vg, _chunk)
	else:
		push_warning("world_gen: road_tool not assigned")
	#_debug_spawn_overlay_examples(new_chunk)		# debug
	#Debugger.draw_voxel_dictionary(WorldMap.surface_layer)

### Begin Debug ###
func _unhandled_input(event: InputEvent) -> void:
	# Optional convenience hotkey: start road tool from any valid grass tile
	if event.is_action_pressed("toggle_road_tool"):
		if road_tool == null:
			return
		var v := _find_any_surface_voxel(func(x: Voxel) -> bool:
			return x != null and x.type == VoxelData.voxel_type.GRASS and x.can_place_road()
		)
		if v != null:
			road_tool.begin_from_voxel(v)

func _debug_spawn_road_and_river() -> void:
	if overlay_visuals == null:
		push_warning("overlay_visuals not assigned")
		return

	var road_start := _find_any_surface_voxel(func(v: Voxel) -> bool:
		return v != null and v.can_place_road()
	)
	if road_start == null:
		push_warning("No road_start found")
		return
	
	var y := float(road_start.height_units) * (settings.voxel_height * 0.5) + 0.02
	"""overlay_visuals.debug_spawn_one(
		world_theme.road_variants[0],   # pick any index you KNOW is populated
		world_theme.river_variants[0],
		Vector3(road_start.world_position.x, y, road_start.world_position.z)
	)"""


	# pick a river tile far enough away
	var river_start := _find_any_surface_voxel(func(v: Voxel) -> bool:
		return v != null and v.can_place_river() and v.grid_position_xz.distance_to(road_start.grid_position_xz) > 6
	)
	if river_start == null:
		push_warning("No river_start found")
		return

	_place_overlay_line(road_start, Voxel.Overlay.ROAD, 3)
	_place_overlay_line(river_start, Voxel.Overlay.RIVER, 3)


func _find_any_surface_voxel(pred: Callable) -> Voxel:
	for key in WorldMap.surface_layer.keys():
		var v: Voxel = WorldMap.surface_layer[key]
		if pred.call(v):
			return v
	return null


func _place_overlay_line(start: Voxel, overlay: int, length: int) -> void:
	var cur := start
	for i in range(length):
		if cur == null:
			break
		
		if overlay == Voxel.Overlay.ROAD and not cur.can_place_road():
			break
		if overlay == Voxel.Overlay.RIVER and not cur.can_place_river():
			break
		
		cur.overlay = overlay
		# recompute masks for cur + neighbors
		_recalc_overlay_masks_around(cur, overlay)
		
		# refresh tile CAP replacements (roads/rivers are full caps)
		_vg.refresh_overlay_at(_chunk, cur)
		for n in WorldMap.get_tile_neighbors_surface(cur):
			_vg.refresh_overlay_at(_chunk, n)
		
		# step to neighbor direction 1 (east-ish)
		cur = _neighbor_surface(cur, 1)


func _neighbor_surface(v: Voxel, dir_index: int) -> Voxel:
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	var nk := v.grid_position_xz + dirs[dir_index]
	return WorldMap.surface_layer.get(nk)


func _recalc_overlay_masks_around(center: Voxel, overlay: int) -> void:
	_recalc_overlay_mask(center, overlay)

	var dirs := VoxelData.neighbor_dirs_for_col(center.grid_position_xz.x)
	for i in range(6):
		var nk := center.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n != null:
			_recalc_overlay_mask(n, overlay)


func _recalc_overlay_mask(v: Voxel, overlay: int) -> void:
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)

	for i in range(6):
		var nk := v.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n == null:
			continue

		if overlay == Voxel.Overlay.ROAD:
			if v.overlay == Voxel.Overlay.ROAD and n.overlay == Voxel.Overlay.ROAD:
				mask |= (1 << i)
		elif overlay == Voxel.Overlay.RIVER:
			if v.overlay == Voxel.Overlay.RIVER and n.overlay == Voxel.Overlay.RIVER:
				mask |= (1 << i)

	if overlay == Voxel.Overlay.ROAD:
		v.road_mask = mask
	else:
		v.river_mask = mask


### End Debug ###


"""func _debug_spawn_overlay_examples(chunk: Chunk) -> void:
	var vg: VoxelGenerator = chunk.get_meta("voxel_generator")
	if vg == null:
		push_warning("No voxel_generator meta on chunk.")
		return

	# Pick two candidate surface voxels far apart
	var road_start := _find_any_surface_voxel(func(v: Voxel) -> bool:
		return v != null and v.can_place_road()
	)
	var river_start := _find_any_surface_voxel(func(v: Voxel) -> bool:
		if v == null:
			return false
		if not v.can_place_river():
			return false
		if road_start == null:
			return true
		return v.grid_position_xz.distance_to(road_start.grid_position_xz) > 6
	)

	if road_start == null or river_start == null:
		push_warning("Couldn't find road_start or river_start.")
		return

	# ROAD: make a 3-tile line
	_place_overlay_line(chunk, vg, road_start, Voxel.Overlay.ROAD, 3)

	# RIVER: make a 3-tile line
	_place_overlay_line(chunk, vg, river_start, Voxel.Overlay.RIVER, 3)




func _find_any_surface_voxel(pred: Callable) -> Voxel:
	for key in WorldMap.surface_layer.keys():
		var v: Voxel = WorldMap.surface_layer[key]
		if pred.call(v):
			return v
	return null


func _place_overlay_line(chunk: Chunk, vg: VoxelGenerator, start: Voxel, overlay: int, length: int) -> void:
	var cur := start
	for i in range(length):
		if cur == null:
			break

		# Place overlay (respect rules)
		if overlay == Voxel.Overlay.ROAD:
			if not cur.can_place_road():
				break
		if overlay == Voxel.Overlay.RIVER:
			if not cur.can_place_river():
				break

		cur.overlay = overlay

		# recompute masks locally (center + neighbors) then update visuals
		_recalc_overlay_masks_around(cur, overlay)
		vg._update_overlay_for_voxel(chunk, cur)
		
		var dirs: Array = VoxelData.neighbor_dirs_for_col(cur.grid_position_xz.x)
		for j in range(6):
			var nk: Vector2i = cur.grid_position_xz + dirs[j]
			var n: Voxel = WorldMap.surface_layer.get(nk)
			if n != null:
				vg._update_overlay_for_voxel(chunk, n)

		# pick next neighbor in direction 1 (east-ish) if possible
		var next := _neighbor_surface(cur, 1) # direction index 1 is usually "E" in your tables
		if next == null:
			break
		cur = next


func _neighbor_surface(v: Voxel, dir_index: int) -> Voxel:
	if v == null:
		return null
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	if dir_index < 0 or dir_index >= dirs.size():
		return null

	var nk := v.grid_position_xz + dirs[dir_index]
	return WorldMap.surface_layer.get(nk)


func _recalc_overlay_masks_around(center: Voxel, overlay: int) -> void:
	_recalc_overlay_mask(center, overlay)

	var dirs := VoxelData.neighbor_dirs_for_col(center.grid_position_xz.x)
	for i in range(6):
		var nk := center.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n != null:
			_recalc_overlay_mask(n, overlay)


func _recalc_overlay_mask(v: Voxel, overlay: int) -> void:
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)

	for i in range(6):
		var nk := v.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n == null:
			continue

		if overlay == Voxel.Overlay.ROAD:
			if v.overlay == Voxel.Overlay.ROAD and n.overlay == Voxel.Overlay.ROAD:
				mask |= (1 << i)

		elif overlay == Voxel.Overlay.RIVER:
			if v.overlay == Voxel.Overlay.RIVER and n.overlay == Voxel.Overlay.RIVER:
				mask |= (1 << i)

	if overlay == Voxel.Overlay.ROAD:
		v.road_mask = mask
	elif overlay == Voxel.Overlay.RIVER:
		v.river_mask = mask"""




## This mess of a function loops through the timing results of generate_world and prints them
func print_generation_results(start : float, dict : Dictionary):
	print("\n")
	label.text = ""
	var last_val = start
	var total = 0
	var unit = "ms"
	
	for key in dict:
		var val = dict[key]
		if val == start:
			continue
		var passed = val - last_val
		label.text += "[b]" + str(key) + "[/b]" + "[i]" + str(passed) + "ms\n" + "[/i]"
		last_val = val
		total += passed

	if total > 999: 
		unit = "s"
		total *= 0.001

	print("Total completion time: ", total, unit)
	label.text += "[b]Total completion time: [/b][i]" + str(total) + unit + "[/i]"


## Ignore buffer and ocean to return for object placer
func get_placeable_voxels() -> Array[Voxel]:
	var placeable_tiles : Array[Voxel] = []
	for key in WorldMap.surface_layer:
		var voxel: Voxel = WorldMap.surface_layer[key]
		if voxel.buffer or not voxel.placeable:
			continue
		placeable_tiles.append(voxel)
	print(str(placeable_tiles.size()) + " placeable tiles")
	return placeable_tiles
