class_name BuildingRegistryV2
extends Node

signal building_registered(building: PlacedBuildingV2)
signal building_unregistered(building: PlacedBuildingV2)
signal registry_changed

@export var placement: BuildingPlacementV2
@export var auto_connect_placement: bool = true

var _buildings: Array[PlacedBuildingV2] = []
var _count_by_id: Dictionary = {}


func _ready() -> void:
	if auto_connect_placement:
		_connect_placement()


func _connect_placement() -> void:
	if placement == null:
		placement = get_node_or_null("../BuildingPlacementV2") as BuildingPlacementV2

	if placement == null:
		return

	if not placement.building_placed.is_connected(_on_building_placed):
		placement.building_placed.connect(_on_building_placed)


func _on_building_placed(building: PlacedBuildingV2, tile: WorldTile) -> void:
	register_building(building)


func register_building(building: PlacedBuildingV2) -> void:
	if building == null:
		return

	if _buildings.has(building):
		return

	_buildings.append(building)

	var id := _building_id(building)

	if id != &"":
		_count_by_id[id] = get_count(id) + 1

	building_registered.emit(building)
	registry_changed.emit()


func unregister_building(building: PlacedBuildingV2) -> void:
	if building == null:
		return

	if not _buildings.has(building):
		return

	_buildings.erase(building)

	var id := _building_id(building)

	if id != &"":
		var next_count: int = max(0, get_count(id) - 1)

		if next_count <= 0:
			_count_by_id.erase(id)
		else:
			_count_by_id[id] = next_count

	building_unregistered.emit(building)
	registry_changed.emit()


func clear() -> void:
	_buildings.clear()
	_count_by_id.clear()
	registry_changed.emit()


func has_building(id: StringName) -> bool:
	return get_count(id) > 0


func get_count(id: StringName) -> int:
	return int(_count_by_id.get(id, 0))


func get_total_count() -> int:
	return _buildings.size()


func get_all_buildings() -> Array[PlacedBuildingV2]:
	var result: Array[PlacedBuildingV2] = []

	for building in _buildings:
		if is_instance_valid(building):
			result.append(building)

	return result


func get_buildings_by_id(id: StringName) -> Array[PlacedBuildingV2]:
	var result: Array[PlacedBuildingV2] = []

	for building in _buildings:
		if not is_instance_valid(building):
			continue

		if _building_id(building) == id:
			result.append(building)

	return result


func get_first_building_by_id(id: StringName) -> PlacedBuildingV2:
	for building in _buildings:
		if not is_instance_valid(building):
			continue

		if _building_id(building) == id:
			return building

	return null


func is_unlocked(definition: BuildingDefinition) -> bool:
	if definition == null:
		return false

	var required = definition.get("required_building_ids")

	if required == null:
		return true

	for required_id in required:
		if not has_building(required_id):
			return false

	return true


func missing_requirements(definition: BuildingDefinition) -> Array[StringName]:
	var missing: Array[StringName] = []

	if definition == null:
		return missing

	var required = definition.get("required_building_ids")

	if required == null:
		return missing

	for required_id in required:
		if not has_building(required_id):
			missing.append(required_id)

	return missing


func unlock_reason(definition: BuildingDefinition) -> String:
	if definition == null:
		return "No building"

	var missing := missing_requirements(definition)

	if missing.is_empty():
		return "Unlocked"

	var parts: Array[String] = []

	for id in missing:
		parts.append(str(id))

	return "Requires: " + ", ".join(parts)


func is_unique_limit_reached(definition: BuildingDefinition) -> bool:
	if definition == null:
		return false

	var is_unique_value = definition.get("is_unique")
	if is_unique_value == null or not bool(is_unique_value):
		return false

	var limit_value = definition.get("unique_limit")
	var limit := 1

	if limit_value != null:
		limit = max(1, int(limit_value))

	return get_count(definition.id) >= limit


func unique_reason(definition: BuildingDefinition) -> String:
	if definition == null:
		return "No building"

	if not is_unique_limit_reached(definition):
		return "Unique available"

	var limit_value = definition.get("unique_limit")
	var limit := 1

	if limit_value != null:
		limit = max(1, int(limit_value))

	var scope_value = definition.get("unique_scope_label")
	var scope := "town"

	if scope_value != null:
		scope = str(scope_value)

	if limit <= 1:
		return "Only one per %s" % [scope]

	return "Limit reached: %d per %s" % [limit, scope]


func is_available(definition: BuildingDefinition) -> bool:
	return is_unlocked(definition) and not is_unique_limit_reached(definition)


func availability_reason(definition: BuildingDefinition) -> String:
	if definition == null:
		return "No building"

	if not is_unlocked(definition):
		return unlock_reason(definition)

	if is_unique_limit_reached(definition):
		return unique_reason(definition)

	return "Available"


func _building_id(building: PlacedBuildingV2) -> StringName:
	if building == null:
		return &""

	if building.definition == null:
		return &""

	return building.definition.id
