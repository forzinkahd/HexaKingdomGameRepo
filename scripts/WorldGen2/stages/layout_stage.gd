class_name LayoutStage
extends RefCounted

func run(settings: GenerationSettingsV2, map: WorldMapData) -> void:
	map.clear()
	map.radius = settings.radius
	for coord in HexGrid.hexagonal_positions(settings.radius):
		var tile := WorldTile.new()
		tile.coord = coord
		tile.world_position = HexGrid.axial_to_world(coord, settings.tile_size)
		map.add_tile(tile)
