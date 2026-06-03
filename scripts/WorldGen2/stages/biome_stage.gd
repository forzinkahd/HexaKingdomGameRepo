class_name BiomeStage
extends RefCounted

func run(settings: GenerationSettingsV2, map: WorldMapData) -> void:
	for tile in map.tiles:
		if tile.is_ocean():
			tile.biome_kind = WorldTile.BiomeKind.OCEAN
			tile.terrain_kind = WorldTile.TerrainKind.SAND
			continue

		if _has_adjacent_water(map, tile):
			tile.biome_kind = WorldTile.BiomeKind.COAST
			tile.terrain_kind = WorldTile.TerrainKind.SAND
		elif tile.height_units >= settings.mountain_min_height_units:
			tile.biome_kind = WorldTile.BiomeKind.MOUNTAIN
			tile.terrain_kind = WorldTile.TerrainKind.STONE
		elif tile.height_units > settings.hills_max_height_units:
			tile.biome_kind = WorldTile.BiomeKind.HILLS
			tile.terrain_kind = WorldTile.TerrainKind.DIRT
		elif tile.noise_height >= settings.forest_noise_threshold and tile.height_units > settings.sea_level_units:
			tile.biome_kind = WorldTile.BiomeKind.FOREST
			tile.terrain_kind = WorldTile.TerrainKind.GRASS
		else:
			tile.biome_kind = WorldTile.BiomeKind.PLAINS
			tile.terrain_kind = WorldTile.TerrainKind.GRASS

func _has_adjacent_water(map: WorldMapData, tile: WorldTile) -> bool:
	for dir in HexGrid.AXIAL_DIRECTIONS:
		var n := map.get_tile(tile.coord + dir)
		if n != null and n.is_water():
			return true
	return false
