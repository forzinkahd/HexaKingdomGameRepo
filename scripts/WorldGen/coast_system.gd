extends Object
class_name CoastSystem

const COAST_A := 0
const COAST_B := 1
const COAST_C := 2
const COAST_D := 3
const COAST_E := 4

#const COAST_EDGE_OFFSET_STEPS := 1 # tune only once after assets are aligned


static func rebuild(surface_tiles: Array[Voxel]) -> void:
	for v in surface_tiles:
		v.is_coast = false
		v.coast_mask = 0
		v.coast_variant_index = -1
		v.coast_yaw = 0.0

	for v in surface_tiles:
		if _is_water(v):
			continue

		var mask := _water_neighbor_mask(v)
		if mask == 0:
			continue

		var resolved := _resolve_contiguous_coast(mask)
		v.is_coast = true
		v.coast_mask = mask
		v.coast_variant_index = int(resolved.x)
		v.coast_yaw = resolved.y


static func _water_neighbor_mask(v: Voxel) -> int:
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)

	for i in range(6):
		var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if n != null and _is_water(n):
			mask |= (1 << i)

	return mask


static func _is_water(v: Voxel) -> bool:
	if v == null:
		return false

	return v.water \
		or v.is_sea \
		or v.water_kind == Voxel.WaterKind.OCEAN \
		or v.water_kind == Voxel.WaterKind.LAKE \
		or v.water_kind == Voxel.WaterKind.RIVER


static func _resolve_contiguous_coast(mask: int) -> Vector2:
	var run := _contiguous_run(mask)
	var run_len := int(run.x)
	var run_start := int(run.y)

	if run_len <= 0:
		return Vector2(COAST_E, 0.0)

	var variant := COAST_E
	match run_len:
		1:
			variant = COAST_A
		2:
			variant = COAST_B
		3:
			variant = COAST_C
		4:
			variant = COAST_D
		_:
			variant = COAST_E

	var yaw := _coast_yaw_from_run(run_start, run_len)
	return Vector2(variant, yaw)


static func _coast_yaw_from_run(run_start: int, run_len: int) -> float:
	var step := TAU / 6.0

	# For A, center = start.
	# For B, center is halfway between two sides.
	# For C, center is the middle side.
	# For D, center is halfway between the two middle sides.
	var run_center := float(run_start) + (float(run_len) - 1.0) * 0.5

	# Tune this once based on how your coast assets are authored.
	# Start with 0. If all coast tiles are consistently rotated 60° off, change by +/-1.
	const COAST_ASSET_OFFSET_STEPS := 0.0

	return (run_center + COAST_ASSET_OFFSET_STEPS) * step


# Returns Vector2(run_len, run_start).
# If the set bits are not one contiguous circular run, returns Vector2(-1, 0).
static func _contiguous_run(mask: int) -> Vector2:
	var bits: Array[int] = []
	for i in range(6):
		if (mask & (1 << i)) != 0:
			bits.append(i)

	if bits.is_empty():
		return Vector2(0, 0)

	var count := bits.size()

	for start in range(6):
		var test_mask := 0
		for k in range(count):
			var side := (start + k) % 6
			test_mask |= (1 << side)

		if test_mask == mask:
			return Vector2(count, start)

	return Vector2(-1, 0)
