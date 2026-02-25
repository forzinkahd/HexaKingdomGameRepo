extends Node
class_name OverlayConnectivity

# -------------------------------------------
# COMPUTE ROAD/RIVER - MASK FROM NEIGHBORS
# -------------------------------------------

func recalc_road_around(center: Voxel) -> void:
	if center == null:
		return
	
	_recalc_road(center)
	var dirs := VoxelData.neighbor_dirs_for_col(center.grid_position_xz.x)
	for i in range(6):
		var n: Variant = WorldMap.surface_layer.get(center.grid_position_xz + dirs[i])
		if n != null:
			_recalc_road(n)


func _recalc_road(v: Voxel) -> void:
	if v.overlay != Voxel.Overlay.ROAD:
		v.road_mask = 0
		return
	
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		var n: Variant = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if n != null and n.overlay == Voxel.Overlay.ROAD:
			mask |= (1 << i)
	v.road_mask = mask
