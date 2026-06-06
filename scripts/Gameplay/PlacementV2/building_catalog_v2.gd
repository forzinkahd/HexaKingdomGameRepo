class_name BuildingCatalogV2
extends Node

signal active_building_changed(definition: BuildingDefinition)
signal catalog_changed

@export var buildings: Array[BuildingDefinition] = []
@export var select_first_on_ready: bool = true

var active_definition: BuildingDefinition


func _ready() -> void:
	if select_first_on_ready and active_definition == null:
		select_first_available()


func set_buildings(new_buildings: Array[BuildingDefinition]) -> void:
	buildings = new_buildings
	catalog_changed.emit()

	if not buildings.has(active_definition):
		select_first_available()


func add_building(definition: BuildingDefinition) -> void:
	if definition == null:
		return

	if buildings.has(definition):
		return

	buildings.append(definition)
	catalog_changed.emit()

	if active_definition == null and select_first_on_ready:
		set_active_building(definition)


func remove_building(definition: BuildingDefinition) -> void:
	if definition == null:
		return

	buildings.erase(definition)
	catalog_changed.emit()

	if active_definition == definition:
		select_first_available()


func select_first_available() -> void:
	for definition in buildings:
		if definition != null:
			set_active_building(definition)
			return

	set_active_building(null)


func set_active_building(definition: BuildingDefinition) -> void:
	if active_definition == definition:
		return

	active_definition = definition
	active_building_changed.emit(active_definition)


func get_active_building() -> BuildingDefinition:
	return active_definition


func get_buildings() -> Array[BuildingDefinition]:
	var result: Array[BuildingDefinition] = []

	for definition in buildings:
		if definition != null:
			result.append(definition)

	return result


func find_by_id(id: StringName) -> BuildingDefinition:
	for definition in buildings:
		if definition != null and definition.id == id:
			return definition

	return null
