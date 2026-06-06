class_name PlacedBuildingV2
extends Node3D

var definition: BuildingDefinition
var tile: WorldTile
var occupied_coords: Array[Vector2i] = []


func setup(
	source_definition: BuildingDefinition,
	source_tile: WorldTile,
	source_occupied_coords: Array[Vector2i] = []
) -> void:
	definition = source_definition
	tile = source_tile
	occupied_coords = source_occupied_coords

	if definition != null:
		name = "Building_%s_%s_%s" % [definition.id, tile.coord.x, tile.coord.y]
	else:
		name = "Building_%s_%s" % [tile.coord.x, tile.coord.y]


func get_display_name() -> String:
	if definition == null:
		return "Unknown Building"

	return definition.display_name


func is_production_building() -> bool:
	if definition == null:
		return false

	return (
		definition.produces_resource != BuildingDefinition.ProducedResource.NONE
		and definition.production_amount > 0
	)


func production_status_text() -> String:
	if not is_production_building():
		return "No production"

	return definition.production_summary()
