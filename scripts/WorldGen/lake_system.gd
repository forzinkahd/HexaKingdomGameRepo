extends Node
class_name LakeSystem


static func apply(surface_tiles: Array[Voxel], settings: GenerationSettings) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.map_seed) + 91231

	var candidates: Array[Voxel] = []

	for v in surface_tiles:
		if _can_seed_lake(v, settings):
			candidates.append(v)

	candidates.shuffle()

	var lake_id := 1
	var attempts: int = min(settings.lake_attempts, candidates.size())

	for i in range(attempts):
		var center := candidates[i]
		if not _can_seed_lake(center, settings):
			continue

		var radius := rng.randi_range(1, settings.lake_max_radius)
		var positions := _hex_disk(center.grid_position_xz, radius)

		var lake_tiles: Array[Voxel] = []
		var valid := true

		for xz in positions:
			var v: Voxel = WorldMap.surface_layer.get(xz)
			if v == null or not _can_be_lake_tile(v, settings):
				valid = false
				break
			lake_tiles.append(v)

		if not valid:
			continue

		if lake_tiles.size() < settings.lake_min_size_tiles:
			continue

		if _touches_ocean(lake_tiles):
			continue

		for v in lake_tiles:
			v.surface_kind = Voxel.SurfaceKind.LAKE
			v.is_water = true
			v.water = true
			v.is_sea = false
			v.water_body_id = lake_id

		lake_id += 1


static func _can_seed_lake(v: Voxel, settings: GenerationSettings) -> bool:
	if v == null:
		return false
	if v.surface_kind != Voxel.SurfaceKind.LAND:
		return false
	if v.buffer:
		return false
	if v.height_units < settings.lake_min_height_units:
		return false
	if v.height_units > settings.lake_max_height_units:
		return false
	if v.has_building() or v.has_resource():
		return false
	return true


static func _can_be_lake_tile(v: Voxel, settings: GenerationSettings) -> bool:
	return _can_seed_lake(v, settings)


static func _touches_ocean(tiles: Array[Voxel]) -> bool:
	for v in tiles:
		var dirs := VoxelData.neighbor_dirs_for_col(v.grid_position_xz.x)
		for i in range(6):
			var n: Voxel = WorldMap.surface_layer.get(v.grid_position_xz + dirs[i])
			if n != null and n.surface_kind == Voxel.SurfaceKind.OCEAN:
				return true
	return false


static func _hex_disk(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for dq in range(-radius, radius + 1):
		for dr in range(-radius, radius + 1):
			var p := Vector2i(center.x + dq, center.y + dr)
			if _hex_distance(center, p) <= radius:
				out.append(p)

	return out


static func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var aq := a.x
	var ar := a.y
	var as_ := -aq - ar

	var bq := b.x
	var br := b.y
	var bs := -bq - br

	return max(abs(aq - bq), abs(ar - br), abs(as_ - bs))
