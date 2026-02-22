extends Node
class_name RoadTool

@export_category("Dependencies")
@export var camera: Camera3D
@export var world_theme: WorldTheme
@export var ghost_parent: Node3D # e.g. World/Overlays or World itself
# Assign these from world_gen.gd after generation
var vg: VoxelGenerator = null
var chunk: Chunk = null


@export_category("Rules")
@export var require_grass: bool = true # only place on grass surface voxels
@export var edge_offset_steps: int = 1 # you found 1 works for your assets

# Tool state
var active: bool = false
var anchor: Voxel = null          # current "front" tile
var ghost: Node3D = null
var ghost_dir: int = 0            # 0..5

const GHOST_INDEX: int = 12       # "M" dead-end in your road_variants

func configure_runtime(_vg: VoxelGenerator, _chunk: Chunk) -> void:
	vg = _vg
	chunk = _chunk

func set_active(on: bool) -> void:
	active = on
	if not active:
		_clear_ghost()
		anchor = null


func begin_from_voxel(v: Voxel) -> void:
	if v == null:
		return

	# IMPORTANT: always resolve to the canonical surface voxel instance
	var key := v.grid_position_xz
	var sv: Voxel = WorldMap.surface_layer.get(key)
	if sv == null:
		push_warning("RoadTool: begin_from_voxel -> no surface voxel at %s" % [key])
		return

	if not _can_place_on(sv, true):
		return

	set_active(true)
	anchor = sv
	ghost_dir = 0
	_show_ghost_on(anchor)


func _can_place_on(v: Voxel, is_start: bool = false) -> bool:
	if v == null:
		push_warning("RoadTool: v == null")
		return false

	# Helpful diagnostics:
	if not v.can_place_road():
		push_warning("RoadTool: can't place road on %s  buffer=%s water=%s overlay=%s building=%s resource=%s placeable=%s"
			% [v.grid_position_xz, v.buffer, v.water, v.overlay, v.has_building(), v.has_resource(), v.placeable])
		return false

	# If you *really* want grass-only placement:
	if require_grass and not v.is_base_grass_cap:
		push_warning("RoadTool: not GRASS at %s  type=%s (require_grass=true)"
			% [v.grid_position_xz, str(v.type)])
		return false

	return true


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event.is_action_pressed("rotate_left"):
		rotate_left()
		return
	if event.is_action_pressed("rotate_right"):
		rotate_right()
		return
	if event.is_action_pressed("ui_cancel"):
		set_active(false)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var v := _pick_surface_voxel()
		if v == null:
			return
		try_place_at(v)

func rotate_left() -> void:
	ghost_dir = (ghost_dir + 5) % 6
	_update_ghost_transform()

func rotate_right() -> void:
	ghost_dir = (ghost_dir + 1) % 6
	_update_ghost_transform()

func try_place_at(v: Voxel) -> void:
	if v == null or anchor == null:
		return
	if vg == null or chunk == null:
		push_warning("RoadTool: vg/chunk not configured. Call road_tool.configure_runtime(vg, chunk) after generation.")
		return

	# If you click an existing road, continue from there (nice UX)
	if v.overlay == Voxel.Overlay.ROAD:
		anchor = v
		_show_ghost_on(anchor)
		return

	# Must be neighbor of anchor
	if not _is_neighbor(anchor, v):
		return

	# Must be placeable
	if not _can_place_on(v):
		return

	# Place road on v
	v.overlay = Voxel.Overlay.ROAD

	# Recalc masks on v + its neighbors (roads only)
	_recalc_road_masks_around(v)

	# Refresh visuals (cap replacement) for v and neighbors
	_refresh_neighborhood(v)

	# Move anchor forward + move ghost
	anchor = v
	_show_ghost_on(anchor)

"""func _can_place_on(v: Voxel) -> bool:
	if v == null:
		return false
	if not v.can_place_road():
		return false
	if require_grass and v.type != VoxelData.voxel_type.GRASS:
		return false
	return true"""

# --- Picking ---

func _pick_surface_voxel() -> Voxel:
	if camera == null:
		return null

	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var to := from + dir * 5000.0

	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var hit := camera.get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null

	var col: Object = hit.get("collider")
	if col == null:
		return null

	# IMPORTANT: this relies on VoxelGenerator tagging the cap/collider with meta "xz"
	if not col.has_meta("xz"):
		return null

	var key: Variant = col.get_meta("xz")
	if typeof(key) != TYPE_VECTOR2I:
		return null

	return WorldMap.surface_layer.get(key)

# --- Neighbor / mask updates ---

func _is_neighbor(a: Voxel, b: Voxel) -> bool:
	if a == null or b == null:
		return false
	var dirs := VoxelData.neighbor_dirs_for_col(a.grid_position_xz.x)
	for i in range(6):
		if a.grid_position_xz + dirs[i] == b.grid_position_xz:
			return true
	return false

func _recalc_road_masks_around(center: Voxel) -> void:
	_recalc_road_mask(center)
	var dirs := VoxelData.neighbor_dirs_for_col(center.grid_position_xz.x)
	for i in range(6):
		var nk := center.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n != null:
			_recalc_road_mask(n)

func _recalc_road_mask(v: Voxel) -> void:
	if v.overlay != Voxel.Overlay.ROAD:
		v.road_mask = 0
		return

	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		var nk := v.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n != null and n.overlay == Voxel.Overlay.ROAD:
			mask |= (1 << i)

	v.road_mask = mask

func _refresh_neighborhood(center: Voxel) -> void:
	# Road caps are full replacements, so we refresh cap replacement logic
	vg.refresh_overlay_at(chunk, center)
	for n in WorldMap.get_tile_neighbors_surface(center):
		vg.refresh_overlay_at(chunk, n)

# --- Ghost ---

func _show_ghost_on(v: Voxel) -> void:
	if v == null:
		return
	_ensure_ghost()
	_update_ghost_transform()

func _ensure_ghost() -> void:
	if ghost != null and is_instance_valid(ghost):
		return
	if world_theme == null:
		push_warning("RoadTool: world_theme not assigned")
		return
	if ghost_parent == null:
		push_warning("RoadTool: ghost_parent not assigned")
		return
	if world_theme.road_variants.is_empty():
		push_warning("RoadTool: theme.road_variants is empty")
		return
	if GHOST_INDEX < 0 or GHOST_INDEX >= world_theme.road_variants.size():
		push_warning("RoadTool: ghost index out of range")
		return

	var scene := world_theme.road_variants[GHOST_INDEX] as PackedScene
	if scene == null:
		push_warning("RoadTool: ghost scene is null at index %d" % GHOST_INDEX)
		return

	ghost = scene.instantiate() as Node3D
	if ghost == null:
		return

	ghost.set_meta("is_ghost", true)
	ghost_parent.add_child(ghost)
	_set_ghost_material(ghost)

func _update_ghost_transform() -> void:
	if ghost == null or anchor == null:
		return

	var y := float(anchor.height_units) * (WorldMap.world_settings.voxel_height * 0.5) + 0.02
	ghost.position = Vector3(anchor.world_position.x, y, anchor.world_position.z)

	var step := TAU / 6.0
	ghost.rotation.y = float(ghost_dir + edge_offset_steps) * step

func _clear_ghost() -> void:
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func _set_ghost_material(root: Node) -> void:
	# recurse
	for c in root.get_children():
		_set_ghost_material(c)

	# handle meshes
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D

		# If the mesh already has materials, override each surface.
		# Otherwise, set a single material_override.
		var mesh := mi.mesh
		if mesh != null:
			for s in range(mesh.get_surface_count()):
				var base_mat: Material = mi.get_active_material(s)
				var mat := _make_ghost_material(base_mat)
				mi.set_surface_override_material(s, mat)
		else:
			# fallback
			mi.material_override = _make_ghost_material(mi.material_override)

func _make_ghost_material(base: Material) -> Material:
	var mat: StandardMaterial3D

	# If you have a StandardMaterial3D already, duplicate it so we don't modify the original.
	if base is StandardMaterial3D:
		mat = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()

	# Make it transparent + slightly emissive so it's readable
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.95
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Optional: stop ghost from casting shadows
	#mat.cast_shadow = BaseMaterial3D.SHADOW_CASTING_SETTING_OFF

	return mat
