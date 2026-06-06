class_name WorldOccupancyV2
extends Node

signal occupancy_changed(tile: WorldTile, occupant: Node3D)

var _occupied_by_coord: Dictionary = {}


func clear() -> void:
	_occupied_by_coord.clear()


func is_occupied(tile: WorldTile) -> bool:
	if tile == null:
		return false

	return is_coord_occupied(tile.coord)


func is_coord_occupied(coord: Vector2i) -> bool:
	return _occupied_by_coord.has(coord)


func get_occupant(tile: WorldTile) -> Node3D:
	if tile == null:
		return null

	return get_occupant_at_coord(tile.coord)


func get_occupant_at_coord(coord: Vector2i) -> Node3D:
	return _occupied_by_coord.get(coord, null)


func can_occupy_coords(coords: Array[Vector2i]) -> bool:
	for coord in coords:
		if is_coord_occupied(coord):
			return false

	return true


func occupy(tile: WorldTile, occupant: Node3D) -> bool:
	if tile == null:
		push_warning("WorldOccupancyV2: cannot occupy null tile.")
		return false

	return occupy_coords([tile.coord], occupant, tile)


func occupy_coords(coords: Array[Vector2i], occupant: Node3D, signal_tile: WorldTile = null) -> bool:
	if occupant == null:
		push_warning("WorldOccupancyV2: cannot occupy tile with null occupant.")
		return false

	if not can_occupy_coords(coords):
		return false

	for coord in coords:
		_occupied_by_coord[coord] = occupant

	occupancy_changed.emit(signal_tile, occupant)
	return true


func release(tile: WorldTile) -> void:
	if tile == null:
		return

	var occupant := get_occupant(tile)
	_occupied_by_coord.erase(tile.coord)
	occupancy_changed.emit(tile, occupant)


func release_coords(coords: Array[Vector2i]) -> void:
	for coord in coords:
		_occupied_by_coord.erase(coord)

	occupancy_changed.emit(null, null)


func release_by_occupant(occupant: Node3D) -> void:
	if occupant == null:
		return

	var to_remove: Array[Vector2i] = []

	for coord in _occupied_by_coord.keys():
		if _occupied_by_coord[coord] == occupant:
			to_remove.append(coord)

	for coord in to_remove:
		_occupied_by_coord.erase(coord)

	occupancy_changed.emit(null, occupant)


func occupied_count() -> int:
	return _occupied_by_coord.size()
