class_name WorldProductionV2
extends Node

signal production_tick(resource: BuildingDefinition.ProducedResource, resource_name: String, amount: int)
signal production_building_registered(building: PlacedBuildingV2)
signal production_building_unregistered(building: PlacedBuildingV2)
signal productivity_changed(resource: BuildingDefinition.ProducedResource, multiplier: float)

@export var economy: WorldEconomyV2
@export var town_center_manager: TownCenterManagerV2
@export var resource_map: WorldResourceMapV2

@export var tick_enabled: bool = true
@export var print_debug: bool = false
@export var use_town_efficiency: bool = true
@export var use_resource_bonuses: bool = true

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

@export_group("Policy Multipliers")
@export_range(0.0, 100.0) var policy_wood_multiplier: float = 1.0
@export_range(0.0, 100.0) var policy_stone_multiplier: float = 1.0
@export_range(0.0, 100.0) var policy_food_multiplier: float = 1.0
@export_range(0.0, 100.0) var policy_gold_multiplier: float = 1.0

var _production_buildings: Array[PlacedBuildingV2] = []
var _resource_progress: Dictionary = {}


func _ready() -> void:
	if economy == null:
		economy = get_node_or_null("../WorldEconomyV2") as WorldEconomyV2

	if town_center_manager == null:
		town_center_manager = get_node_or_null("../TownCenterManagerV2") as TownCenterManagerV2

	if resource_map == null:
		resource_map = get_node_or_null("../WorldResourceMapV2") as WorldResourceMapV2

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


func set_policy_multipliers(wood: float, stone: float, food: float, gold: float) -> void:
	policy_wood_multiplier = maxf(0.0, wood)
	policy_stone_multiplier = maxf(0.0, stone)
	policy_food_multiplier = maxf(0.0, food)
	policy_gold_multiplier = maxf(0.0, gold)

	productivity_changed.emit(BuildingDefinition.ProducedResource.WOOD, get_productivity_multiplier(BuildingDefinition.ProducedResource.WOOD))
	productivity_changed.emit(BuildingDefinition.ProducedResource.STONE, get_productivity_multiplier(BuildingDefinition.ProducedResource.STONE))
	productivity_changed.emit(BuildingDefinition.ProducedResource.FOOD, get_productivity_multiplier(BuildingDefinition.ProducedResource.FOOD))
	productivity_changed.emit(BuildingDefinition.ProducedResource.GOLD, get_productivity_multiplier(BuildingDefinition.ProducedResource.GOLD))

func _get_base_productivity_multiplier(resource: BuildingDefinition.ProducedResource) -> float:
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

func _get_policy_productivity_multiplier(resource: BuildingDefinition.ProducedResource) -> float:
	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			return policy_wood_multiplier
		BuildingDefinition.ProducedResource.STONE:
			return policy_stone_multiplier
		BuildingDefinition.ProducedResource.FOOD:
			return policy_food_multiplier
		BuildingDefinition.ProducedResource.GOLD:
			return policy_gold_multiplier
		_:
			return 1.0

# Replace your existing get_productivity_multiplier() with this:
func get_productivity_multiplier(resource: BuildingDefinition.ProducedResource) -> float:
	return _get_base_productivity_multiplier(resource) * _get_policy_productivity_multiplier(resource)

# Replace add_productivity_multiplier() with this, so future tech/progression modifies the base multiplier:
func add_productivity_multiplier(resource: BuildingDefinition.ProducedResource, additive_bonus: float) -> void:
	set_productivity_multiplier(resource, _get_base_productivity_multiplier(resource) + additive_bonus)


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


func set_productivity_multiplier(resource: BuildingDefinition.ProducedResource, multiplier: float) -> void:
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

# DEPRECATED
"""func add_productivity_multiplier(resource: BuildingDefinition.ProducedResource, additive_bonus: float) -> void:
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
			return 0.0"""


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


func set_tick_interval(resource: BuildingDefinition.ProducedResource, seconds: float) -> void:
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
		if not _is_valid_producer_for_resource(building, resource):
			continue

		total += building.definition.production_amount

	return total


func get_effective_base_amount_per_tick(resource: BuildingDefinition.ProducedResource) -> float:
	var total := 0.0

	for building in _production_buildings:
		if not _is_valid_producer_for_resource(building, resource):
			continue

		total += get_building_effective_base_amount(building)

	return total


func get_amount_per_tick(resource: BuildingDefinition.ProducedResource) -> int:
	var base_amount := get_effective_base_amount_per_tick(resource)
	var multiplier := get_productivity_multiplier(resource)
	return int(floor(base_amount * multiplier))


func get_building_effective_base_amount(building: PlacedBuildingV2) -> float:
	if building == null or not is_instance_valid(building):
		return 0.0

	if not building.is_production_building():
		return 0.0

	var base := float(building.definition.production_amount)
	return base * get_building_town_efficiency(building) * get_building_resource_multiplier(building)


func get_building_amount_per_tick(building: PlacedBuildingV2) -> float:
	return get_building_effective_base_amount(building)


func get_building_town_efficiency(building: PlacedBuildingV2) -> float:
	if not use_town_efficiency:
		return 1.0

	if town_center_manager == null:
		return 1.0

	return town_center_manager.get_efficiency_for_building(building)


func get_building_resource_multiplier(building: PlacedBuildingV2) -> float:
	if not use_resource_bonuses:
		return 1.0

	if resource_map == null:
		return 1.0

	return resource_map.get_best_multiplier_for_building(building)


func get_building_count_for_resource(resource: BuildingDefinition.ProducedResource) -> int:
	var count := 0

	for building in _production_buildings:
		if not _is_valid_producer_for_resource(building, resource):
			continue

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
			" +", total_amount,
			" from ", producer_count,
			" buildings",
			" base=", get_base_amount_per_tick(resource),
			" effective_base=", get_effective_base_amount_per_tick(resource),
			" multiplier=", get_productivity_multiplier(resource)
		)


func _is_valid_producer_for_resource(building: PlacedBuildingV2, resource: BuildingDefinition.ProducedResource) -> bool:
	if building == null or not is_instance_valid(building):
		return false

	if not building.is_production_building():
		return false

	return building.definition.produces_resource == resource


func _reset_resource_progress() -> void:
	_resource_progress[BuildingDefinition.ProducedResource.WOOD] = 0.0
	_resource_progress[BuildingDefinition.ProducedResource.STONE] = 0.0
	_resource_progress[BuildingDefinition.ProducedResource.FOOD] = 0.0
	_resource_progress[BuildingDefinition.ProducedResource.GOLD] = 0.0
