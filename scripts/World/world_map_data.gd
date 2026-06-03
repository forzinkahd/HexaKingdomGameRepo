class_name WorldMapData
extends RefCounted

var tiles: Array[WorldTile] = []
var by_coord: Dictionary = {}
var seed: int = 0
var radius: int = 0

func clear() -> void:
	tiles.clear()
	by_coord.clear()

func add_tile(tile: WorldTile) -> void:
	tiles.append(tile)
	by_coord[tile.coord] = tile

func get_tile(coord: Vector2i) -> WorldTile:
	return by_coord.get(coord, null)

func has_tile(coord: Vector2i) -> bool:
	return by_coord.has(coord)

func neighbors(tile: WorldTile) -> Array[WorldTile]:
	var result: Array[WorldTile] = []
	for dir in HexGrid.AXIAL_DIRECTIONS:
		var n := get_tile(tile.coord + dir)
		if n != null:
			result.append(n)
	return result

func land_tiles() -> Array[WorldTile]:
	var result: Array[WorldTile] = []
	for tile in tiles:
		if tile.is_land():
			result.append(tile)
	return result

func water_tiles() -> Array[WorldTile]:
	var result: Array[WorldTile] = []
	for tile in tiles:
		if tile.is_water():
			result.append(tile)
	return result

func placeable_tiles() -> Array[WorldTile]:
	var result: Array[WorldTile] = []
	for tile in tiles:
		if tile.can_place_building():
			result.append(tile)
	return result
