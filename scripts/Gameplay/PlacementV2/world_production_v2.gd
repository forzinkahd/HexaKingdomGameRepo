class_name WorldProductionV2
extends Node

signal production_tick(resource: BuildingDefinition.ProducedResource, resource_name: String, amount: int)
signal production_building_registered(building: PlacedBuildingV2)
signal production_building_unregistered(building: PlacedBuildingV2)
signal productivity_changed(resource: BuildingDefinition.ProducedResource, multiplier: float)

@export var economy: WorldEconomyV2
@export var tick_enabled: bool = true
@export var print_debug: bool = false

@export_group("Global Tick Intervals")
@export_range(0.1, 9999.0) var wood_tick_seconds: float = 5.0
@export_range(0.1, 9999.0) var stone_tick_seconds: float = 5.0
@export_range(0.1, 9999.0) var food_tick_seconds: float = 5.0
@export_range(0.1, 9999.0) var gold_tick_seconds: float = 5.0

@export_group("Productivity Multipliers")
@export_range(0.0, 100.0) var wood_multiplier: float = 1.0
@export_range(0.0, 100.0) var stone_multiplier: float = 1.0
@export_range(0.0, 100.0) var food_multiplier: float = 1.0
@export_range(0.0, 100.0) var gold_multiplier: float = 1.0

var _production_buildings: Array[PlacedBuildingV2] = []
var _resource_progress: Dictionary = {}


func _ready() -> void:
	if economy == null:
		economy = get_node_or_null("../WorldEconomyV2") as WorldEconomyV2

	_reset_resource_progress()


func _process(delta: float) -> void:
	if not tick_enabled:
		return

	if economy == null:
		return

	_tick_resource(BuildingDefinition.ProducedResource.WOOD, delta)
	_tick_resource(BuildingDefinition.ProducedResource.STONE, delta)
	_tick_resource(BuildingDefinition.ProducedResource.FOOD, delta)
	_tick_resource(BuildingDefinition.ProducedResource.GOLD, delta)


func register_building(building: PlacedBuildingV2) -> void:
	if building == null:
		return

	if not building.is_production_building():
		return

	if _production_buildings.has(building):
		return

	_production_buildings.append(building)
	production_building_registered.emit(building)


func unregister_building(building: PlacedBuildingV2) -> void:
	if building == null:
		return

	_production_buildings.erase(building)
	production_building_unregistered.emit(building)


func clear() -> void:
	_production_buildings.clear()
	_reset_resource_progress()


func production_building_count() -> int:
	return _production_buildings.size()


func get_production_buildings() -> Array[PlacedBuildingV2]:
	return _production_buildings.duplicate()


func set_productivity_multiplier(
	resource: BuildingDefinition.ProducedResource,
	multiplier: float
) -> void:
	multiplier = maxf(0.0, multiplier)

	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			wood_multiplier = multiplier
		BuildingDefinition.ProducedResource.STONE:
			stone_multiplier = multiplier
		BuildingDefinition.ProducedResource.FOOD:
			food_multiplier = multiplier
		BuildingDefinition.ProducedResource.GOLD:
			gold_multiplier = multiplier
		_:
			return

	productivity_changed.emit(resource, multiplier)


func add_productivity_multiplier(
	resource: BuildingDefinition.ProducedResource,
	additive_bonus: float
) -> void:
	set_productivity_multiplier(resource, get_productivity_multiplier(resource) + additive_bonus)


func get_productivity_multiplier(resource: BuildingDefinition.ProducedResource) -> float:
	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			return wood_multiplier
		BuildingDefinition.ProducedResource.STONE:
			return stone_multiplier
		BuildingDefinition.ProducedResource.FOOD:
			return food_multiplier
		BuildingDefinition.ProducedResource.GOLD:
			return gold_multiplier
		_:
			return 0.0


func get_tick_interval(resource: BuildingDefinition.ProducedResource) -> float:
	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			return wood_tick_seconds
		BuildingDefinition.ProducedResource.STONE:
			return stone_tick_seconds
		BuildingDefinition.ProducedResource.FOOD:
			return food_tick_seconds
		BuildingDefinition.ProducedResource.GOLD:
			return gold_tick_seconds
		_:
			return 999999.0


func set_tick_interval(
	resource: BuildingDefinition.ProducedResource,
	seconds: float
) -> void:
	seconds = maxf(0.1, seconds)

	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			wood_tick_seconds = seconds
		BuildingDefinition.ProducedResource.STONE:
			stone_tick_seconds = seconds
		BuildingDefinition.ProducedResource.FOOD:
			food_tick_seconds = seconds
		BuildingDefinition.ProducedResource.GOLD:
			gold_tick_seconds = seconds
		_:
			return


func get_progress_ratio(resource: BuildingDefinition.ProducedResource) -> float:
	var interval := get_tick_interval(resource)

	if interval <= 0.0:
		return 0.0

	var progress: float = _resource_progress.get(resource, 0.0)
	return clamp(progress / interval, 0.0, 1.0)


func get_base_amount_per_tick(resource: BuildingDefinition.ProducedResource) -> int:
	var total := 0

	for building in _production_buildings:
		if not is_instance_valid(building):
			continue

		if not building.is_production_building():
			continue

		if building.definition.produces_resource != resource:
			continue

		total += building.definition.production_amount

	return total


func get_amount_per_tick(resource: BuildingDefinition.ProducedResource) -> int:
	var base_amount := get_base_amount_per_tick(resource)
	var multiplier := get_productivity_multiplier(resource)
	return int(floor(float(base_amount) * multiplier))


func get_building_count_for_resource(resource: BuildingDefinition.ProducedResource) -> int:
	var count := 0

	for building in _production_buildings:
		if not is_instance_valid(building):
			continue

		if not building.is_production_building():
			continue

		if building.definition.produces_resource == resource:
			count += 1

	return count


func _tick_resource(resource: BuildingDefinition.ProducedResource, delta: float) -> void:
	var producer_count := get_building_count_for_resource(resource)

	if producer_count <= 0:
		_resource_progress[resource] = 0.0
		return

	var interval := get_tick_interval(resource)
	var progress: float = _resource_progress.get(resource, 0.0)
	progress += delta

	if progress < interval:
		_resource_progress[resource] = progress
		return

	var completed_ticks := int(floor(progress / interval))
	progress = fmod(progress, interval)
	_resource_progress[resource] = progress

	var amount_per_tick := get_amount_per_tick(resource)
	var total_amount := amount_per_tick * completed_ticks

	if total_amount <= 0:
		return

	economy.add_resource(resource, total_amount)

	var resource_name := BuildingDefinition.resource_name(resource)
	production_tick.emit(resource, resource_name, total_amount)

	if print_debug:
		print(
			"Global production: ",
			resource_name,
			" +",
			total_amount,
			" from ",
			producer_count,
			" buildings",
			" multiplier=",
			get_productivity_multiplier(resource)
		)


func _reset_resource_progress() -> void:
	_resource_progress[BuildingDefinition.ProducedResource.WOOD] = 0.0
	_resource_progress[BuildingDefinition.ProducedResource.STONE] = 0.0
	_resource_progress[BuildingDefinition.ProducedResource.FOOD] = 0.0
	_resource_progress[BuildingDefinition.ProducedResource.GOLD] = 0.0
