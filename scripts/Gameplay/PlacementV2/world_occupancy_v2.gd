class_name WorldOccupancyV2
extends Node

signal occupancy_changed(tile: WorldTile, occupant: Node3D)

var _occupied_by_coord: Dictionary = {}


func clear() -> void:
	_occupied_by_coord.clear()


func is_occupied(tile: WorldTile) -> bool:
	if tile == null:
		return false

	return _occupied_by_coord.has(tile.coord)


func get_occupant(tile: WorldTile) -> Node3D:
	if tile == null:
		return null

	return _occupied_by_coord.get(tile.coord, null)


func occupy(tile: WorldTile, occupant: Node3D) -> bool:
	if tile == null:
		push_warning("WorldOccupancyV2: cannot occupy null tile.")
		return false

	if occupant == null:
		push_warning("WorldOccupancyV2: cannot occupy tile with null occupant.")
		return false

	if is_occupied(tile):
		return false

	_occupied_by_coord[tile.coord] = occupant
	occupancy_changed.emit(tile, occupant)
	return true


func release(tile: WorldTile) -> void:
	if tile == null:
		return

	var occupant := get_occupant(tile)
	_occupied_by_coord.erase(tile.coord)
	occupancy_changed.emit(tile, occupant)


func release_by_occupant(occupant: Node3D) -> void:
	if occupant == null:
		return

	for coord in _occupied_by_coord.keys():
		if _occupied_by_coord[coord] == occupant:
			_occupied_by_coord.erase(coord)
			return


func occupied_count() -> int:
	return _occupied_by_coord.size()
