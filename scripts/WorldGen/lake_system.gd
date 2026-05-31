extends Object
class_name LakeSystem


static func apply_lakes(voxels: Array[Voxel], settings: GenerationSettings) -> void:
	if settings.lake_attempts <= 0:
		return

	var by_xz := {}
	for v in voxels:
		by_xz[v.grid_position_xz] = v

	var lake_id := 0
	var candidates := _lake_candidates(voxels, settings)

	candidates.shuffle()

	var made := 0
	for seed: Voxel in candidates:
		if made >= settings.lake_attempts:
			break
		if seed.water:
			continue

		var lake := _grow_lake(seed, by_xz, settings)
		if lake.size() < settings.lake_min_tiles:
			continue

		for v: Voxel in lake:
			v.height_units = settings.sea_level_units
			v.water = true
			v.is_sea = false
			v.water_kind = Voxel.WaterKind.LAKE
			v.water_body_id = lake_id
			v.walkable = false
			v.move_cost = INF

		lake_id += 1
		made += 1


static func _lake_candidates(voxels: Array[Voxel], settings: GenerationSettings) -> Array[Voxel]:
	var out: Array[Voxel] = []

	for v in voxels:
		if v.buffer:
			continue
		if v.water:
			continue
		if v.height_units > settings.lake_max_height_units:
			continue
		if _distance_from_forced_ocean_edge(v.grid_position_xz, settings) < settings.lake_margin_from_ocean_edge:
			continue

		out.append(v)

	return out


static func _grow_lake(seed: Voxel, by_xz: Dictionary, settings: GenerationSettings) -> Array[Voxel]:
	var target_size := randi_range(settings.lake_min_tiles, settings.lake_max_tiles)

	var result: Array[Voxel] = []
	var frontier: Array[Voxel] = [seed]
	var visited := {}

	while not frontier.is_empty() and result.size() < target_size:
		var v := frontier.pop_front() as Voxel
		if visited.has(v.grid_position_xz):
			continue

		visited[v.grid_position_xz] = true

		if v.water:
			continue
		if v.height_units > settings.lake_max_height_units:
			continue
		if _distance_from_forced_ocean_edge(v.grid_position_xz, settings) < settings.lake_margin_from_ocean_edge:
			continue

		result.append(v)

		var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
		for i in range(6):
			var n: Voxel = by_xz.get(v.grid_position_xz + dirs[i])
			if n == null:
				continue
			if visited.has(n.grid_position_xz):
				continue

			# Randomized expansion prevents perfect circles but still keeps blobs compact.
			if randf() < 0.75:
				frontier.append(n)

	return result


static func _distance_from_forced_ocean_edge(xz: Vector2i, settings: GenerationSettings) -> int:
	var q := xz.x
	var r := xz.y
	var s := -q - r
	var radius := settings.radius

	match settings.forced_ocean_edge:
		"WEST":
			return q + radius
		"EAST":
			return radius - q
		"NORTH_WEST":
			return r + radius
		"SOUTH_EAST":
			return radius - r
		"NORTH_EAST":
			return s + radius
		"SOUTH_WEST":
			return radius - s
		_:
			return q + radius
