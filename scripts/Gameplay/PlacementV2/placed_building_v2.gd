class_name PlacedBuildingV2
extends Node3D

var definition: BuildingDefinition
var tile: WorldTile


func setup(source_definition: BuildingDefinition, source_tile: WorldTile) -> void:
	definition = source_definition
	tile = source_tile

	if definition != null:
		name = "Building_%s_%s_%s" % [definition.id, tile.coord.x, tile.coord.y]
	else:
		name = "Building_%s_%s" % [tile.coord.x, tile.coord.y]


func get_display_name() -> String:
	if definition == null:
		return "Unknown Building"

	return definition.display_name
