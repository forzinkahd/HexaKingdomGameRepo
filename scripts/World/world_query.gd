class_name WorldQuery
extends RefCounted

var map: WorldMapData

func _init(p_map: WorldMapData = null) -> void:
	map = p_map

func get_tile(coord: Vector2i) -> WorldTile:
	if map == null:
		return null
	return map.get_tile(coord)

func neighbors(coord: Vector2i) -> Array[WorldTile]:
	var result: Array[WorldTile] = []
	if map == null:
		return result
	for dir in HexGrid.AXIAL_DIRECTIONS:
		var n := map.get_tile(coord + dir)
		if n != null:
			result.append(n)
	return result

func has_adjacent_water(tile: WorldTile) -> bool:
	for n in neighbors(tile.coord):
		if n.is_water():
			return true
	return false

func has_adjacent_land(tile: WorldTile) -> bool:
	for n in neighbors(tile.coord):
		if n.is_land():
			return true
	return false
