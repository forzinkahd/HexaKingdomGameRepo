extends Node
class_name CoastSystem


static func apply(surface_tiles: Array[Voxel], settings: GenerationSettings) -> void:
	for v in surface_tiles:
		v.has_coast_cap = false
		v.coast_mask = 0
		v.coast_variant = ""
		v.coast_yaw = 0.0
		v.sea_is_coast_ring = false

	for v in surface_tiles:
		if not v.is_water:
			continue

		var land_mask := _neighbor_mask(v, false)
		if land_mask == 0:
			continue

		var water_mask := _neighbor_mask(v, true)
		var authored_mask := land_mask if settings.coast_mask_uses_land_edges else water_mask

		var result := _coast_result_from_mask(authored_mask, settings.coast_yaw_offset_steps)

		v.has_coast_cap = true
		v.sea_is_coast_ring = true
		v.coast_mask = authored_mask
		v.coast_variant = result.variant
		v.coast_yaw = result.yaw


static func _neighbor_mask(v: Voxel, want_water: bool) -> int:
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)

	for i in range(6):
		var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if n == null:
			continue

		if n.is_water == want_water:
			mask |= (1 << i)

	return mask


static func _coast_result_from_mask(mask: int, offset_steps: int) -> Dictionary:
	if mask == 0:
		return {
			"variant": "E",
			"yaw": 0.0
		}

	var run := _best_contiguous_run(mask)
	var run_len: int = clampi(run.len, 1, 4)
	var start_edge: int = run.start

	var variant := "A"
	match run_len:
		1:
			variant = "A"
		2:
			variant = "B"
		3:
			variant = "C"
		4:
			variant = "D"

	return {
		"variant": variant,
		"yaw": VoxelData.yaw_from_edge(start_edge, offset_steps)
	}


static func _best_contiguous_run(mask: int) -> Dictionary:
	var best_start := 0
	var best_len := 0

	for start in range(6):
		if (mask & (1 << start)) == 0:
			continue

		var length := 0

		for k in range(6):
			var edge := (start + k) % 6
			if (mask & (1 << edge)) != 0:
				length += 1
			else:
				break

		if length > best_len:
			best_start = start
			best_len = length

	return {
		"start": best_start,
		"len": best_len
	}
