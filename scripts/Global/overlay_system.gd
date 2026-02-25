extends Node
class_name OverlaySystem

# =================================================
# MIGHT BE REDUNDANT AFTER REFACTOR 25.02.26
# =================================================

func set_road(v: Voxel, on: bool) -> void:
	if v == null:
		return
	
	if on:
		v.overlay = Voxel.Overlay.ROAD
	else:
		if v.overlay == Voxel.Overlay.ROAD:
			v.overlay = Voxel.Overlay.NONE
	_recalc_masks_around(v)


func set_river(v: Voxel, on: bool) -> void:
	if v == null:
		return
	
	if on:
		v.overlay = Voxel.Overlay.RIVER
		# rivers should usually make tile not walkable unless bridged
		v.walkable = false
		v.move_cost = INF
	else:
		if v.overlay == Voxel.Overlay.RIVER:
			v.overlay = Voxel.Overlay.NONE
		v.walkable = true
		v.move_cost = 1.0
	_recalc_masks_around(v)


func _recalc_masks_around(center: Voxel) -> void:
	_recalc_masks(center)
	var dirs: Array = VoxelData.get_tile_neighbor_table(center.grid_position_xz.x)
	for i in range(6):
		var nk: Vector2i = center.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n != null:
			_recalc_masks(n)


func _recalc_masks(v: Voxel) -> void:
	v.road_mask = _calc_mask(v, Voxel.Overlay.ROAD)
	v.river_mask = _calc_mask(v, Voxel.Overlay.RIVER)
	
	# update movement cost (roads cheaper) - safe now, useful later
	if v.overlay == Voxel.Overlay.ROAD:
		v.walkable = true
		v.move_cost = 0.6
	elif v.overlay == Voxel.Overlay.RIVER:
		v.walkable = false
		v.move_cost = INF
	else:
		v.walkable = true
		v.move_cost = 1.0


func _calc_mask(v: Voxel, which: int) -> int:
	if v.overlay != which:
		return 0
	
	var mask := 0
	var dirs: Array = VoxelData.get_tile_neighbor_table(v.grid_position_xz.x)
	for i in range(6):
		var nk: Vector2i = v.grid_position_xz + dirs[i]
		var n: Voxel = WorldMap.surface_layer.get(nk)
		if n != null and n.overlay == which:
			mask |= (1 << i)
	return mask
