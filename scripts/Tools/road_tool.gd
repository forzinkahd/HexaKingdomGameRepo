extends Node
class_name RoadTool

@export_category("Dependencies")
@export var camera: Camera3D
@export var placement: PlacementSystem
@export var preview: PreviewSystem
@export var world_theme: WorldTheme

# Assign these from world_gen.gd after generation
var vg: VoxelGenerator = null
var chunk: Chunk = null

@export_category("Rules")
@export var require_grass: bool = true
@export var edge_offset_steps: int = 1 # your assets need +1

# Tool state
var active := false
var anchor: Voxel = null
var ghost_dir := 0
var preview_variant_index := 12
var preview_voxel: Voxel = null

var _place_anchor_first := false # NEW


func configure_runtime(_vg: VoxelGenerator, _chunk: Chunk) -> void:
	vg = _vg
	chunk = _chunk


func begin_from_voxel(v: Voxel) -> void:
	var sv: Voxel = WorldMap.surface_layer.get(v.grid_position_xz)
	if sv == null:
		return
	
	active = true
	anchor = sv
	ghost_dir = 0
	
	# NEW: if the starting tile is not already a road, first confirm should place here
	_place_anchor_first = (anchor.overlay != Voxel.Overlay.ROAD)
	
	_clear_preview()
	_update_preview()


func rotate_right() -> void:
	ghost_dir = (ghost_dir + 1) % 6
	_update_preview()


func rotate_left() -> void:
	ghost_dir = (ghost_dir + 5) % 6
	_update_preview()


func commit_current() -> void:
	if not active or anchor == null or preview_voxel == null:
		return
	
	var v := preview_voxel # capture the target BEFORE clearing anything
	
	var step := TAU / 6.0
	var yaw := float(ghost_dir + edge_offset_steps) * step
	
	# 1) Commit the overlay state first
	if placement != null:
		placement.set_road(v, true, preview_variant_index, yaw, true)
	
	# 2) Now clear preview bookkeeping (this will restore to overlay, not terrain)
	_clear_preview()


func cancel() -> void:
	_clear_preview()
	active = false
	anchor = null
	preview_voxel = null
	_place_anchor_first = false


func cycle_variant(delta: int) -> void:
	var n := world_theme.road_variants.size()
	if n <= 0:
		return
	preview_variant_index = (preview_variant_index + delta) % n
	if preview_variant_index < 0:
		preview_variant_index += n
	_update_preview()


func _update_preview() -> void:
	if not active or anchor == null or vg == null or chunk == null or world_theme == null:
		return

	_clear_preview()

	var target: Voxel = null

	if _place_anchor_first:
		# NEW: preview on the selected tile for the first placement only
		target = anchor
	else:
		# preview on the next tile in the chosen direction
		var dirs := VoxelData.get_tile_neighbor_table(anchor.grid_position_xz.x) # use your existing API
		var next_xz: Vector2i = anchor.grid_position_xz + Vector2i(int(dirs[ghost_dir].x), int(dirs[ghost_dir].y))
		target = WorldMap.surface_layer.get(next_xz)

	if target == null:
		return

	# don’t preview illegal placements
	if placement != null and placement.rules != null:
		if not placement.rules.can_place_road(target):
			return

	preview_voxel = target

	var step := TAU / 6.0
	var yaw := float(ghost_dir + edge_offset_steps) * step

	var scene := world_theme.road_variants[preview_variant_index]
	vg.preview_cap_at(chunk, preview_voxel, scene)
	vg.preview_cap_rotate(preview_voxel.grid_position_xz, yaw)

	if preview != null:
		preview.set_road_preview(preview_voxel.grid_position_xz, preview_variant_index, yaw)


func _clear_preview() -> void:
	if preview_voxel == null:
		return
	if vg == null or chunk == null:
		return

	vg.clear_preview_cap(chunk, preview_voxel)

	if preview != null:
		preview.clear_preview(preview_voxel.grid_position_xz)

	preview_voxel = null
