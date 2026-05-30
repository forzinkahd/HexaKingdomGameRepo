extends Node
class_name CoastSystem

# Masks are 6 bits. We will only accept "contiguous runs" of length 1..4.
# If not representable, we degrade to E (filler) or A (single).

static func recalc(surface_tiles: Array[Voxel], sea_level_units: int) -> void:
	# Reset
	for v in surface_tiles:
		v.is_sea = (v.height_units <= sea_level_units)
		v.water = v.is_sea
		
		v.sea_is_coast_ring = false
		v.coast_mask = 0
		
		v.has_coast_cap = false
		v.coast_variant = ""
		v.coast_yaw = 0.0
		
	# Coast ring: SEA tiles that touch LAND
	for v in surface_tiles:
		if not v.is_sea:
			continue
		
		var mask_to_land := _mask_to_land(v)
		if mask_to_land == 0:
			continue
		
		v.sea_is_coast_ring = true
		
		# IMPORTANT: your art is defined by SEA connections, not LAND connections.
		# Convert land-neighbor mask into "sea edges mask":
		# sea_edges are the edges that are NOT land-touching.
		var sea_mask := (~mask_to_land) & 0x3F
		
		# Classify sea_mask into A/B/C/D/E and compute yaw from the contiguous run
		var result := _coast_variant_and_yaw_from_sea_mask(sea_mask)
		
		v.has_coast_cap = true
		v.coast_variant = result.variant
		v.coast_yaw = result.yaw
		
		# keep for debugging/inspection if you want
		v.coast_mask = sea_mask


static func _mask_to_land(v: Voxel) -> int:
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if n != null and (not n.is_sea):
			mask |= (1 << i)
	return mask


# Returns a Dictionary {variant: String, yaw: float}
# sea_mask meaning: bit i == 1 means "edge i is sea" (water is open on that edge)
static func _coast_variant_and_yaw_from_sea_mask(sea_mask: int) -> Dictionary:
	var count := VoxelData.mask_bit_count(sea_mask)
	
	# Your definition:
	# A: 1 sea edge
	# B: 2 adjacent sea edges
	# C: 3 adjacent sea edges
	# D: 4 adjacent sea edges
	# E: 0 sea edges (filler / tiny beaches)
	#
	# We must reject non-adjacent patterns (like 1+3). For those, choose a fallback.
	
	if count == 0:
		return {"variant": "E", "yaw": 0.0}
	
	# Find the best contiguous run of 1s in sea_mask (circular)
	var run := _best_contiguous_run(sea_mask)
	
	# run.len is 1..6, run.start is 0..5
	# If the mask is fragmented, run.len will be < count.
	# We degrade by taking the largest run only.
	var run_len: int = run.len
	var start_edge: int = run.start
	
	# Clamp run_len to supported set (1..4). If 5/6 ever happens, treat as 4.
	if run_len >= 4:
		run_len = 4
	
	var variant := ""
	match run_len:
		1: variant = "A"
		2: variant = "B"
		3: variant = "C"
		4: variant = "D"
		_: variant = "A"
	
	# Yaw: rotate so that the run's START EDGE aligns with the mesh's authored "start".
	# You will tune this once.
	var yaw: float = VoxelData.yaw_from_edge(start_edge, VoxelData.COAST_ASSET_EDGE0_OFFSET_STEPS)
	
	return {"variant": variant, "yaw": yaw}


# Find the longest contiguous run of 1 bits on a 6-bit ring.
# Returns {start:int, len:int}
static func _best_contiguous_run(mask: int) -> Dictionary:
	var best_len := 0
	var best_start := 0
	
	for start in range(6):
		# only consider starts where bit is 1
		if (mask & (1 << start)) == 0:
			continue
		
		var l := 0
		for k in range(6):
			var i := (start + k) % 6
			if (mask & (1 << i)) != 0:
				l += 1
			else:
				break
		
		if l > best_len:
			best_len = l
			best_start = start

	# If mask is 0, return 0
	return {"start": best_start, "len": best_len}
	
