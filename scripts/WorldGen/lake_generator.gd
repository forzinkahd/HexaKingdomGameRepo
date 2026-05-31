class_name LakeGenerator

# Carves lakes into plains tiles BEFORE mesh generation.
# Lakes are blobs: at least min_size tiles, no thin arms.
# Each tile is set to sea_level_units height so it generates flat water geometry.

func generate(voxels: Array[Voxel], settings: GenerationSettings) -> void:
	if not settings.lakes_enabled:
		return

	# Build lookup
	var by_xz: Dictionary = {}
	for v in voxels:
		by_xz[v.grid_position_xz] = v

	# Deterministic RNG seeded to map
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(settings.map_seed + 1, 271828))

	# Collect plains candidates: above sea, at or below plains max, not buffer
	var candidates: Array[Voxel] = []
	for v in voxels:
		if v.buffer: continue
		if v.height_units <= settings.sea_level_units: continue
		if v.height_units > settings.plains_max_height_units: continue
		candidates.append(v)

	_shuffle(candidates, rng)

	var used: Dictionary = {}
	var lakes_made := 0
	var attempts := 0
	var max_attempts := candidates.size()

	for seed in candidates:
		if lakes_made >= settings.lake_count:
			break
		if attempts >= max_attempts:
			break
		attempts += 1

		if used.has(seed.grid_position_xz):
			continue

		var lake := _grow_blob(seed, by_xz, used, settings, rng)

		if lake.size() < settings.lake_min_size:
			# Too small — still mark these so we don't seed from them again
			continue

		# Trim to max size
		while lake.size() > settings.lake_max_size:
			lake.pop_back()

		# Verify no thin peninsulas: all tiles must have 2+ lake neighbors
		# (run a second pass and remove isolated tips)
		lake = _remove_thin_tips(lake, settings)

		if lake.size() < settings.lake_min_size:
			continue

		# Carve: set to sea level
		for lt in lake:
			lt.height_units = settings.sea_level_units
			used[lt.grid_position_xz] = true

		lakes_made += 1

	print("Generated %d lakes" % lakes_made)


func _grow_blob(seed: Voxel, by_xz: Dictionary, used: Dictionary, settings: GenerationSettings, rng: RandomNumberGenerator) -> Array[Voxel]:
	var in_lake: Dictionary = {}
	var lake: Array[Voxel] = []
	var frontier: Array[Voxel] = []

	in_lake[seed.grid_position_xz] = true
	lake.append(seed)
	frontier.append(seed)

	while frontier.size() > 0 and lake.size() < settings.lake_max_size:
		# Pick random frontier tile for organic shape
		var fi := rng.randi_range(0, frontier.size() - 1)
		var current: Voxel = frontier[fi]
		frontier.remove_at(fi)

		var dirs := VoxelData.neighbor_dirs_for_col(current.grid_position_xz.x)
		for i in range(6):
			if lake.size() >= settings.lake_max_size:
				break
			var nk := current.grid_position_xz + dirs[i]
			if in_lake.has(nk) or used.has(nk):
				continue
			var n: Voxel = by_xz.get(nk)
			if n == null or n.buffer:
				continue
			if n.height_units <= settings.sea_level_units:
				continue
			if n.height_units > settings.plains_max_height_units:
				continue

			# Thickness rule: require 2+ existing lake neighbors after first few tiles
			# This ensures no single-tile arms form
			if lake.size() > 4:
				var lcount := _count_lake_neighbors(n, in_lake)
				if lcount < 2:
					continue

			in_lake[nk] = true
			lake.append(n)
			frontier.append(n)

	return lake


func _remove_thin_tips(lake: Array[Voxel], settings: GenerationSettings) -> Array[Voxel]:
	# Iteratively remove tiles that have fewer than 2 lake neighbors
	# until stable. Prevents thin peninsulas.
	var in_lake: Dictionary = {}
	for v in lake:
		in_lake[v.grid_position_xz] = true

	var changed := true
	while changed:
		changed = false
		var to_remove: Array[Voxel] = []
		for v in lake:
			if _count_lake_neighbors(v, in_lake) < 2 and lake.size() - to_remove.size() > settings.lake_min_size:
				to_remove.append(v)
		for v in to_remove:
			in_lake.erase(v.grid_position_xz)
			lake.erase(v)
			changed = true

	return lake


func _count_lake_neighbors(v: Voxel, in_lake: Dictionary) -> int:
	var count := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		if in_lake.has(v.grid_position_xz + dirs[i]):
			count += 1
	return count


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp : Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
