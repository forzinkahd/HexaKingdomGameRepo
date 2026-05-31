class_name HexTransition

# Rotate a 6-bit hex neighbor mask clockwise by `steps` positions.
# CW step = connection at direction i moves to direction (i+1) mod 6.
static func rotate_mask_cw(mask: int, steps: int) -> int:
	var m := mask & 0x3F
	steps = ((steps % 6) + 6) % 6
	if steps == 0:
		return m
	return ((m << steps) | (m >> (6 - steps))) & 0x3F


# Find the minimum mask value under all rotations (canonical form).
# Returns {canonical: int, cw_steps: int}
# cw_steps = how many CW steps were applied to reach canonical from original.
static func canonicalize(mask: int) -> Dictionary:
	var m := mask & 0x3F
	var best_mask := m
	var best_steps := 0
	for steps in range(1, 6):
		var r := rotate_mask_cw(m, steps)
		if r < best_mask:
			best_mask = r
			best_steps = steps
	return {"canonical": best_mask, "cw_steps": best_steps}


# Convert cw_steps from canonicalize() into a world-space rotation.y.
# baked_offset: the facing angle already baked into the asset (radians).
static func rotation_from_steps(cw_steps: int, baked_offset: float = 0.0) -> float:
	return float(cw_steps) * (PI / 3.0) + baked_offset


static func are_bits_adjacent(mask: int) -> bool:
	if bit_count(mask) != 2:
		return false
	var bits: Array[int] = []
	for i in range(6):
		if (mask & (1 << i)) != 0:
			bits.append(i)
	var diff := (bits[1] - bits[0] + 6) % 6
	return diff == 1 or diff == 5


# Compute a 6-bit neighbor mask for any transition type.
# condition(neighbor: Voxel) -> bool: return true if this neighbor triggers the transition.
# Null neighbors (map edge) are passed as null — let your condition handle them.
static func compute_mask(v: Voxel, condition: Callable) -> int:
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if condition.call(n):
			mask |= (1 << i)
	return mask


static func bit_count(mask: int) -> int:
	var c := 0
	for i in range(6):
		if (mask & (1 << i)) != 0:
			c += 1
	return c
