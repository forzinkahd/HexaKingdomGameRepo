extends Node
class_name PlacementSystem

# ------------------------------------
# CHANGING VOXEL STATE, RECALCs (building, overlay, etc)
# ------------------------------------

@export var rules: PlacementRules
@export var connectivity: OverlayConnectivity

var vg: VoxelGenerator
var chunk: Chunk


func configure_runtime(_vg: VoxelGenerator, _chunk: Chunk) -> void:
	vg = _vg
	chunk = _chunk


func set_road(v: Voxel, on: bool, variant_override: int = -1, yaw_override: float = 0.0, use_yaw_override: bool = false) -> bool:
	if v == null:
		return false
	
	# canonical surface voxel
	v = WorldMap.surface_layer.get(v.grid_position_xz) if WorldMap.surface_layer.has(v.grid_position_xz) else v
	
	if on:
		if rules != null and not rules.can_place_road(v):
			return false
		
		v.overlay = Voxel.Overlay.ROAD
		v.road_variant_override = variant_override
		
		# IMPORTANT: set yaw override BEFORE refresh
		if use_yaw_override:
			v.road_yaw_override = yaw_override
			v.has_road_yaw_override = true
	else:
		if v.overlay == Voxel.Overlay.ROAD:
			v.overlay = Voxel.Overlay.NONE
			v.road_variant_override = -1
			v.has_road_yaw_override = false
			v.road_yaw_override = 0.0
	
	if connectivity != null:
		connectivity.recalc_road_around(v)
	
	_refresh_overlay_neighborhood(v)
	return true


func _refresh_overlay_neighborhood(center: Voxel) -> void:
	if vg == null or chunk == null: return
	vg.refresh_overlay_at(chunk, center)
	for n in WorldMap.get_tile_neighbors_surface(center):
		vg.refresh_overlay_at(chunk, n)
