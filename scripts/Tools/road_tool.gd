extends Node
class_name RoadTool

@export_category("Dependencies")
@export var camera: Camera3D
@export var world_theme: WorldTheme

# Assign these from world_gen.gd after generation
var vg: VoxelGenerator = null
var chunk: Chunk = null

@export_category("Rules")
@export var require_grass: bool = true
@export var edge_offset_steps: int = 1 # your assets need +1

# Tool state
var active: bool = false
var anchor: Voxel = null          # current "front" tile
var ghost_dir: int = 0            # 0..5 (we keep name for rotation)

const PREVIEW_INDEX: int = 2     # "M" dead-end in road_variants

func configure_runtime(_vg: VoxelGenerator, _chunk: Chunk) -> void:
	vg = _vg
	chunk = _chunk

func set_active(on: bool) -> void:
	active = on
	if not active:
		_clear_preview()
		anchor = null

func begin_from_voxel(v: Voxel) -> void:
	if v == null:
		return

	# Always resolve canonical surface voxel
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

	# Show preview using REAL road tile (index 12) without changing overlay state yet
	_apply_preview_cap(anchor)


func commit_current() -> void:
	# Commit the currently previewed tile as an actual road.
	if not active:
		return
	if vg == null or chunk == null:
		push_warning("RoadTool: commit_current -> vg/chunk not configured")
		return
	if anchor == null:
		return

	# Always resolve canonical surface voxel
	var sv: Voxel = WorldMap.surface_layer.get(anchor.grid_position_xz)
	if sv != null:
		anchor = sv

	# If it's already a road, nothing to do (but we should clear preview)
	if anchor.overlay == Voxel.Overlay.ROAD:
		_clear_preview()
		return

	# Enforce placement rules (optional but recommended)
	if not _can_place_on(anchor):
		return

	# Remove preview (this restores base cap, but we immediately replace it via refresh_overlay_at)
	_clear_preview()

	# Commit overlay state
	anchor.overlay = Voxel.Overlay.ROAD

	# Update connectivity + visuals
	_recalc_road_masks_around(anchor)
	_refresh_neighborhood(anchor)

	# Optionally end placement mode after confirm
	set_active(false)


func _can_place_on(v: Voxel, is_start: bool = false) -> bool:
	if v == null:
		return false

	if not v.can_place_road():
		push_warning("RoadTool: can't place road on %s  buffer=%s water=%s overlay=%s building=%s resource=%s placeable=%s"
			% [v.grid_position_xz, v.buffer, v.water, v.overlay, v.has_building(), v.has_resource(), v.placeable])
		return false

	# "Grass only" = only tiles whose current cap is the base grass cap
	if require_grass and not v.is_base_grass_cap:
		push_warning("RoadTool: not GRASS-cap at %s (require_grass=true)" % [v.grid_position_xz])
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

	"""if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var v := _pick_surface_voxel()
		if v == null:
			return
		try_place_at(v)"""

func rotate_left() -> void:
	ghost_dir = (ghost_dir + 5) % 6
	# rotate preview cap if we have one
	_apply_preview_rotation()

func rotate_right() -> void:
	ghost_dir = (ghost_dir + 1) % 6
	_apply_preview_rotation()

func try_place_at(v: Voxel) -> void:
	if v == null or anchor == null:
		return
	if vg == null or chunk == null:
		push_warning("RoadTool: vg/chunk not configured. Call road_tool.configure_runtime(vg, chunk) after generation.")
		return

	# Resolve canonical surface voxel again
	v = WorldMap.surface_layer.get(v.grid_position_xz)

	# Clicking an existing road = continue from there (no preview swap needed)
	if v.overlay == Voxel.Overlay.ROAD:
		_clear_preview()
		anchor = v
		return

	# Must be neighbor of anchor
	if not _is_neighbor(anchor, v):
		return

	# Must be placeable
	if not _can_place_on(v):
		return

	# COMMIT: set overlay and update masks/visuals
	_clear_preview() # remove preview on previous anchor

	v.overlay = Voxel.Overlay.ROAD
	_recalc_road_masks_around(v)
	_refresh_neighborhood(v)

	# Move anchor forward and show preview again on the new anchor
	anchor = v
	ghost_dir = 0
	_apply_preview_cap(anchor)

# --- Picking ---

"""func _pick_surface_voxel() -> Voxel:
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

	# relies on VoxelGenerator tagging caps/colliders with meta "xz"
	if not col.has_meta("xz"):
		return null

	var key: Variant = col.get_meta("xz")
	if typeof(key) != TYPE_VECTOR2I:
		return null

	return WorldMap.surface_layer.get(key)"""

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
	vg.refresh_overlay_at(chunk, center)
	for n in WorldMap.get_tile_neighbors_surface(center):
		vg.refresh_overlay_at(chunk, n)

# --- Preview using REAL road cap (index 12) ---

func _apply_preview_cap(v: Voxel) -> void:
	if vg == null or chunk == null or world_theme == null:
		return
	if v == null:
		return

	if PREVIEW_INDEX < 0 or PREVIEW_INDEX >= world_theme.road_variants.size():
		push_warning("RoadTool: PREVIEW_INDEX out of range")
		return

	var scene := world_theme.road_variants[PREVIEW_INDEX] as PackedScene
	if scene == null:
		push_warning("RoadTool: preview scene null at %d" % PREVIEW_INDEX)
		return

	# Swap this tile's cap to the preview road tile (does NOT set overlay)
	vg.preview_cap_at(chunk, v, scene)

	# Rotate it to match current direction
	_apply_preview_rotation()

func _apply_preview_rotation() -> void:
	if vg == null or chunk == null or anchor == null:
		return
	var step := TAU / 6.0
	var yaw := float(ghost_dir + edge_offset_steps) * step
	vg.preview_cap_rotate(anchor.grid_position_xz, yaw)

func _clear_preview() -> void:
	if vg == null or chunk == null or anchor == null:
		return
	# restore the normal terrain cap
	vg.clear_preview_cap(chunk, anchor)
