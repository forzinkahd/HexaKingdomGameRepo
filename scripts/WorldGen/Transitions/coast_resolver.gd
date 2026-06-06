# scripts/WorldGen/transitions/coast_resolver.gd
class_name CoastResolverOld
extends RefCounted

"""func run(tiles: Array[WorldTile], by_xz: Dictionary[Vector2i, WorldTile]) -> void:
	for tile in tiles:
		tile.coast_mask = 0
		tile.coast_variant_index = -1
		tile.coast_yaw = 0.0

	for tile in tiles:
		if tile.water_kind == WorldTile.WaterKind.NONE:
			continue

		var mask := HexMask.mask_for(tile, by_xz, func(n):
			return n != null and n.water_kind == WorldTile.WaterKind.NONE
		)

		if mask == 0:
			continue

		var resolved := _resolve_contiguous_coast(mask)
		tile.coast_mask = mask
		tile.coast_variant_index = int(resolved.x)
		tile.coast_yaw = resolved.y"""
