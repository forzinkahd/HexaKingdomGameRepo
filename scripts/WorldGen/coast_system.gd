extends Object
class_name CoastSystem

const COAST_A := 0 # 1 adjacent land side
const COAST_B := 1 # 2 adjacent land sides
const COAST_C := 2 # 3 adjacent land sides
const COAST_D := 3 # 4 adjacent land sides
const COAST_E := 4 # fallback / filler

# Tune this only after the logic is correct.
# Try 0.0 first, then +/-1.0 if all coast pieces are one hex side off.
const COAST_ASSET_OFFSET_STEPS := -0.5


static func rebuild(surface_tiles: Array[Voxel]) -> void:
	for v in surface_tiles:
		v.is_coast = false
		v.coast_mask = 0
		v.coast_variant_index = -1
		v.coast_yaw = 0.0

	# Coast now belongs to WATER tiles that touch LAND.
	# This avoids lowering land caps into their own columns.
	for v in surface_tiles:
		if not _is_water(v):
			continue

		var mask := _land_neighbor_mask(v)
		if mask == 0:
			continue

		var resolved := _resolve_contiguous_coast(mask)
		v.is_coast = true
		v.coast_mask = mask
		v.coast_variant_index = int(resolved.x)
		v.coast_yaw = resolved.y


static func _land_neighbor_mask(v: Voxel) -> int:
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)

	for i in range(6):
		var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if n != null and not _is_water(n):
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


# Returns Vector2(variant_index, yaw)
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

	var yaw := _yaw_from_contiguous_run(run_start, run_len)
	return Vector2(variant, yaw)


static func _yaw_from_contiguous_run(run_start: int, run_len: int) -> float:
	var step := TAU / 6.0

	# For B/C/D, rotate toward the center of the adjacent land arc,
	# not merely toward the first side of the mask.
	var center_side := float(run_start) + (float(run_len) - 1.0) * 0.5

	return (center_side + COAST_ASSET_OFFSET_STEPS) * step


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
