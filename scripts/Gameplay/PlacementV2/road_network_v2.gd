class_name RoadNetworkV2
extends Node3D

signal road_placed(coord: Vector2i)
signal road_removed(coord: Vector2i)
signal roads_changed

@export var economy: WorldEconomyV2
@export var occupancy: WorldOccupancyV2
@export var road_root: Node3D
@export var road_scene: PackedScene

@export_group("Cost")
@export var cost_wood: int = 2
@export var cost_stone: int = 0

@export_group("Visual")
@export var road_y_offset: float = 0.08
@export var fallback_road_color: Color = Color(0.45, 0.32, 0.18)

var world_map: WorldMapData
var _roads_by_coord: Dictionary = {}


func _ready() -> void:
	add_to_group("road_network")

	if economy == null:
		economy = get_node_or_null("../WorldEconomyV2") as WorldEconomyV2

	if occupancy == null:
		occupancy = get_node_or_null("../WorldOccupancyV2") as WorldOccupancyV2

	if road_root == null:
		road_root = Node3D.new()
		road_root.name = "Roads"
		add_child(road_root)


func configure_world_map(source_world_map: WorldMapData) -> void:
	world_map = source_world_map


func has_road_at_coord(coord: Vector2i) -> bool:
	return _roads_by_coord.has(coord)


func can_place_road(tile: WorldTile) -> bool:
	return get_road_invalid_reason(tile) == ""


func get_road_invalid_reason(tile: WorldTile) -> String:
	if tile == null:
		return "No tile selected"
	
	if tile.water_kind != WorldTile.WaterKind.NONE:
		return "Cannot build road on water"
	
	if has_road_at_coord(tile.coord):
		return "Road already exists"
	
	if _is_tile_occupied(tile):
		return "Tile is occupied"
	
	if not _can_afford_road():
		return _missing_cost_reason()
	
	return ""


func _is_tile_occupied(tile: WorldTile) -> bool:
	if tile == null or occupancy == null:
		return false
	
	if occupancy.has_method("is_coord_occupied"):
		return bool(occupancy.call("is_coord_occupied", tile.coord))
	
	if occupancy.has_method("get_occupant_at_coord"):
		return occupancy.call("get_occupant_at_coord", tile.coord) != null
	
	return false


func place_road(tile: WorldTile, visual_node: Node3D = null, free: bool = false) -> bool:
	if tile == null:
		return false

	var reason := get_road_invalid_reason(tile)

	if reason != "" and not free:
		push_warning("RoadNetworkV2: road placement failed: %s" % [reason])
		return false

	if not free:
		if not _spend_road_cost():
			push_warning("RoadNetworkV2: could not spend road cost.")
			return false

	var road_visual := _make_road_visual()
	road_visual.name = "Road_%s_%s" % [tile.coord.x, tile.coord.y]

	var base_position := tile.world_position

	if visual_node != null and is_instance_valid(visual_node):
		base_position = visual_node.global_position

	road_visual.global_position = base_position + Vector3.UP * road_y_offset
	road_visual.set_meta("coord", tile.coord)
	road_visual.set_meta("world_tile", tile)

	road_root.add_child(road_visual)

	_roads_by_coord[tile.coord] = road_visual

	road_placed.emit(tile.coord)
	roads_changed.emit()

	return true


func clear_roads() -> void:
	_roads_by_coord.clear()

	if road_root != null:
		for child in road_root.get_children():
			child.queue_free()

	roads_changed.emit()


func get_save_data() -> Array:
	var result: Array = []

	for coord in _roads_by_coord.keys():
		if coord is Vector2i:
			result.append({
				"coord_x": coord.x,
				"coord_y": coord.y
			})

	return result


func load_save_data(data: Array) -> void:
	clear_roads()

	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var coord := Vector2i(
			int(entry.get("coord_x", 0)),
			int(entry.get("coord_y", 0))
		)

		var tile := _get_tile_by_coord(coord)

		if tile == null:
			push_warning("RoadNetworkV2: could not load road at %s" % [str(coord)])
			continue

		place_road(tile, null, true)


func _get_tile_by_coord(coord: Vector2i) -> WorldTile:
	if world_map == null:
		return null

	if world_map.has_method("get_tile"):
		return world_map.call("get_tile", coord) as WorldTile

	var tiles_by_coord = world_map.get("tiles_by_coord")

	if tiles_by_coord is Dictionary and tiles_by_coord.has(coord):
		return tiles_by_coord[coord] as WorldTile

	var tiles = world_map.get("tiles")

	if tiles is Array:
		for tile in tiles:
			if tile is WorldTile and tile.coord == coord:
				return tile

	return null


func _make_road_visual() -> Node3D:
	if road_scene != null:
		var instance := road_scene.instantiate() as Node3D

		if instance != null:
			return instance

	return _fallback_road_visual()


func _fallback_road_visual() -> Node3D:
	var root := Node3D.new()
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FallbackRoadVisual"
	
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.48
	mesh.bottom_radius = 0.48
	mesh.height = 0.04
	mesh.radial_segments = 6
	
	mesh_instance.mesh = mesh
	
	# CylinderMesh height is along Y by default, so this already lies flat on the tile.
	mesh_instance.position = Vector3.ZERO
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback_road_color
	mesh_instance.material_override = mat
	
	root.add_child(mesh_instance)
	return root


func _can_afford_road() -> bool:
	return _has_resource(BuildingDefinition.ProducedResource.WOOD, cost_wood) \
		and _has_resource(BuildingDefinition.ProducedResource.STONE, cost_stone)


func _spend_road_cost() -> bool:
	if not _can_afford_road():
		return false

	_add_resource(BuildingDefinition.ProducedResource.WOOD, -cost_wood)
	_add_resource(BuildingDefinition.ProducedResource.STONE, -cost_stone)

	return true


func _has_resource(resource: BuildingDefinition.ProducedResource, amount: int) -> bool:
	if amount <= 0:
		return true

	if economy == null:
		return false

	if economy.has_method("get_resource_amount"):
		return int(economy.get_resource_amount(resource)) >= amount

	if economy.has_method("get_amount"):
		return int(economy.get_amount(resource)) >= amount

	return false


func _add_resource(resource: BuildingDefinition.ProducedResource, amount_delta: int) -> void:
	if amount_delta == 0:
		return

	if economy == null:
		return

	if economy.has_method("add_resource"):
		economy.add_resource(resource, amount_delta)
		return

	if economy.has_method("change_resource"):
		economy.change_resource(resource, amount_delta)
		return

	if economy.has_method("get_resource_amount") and economy.has_method("set_resource"):
		var current := int(economy.get_resource_amount(resource))
		economy.set_resource(resource, max(0, current + amount_delta))


func _missing_cost_reason() -> String:
	var parts: Array[String] = []

	if cost_wood > 0:
		parts.append("Wood %d" % [cost_wood])

	if cost_stone > 0:
		parts.append("Stone %d" % [cost_stone])

	if parts.is_empty():
		return "Cannot afford road"

	return "Requires: " + ", ".join(parts)
