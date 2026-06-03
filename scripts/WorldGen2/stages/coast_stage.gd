class_name CoastStage
extends RefCounted

func run(_settings: GenerationSettingsV2, map: WorldMapData) -> void:
	for tile in map.tiles:
		tile.coast_mask = 0
		tile.coast_variant_index = -1
		tile.coast_yaw = 0.0

	for tile in map.tiles:
		if not tile.is_water():
			continue
		var mask := 0
		for i in range(6):
			var n := map.get_tile(tile.coord + HexGrid.AXIAL_DIRECTIONS[i])
			if n != null and n.is_land():
				mask |= 1 << i
		if mask == 0:
			continue
		tile.coast_mask = mask
		tile.coast_variant_index = HexGrid.coast_variant_index(mask)
		tile.coast_yaw = HexGrid.yaw_from_mask(tile, map, mask)
