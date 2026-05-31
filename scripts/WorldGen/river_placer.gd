class_name RiverPlacer

# Places river overlay tiles connecting lakes to the ocean.
# Runs AFTER mesh generation since it uses the overlay system.
# Uses greedy downhill pathfinding.

func place(surface_voxels: Array[Voxel], vg: VoxelGenerator, chunk: Chunk, settings: GenerationSettings) -> void:
	if not settings.rivers_enabled:
		return

	# Classify which sea tiles are ocean (near buffer/edge) vs lake (inland)
	var ocean_tiles: Dictionary = {}   # xz -> true
	var lake_tiles: Dictionary = {}    # xz -> true

	for v in surface_voxels:
		if not v.is_sea:
			continue
		if _is_ocean(v):
			ocean_tiles[v.grid_position_xz] = true
		else:
			lake_tiles[v.grid_position_xz] = true

	if lake_tiles.is_empty():
		return

	# Find one "outlet" tile per lake cluster: land tile adjacent to lake,
	# chosen as the one closest to ocean (lowest height)
	var processed_lake_ids: Dictionary = {}
	var river_xz: Dictionary = {}
	var rivers_placed := 0

	for v in surface_voxels:
		if v.is_sea or v.buffer: continue

		# Is this land tile adjacent to a lake?
		var lake_id := _adjacent_lake_id(v, lake_tiles)
		if lake_id == Vector2i(-9999, -9999): continue
		if processed_lake_ids.has(lake_id): continue

		# Find the best outlet: land tile adjacent to this lake with lowest height
		var best_outlet := _find_best_outlet(lake_id, lake_tiles, surface_voxels)
		if best_outlet == null:
			processed_lake_ids[lake_id] = true
			continue

		# Pathfind from outlet to ocean
		var path := _pathfind_to_ocean(best_outlet, ocean_tiles, river_xz, settings)

		if path.size() >= settings.river_min_length:
			for rv in path:
				rv.overlay = Voxel.Overlay.RIVER
				river_xz[rv.grid_position_xz] = true
			rivers_placed += 1

		processed_lake_ids[lake_id] = true

	# Recalculate masks and refresh caps
	for xz in river_xz:
		var v: Voxel = WorldMap.surface_layer.get(xz)
		if v != null:
			_recalc_river_mask(v)

	for xz in river_xz:
		var v: Voxel = WorldMap.surface_layer.get(xz)
		if v != null:
			vg.refresh_overlay_at(chunk, v)
		# Also refresh neighbors so adjacent tiles get correct masks
		var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
		for i in range(6):
			var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
			if n != null:
				_recalc_river_mask(n)
				vg.refresh_overlay_at(chunk, n)

	print("Rivers placed: %d (tiles: %d)" % [rivers_placed, river_xz.size()])


func _is_ocean(v: Voxel) -> bool:
	# Ocean tiles are adjacent to map edge (null neighbor) or buffer tile
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if n == null or n.buffer:
			return true
	return false


func _adjacent_lake_id(v: Voxel, lake_tiles: Dictionary) -> Vector2i:
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		var nk := v.grid_position_xz + dirs[i]
		if lake_tiles.has(nk):
			return nk
	return Vector2i(-9999, -9999)


func _find_best_outlet(lake_id: Vector2i, lake_tiles: Dictionary, surface_voxels: Array[Voxel]) -> Voxel:
	# Flood-fill the lake cluster, collect all adjacent land tiles, return lowest
	var lake_cluster: Dictionary = {}
	var frontier: Array[Vector2i] = [lake_id]
	lake_cluster[lake_id] = true

	while frontier.size() > 0:
		var cur: Vector2i = frontier.pop_back()
		var cv: Voxel = WorldMap.surface_layer.get(cur)
		if cv == null: continue
		var dirs := VoxelData.neighbor_dirs_for_col(cur.x)
		for i in range(6):
			var nk := cur + dirs[i]
			if lake_cluster.has(nk): continue
			var n: Voxel = WorldMap.surface_layer.get(nk)
			if n != null and n.is_sea and lake_tiles.has(nk):
				lake_cluster[nk] = true
				frontier.append(nk)

	# Find lowest land tile adjacent to any lake tile in cluster
	var best: Voxel = null
	var best_h := 999999

	for xz in lake_cluster:
		var lv: Voxel = WorldMap.surface_layer.get(xz)
		if lv == null: continue
		var dirs := VoxelData.neighbor_dirs_for_col(xz.x)
		for i in range(6):
			var n: Voxel = WorldMap.surface_layer.get(xz + dirs[i])
			if n == null or n.is_sea or n.buffer: continue
			if n.height_units < best_h:
				best_h = n.height_units
				best = n

	return best


func _pathfind_to_ocean(start: Voxel, ocean_tiles: Dictionary, avoid: Dictionary, settings: GenerationSettings) -> Array[Voxel]:
	var path: Array[Voxel] = []
	var visited: Dictionary = {}
	var current := start
	var max_steps := 80

	while max_steps > 0:
		max_steps -= 1
		if visited.has(current.grid_position_xz):
			break

		visited[current.grid_position_xz] = true
		path.append(current)

		# Check adjacency to ocean
		var dirs := VoxelData.neighbor_dirs_for_col(current.grid_position_xz.x)
		var reached := false
		for i in range(6):
			var nk := current.grid_position_xz + dirs[i]
			var n: Voxel = WorldMap.surface_layer.get(nk)
			if n == null or ocean_tiles.has(nk):
				reached = true
				break

		if reached:
			break

		# Next: prefer downhill, allow flat, avoid uphill
		# Score: height_units (lower is better), with small penalty for going uphill
		var best: Voxel = null
		var best_score := 999999

		for i in range(6):
			var n: Voxel = WorldMap.surface_layer.get(current.grid_position_xz + dirs[i])
			if n == null or visited.has(n.grid_position_xz): continue
			if n.is_sea or n.water: continue
			if n.buffer: continue
			if avoid.has(n.grid_position_xz): continue
			# Strongly prefer downhill or flat
			var uphill_penalty : Variant = max(0, n.height_units - current.height_units) * 5
			var score : Variant = n.height_units + uphill_penalty
			if score < best_score:
				best_score = score
				best = n

		if best == null:
			break
		current = best

	return path


func _recalc_river_mask(v: Voxel) -> void:
	if v.overlay != Voxel.Overlay.RIVER:
		v.river_mask = 0
		return
	var mask := 0
	var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
	for i in range(6):
		var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
		if n != null and n.overlay == Voxel.Overlay.RIVER:
			mask |= (1 << i)
	v.river_mask = mask
