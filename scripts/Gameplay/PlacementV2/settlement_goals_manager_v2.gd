class_name SettlementGoalsManagerV2
extends Node

signal goals_changed
signal goal_completed(goal: SettlementGoalDefinitionV2)
signal goal_reward_granted(goal: SettlementGoalDefinitionV2)

@export var economy: WorldEconomyV2
@export var registry: BuildingRegistryV2
@export var politics: TownPoliticsManagerV2
@export var town_center_manager: TownCenterManagerV2
@export var goals: Array[SettlementGoalDefinitionV2] = []

@export_group("Behavior")
@export var evaluate_on_ready: bool = true
@export var print_debug: bool = false

var _completed_goal_ids: Dictionary = {}
var _rewarded_goal_ids: Dictionary = {}
var _loading_save_data: bool = false


func _ready() -> void:
	if economy == null:
		economy = get_node_or_null("../WorldEconomyV2") as WorldEconomyV2
	if registry == null:
		registry = get_node_or_null("../BuildingRegistryV2") as BuildingRegistryV2
	if politics == null:
		politics = get_node_or_null("../TownPoliticsManagerV2") as TownPoliticsManagerV2
	if town_center_manager == null:
		town_center_manager = get_node_or_null("../TownCenterManagerV2") as TownCenterManagerV2

	_connect_sources()
	if evaluate_on_ready:
		call_deferred("evaluate_goals")


func evaluate_goals() -> void:
	var completed_something := false
	for goal in goals:
		if goal == null or is_goal_completed(goal) or not are_prerequisites_met(goal):
			continue
		if _is_goal_condition_met(goal):
			_mark_goal_completed(goal)
			completed_something = true
	goals_changed.emit()


func reset_goals() -> void:
	_completed_goal_ids.clear()
	_rewarded_goal_ids.clear()
	goals_changed.emit()


func is_goal_completed(goal: SettlementGoalDefinitionV2) -> bool:
	return goal != null and _completed_goal_ids.has(goal.id)


func is_goal_visible(goal: SettlementGoalDefinitionV2) -> bool:
	if goal == null:
		return false
	return (not goal.hidden_until_prerequisites_met) or are_prerequisites_met(goal) or is_goal_completed(goal)


func are_prerequisites_met(goal: SettlementGoalDefinitionV2) -> bool:
	if goal == null:
		return false
	for required_id in goal.prerequisite_goal_ids:
		if not _completed_goal_ids.has(required_id):
			return false
	return true


func get_visible_goals() -> Array[SettlementGoalDefinitionV2]:
	var result: Array[SettlementGoalDefinitionV2] = []
	for goal in goals:
		if goal != null and is_goal_visible(goal):
			result.append(goal)
	return result


func get_visible_completed_count() -> int:
	var count := 0
	for goal in get_visible_goals():
		if is_goal_completed(goal):
			count += 1
	return count


func get_goal_progress_text(goal: SettlementGoalDefinitionV2) -> String:
	if goal == null:
		return "No goal"
	if is_goal_completed(goal):
		return "Complete"
	if not are_prerequisites_met(goal):
		return "Locked"
	match goal.goal_type:
		SettlementGoalDefinitionV2.GoalType.RESOURCE_AMOUNT:
			return "%d / %d %s" % [_get_resource_amount(goal.target_resource), goal.target_amount, BuildingDefinition.resource_name(goal.target_resource)]
		SettlementGoalDefinitionV2.GoalType.BUILDING_COUNT:
			return "%d / %d built" % [_get_building_count(goal.target_building_id), goal.target_building_count]
		SettlementGoalDefinitionV2.GoalType.TOWN_CENTER_PLACED:
			return "Placed" if _has_town_center() else "Not placed"
		SettlementGoalDefinitionV2.GoalType.ACTIVE_POLICY:
			var active := _get_active_policy_id()
			return "No active policy" if active == &"" else "Active: %s" % [str(active)]
		SettlementGoalDefinitionV2.GoalType.APPROVAL_AT_LEAST:
			return "%d / %d Approval" % [_get_approval(), goal.target_status_value]
		SettlementGoalDefinitionV2.GoalType.STABILITY_AT_LEAST:
			return "%d / %d Stability" % [_get_stability(), goal.target_status_value]
		SettlementGoalDefinitionV2.GoalType.AUTHORITY_AT_LEAST:
			return "%d / %d Authority" % [_get_authority(), goal.target_status_value]
		_:
			return "Unknown"


func get_goal_completion_ratio(goal: SettlementGoalDefinitionV2) -> float:
	if goal == null:
		return 0.0
	if is_goal_completed(goal):
		return 1.0
	match goal.goal_type:
		SettlementGoalDefinitionV2.GoalType.RESOURCE_AMOUNT:
			return 1.0 if goal.target_amount <= 0 else clamp(float(_get_resource_amount(goal.target_resource)) / float(goal.target_amount), 0.0, 1.0)
		SettlementGoalDefinitionV2.GoalType.BUILDING_COUNT:
			return 1.0 if goal.target_building_count <= 0 else clamp(float(_get_building_count(goal.target_building_id)) / float(goal.target_building_count), 0.0, 1.0)
		SettlementGoalDefinitionV2.GoalType.TOWN_CENTER_PLACED:
			return 1.0 if _has_town_center() else 0.0
		SettlementGoalDefinitionV2.GoalType.ACTIVE_POLICY:
			return 1.0 if _get_active_policy_id() == goal.target_policy_id else 0.0
		SettlementGoalDefinitionV2.GoalType.APPROVAL_AT_LEAST:
			return 1.0 if goal.target_status_value <= 0 else clamp(float(_get_approval()) / float(goal.target_status_value), 0.0, 1.0)
		SettlementGoalDefinitionV2.GoalType.STABILITY_AT_LEAST:
			return 1.0 if goal.target_status_value <= 0 else clamp(float(_get_stability()) / float(goal.target_status_value), 0.0, 1.0)
		SettlementGoalDefinitionV2.GoalType.AUTHORITY_AT_LEAST:
			return 1.0 if goal.target_status_value <= 0 else clamp(float(_get_authority()) / float(goal.target_status_value), 0.0, 1.0)
		_:
			return 0.0


func _connect_sources() -> void:
	if economy != null and economy.has_signal("resources_changed") and not economy.resources_changed.is_connected(_on_source_changed):
		economy.resources_changed.connect(_on_source_changed)
	if registry != null and not registry.registry_changed.is_connected(_on_source_changed):
		registry.registry_changed.connect(_on_source_changed)
	if politics != null:
		if not politics.politics_changed.is_connected(_on_source_changed): politics.politics_changed.connect(_on_source_changed)
		if not politics.active_policy_changed.is_connected(_on_source_changed): politics.active_policy_changed.connect(_on_source_changed)
	if town_center_manager != null and not town_center_manager.town_center_changed.is_connected(_on_source_changed):
		town_center_manager.town_center_changed.connect(_on_source_changed)


func _on_source_changed(_arg = null) -> void:
	evaluate_goals()


func _is_goal_condition_met(goal: SettlementGoalDefinitionV2) -> bool:
	match goal.goal_type:
		SettlementGoalDefinitionV2.GoalType.RESOURCE_AMOUNT:
			return _get_resource_amount(goal.target_resource) >= goal.target_amount
		SettlementGoalDefinitionV2.GoalType.BUILDING_COUNT:
			return _get_building_count(goal.target_building_id) >= goal.target_building_count
		SettlementGoalDefinitionV2.GoalType.TOWN_CENTER_PLACED:
			return _has_town_center()
		SettlementGoalDefinitionV2.GoalType.ACTIVE_POLICY:
			return _get_active_policy_id() == goal.target_policy_id
		SettlementGoalDefinitionV2.GoalType.APPROVAL_AT_LEAST:
			return _get_approval() >= goal.target_status_value
		SettlementGoalDefinitionV2.GoalType.STABILITY_AT_LEAST:
			return _get_stability() >= goal.target_status_value
		SettlementGoalDefinitionV2.GoalType.AUTHORITY_AT_LEAST:
			return _get_authority() >= goal.target_status_value
		_:
			return false


func _mark_goal_completed(goal: SettlementGoalDefinitionV2) -> void:
	if goal == null:
		return
	
	if _loading_save_data:
		return
	
	if _completed_goal_ids.has(goal.id):
		return
	
	_completed_goal_ids[goal.id] = true
	
	if goal.auto_grant_reward and not _rewarded_goal_ids.has(goal.id):
		_grant_reward(goal)
	
	goal_completed.emit(goal)
	goals_changed.emit()


func _grant_reward(goal: SettlementGoalDefinitionV2) -> void:
	if goal == null:
		return
	
	if _loading_save_data:
		return
	
	if _rewarded_goal_ids.has(goal.id):
		return
	
	_rewarded_goal_ids[goal.id] = true
	
	if economy == null:
		return
	_rewarded_goal_ids[goal.id] = true
	_add_resource(BuildingDefinition.ProducedResource.WOOD, goal.reward_wood)
	_add_resource(BuildingDefinition.ProducedResource.STONE, goal.reward_stone)
	_add_resource(BuildingDefinition.ProducedResource.FOOD, goal.reward_food)
	_add_resource(BuildingDefinition.ProducedResource.GOLD, goal.reward_gold)
	goal_reward_granted.emit(goal)
	goals_changed.emit()


func _add_resource(resource: BuildingDefinition.ProducedResource, amount: int) -> void:
	if amount > 0 and economy != null and economy.has_method("add_resource"):
		economy.add_resource(resource, amount)


func _get_resource_amount(resource: BuildingDefinition.ProducedResource) -> int:
	if economy == null:
		return 0
	if economy.has_method("get_resource_amount"):
		return int(economy.get_resource_amount(resource))
	if economy.has_method("get_amount"):
		return int(economy.get_amount(resource))
	var value = economy.get(_resource_property_name(resource))
	return 0 if value == null else int(value)


func _resource_property_name(resource: BuildingDefinition.ProducedResource) -> StringName:
	match resource:
		BuildingDefinition.ProducedResource.WOOD: return &"wood"
		BuildingDefinition.ProducedResource.STONE: return &"stone"
		BuildingDefinition.ProducedResource.FOOD: return &"food"
		BuildingDefinition.ProducedResource.GOLD: return &"gold"
		_: return &""


func _get_building_count(building_id: StringName) -> int:
	return 0 if registry == null or building_id == &"" else registry.get_count(building_id)


func _has_town_center() -> bool:
	if town_center_manager != null:
		return town_center_manager.has_town_center()
	return registry != null and registry.has_building(&"town_center")


func get_save_data() -> Dictionary:
	var completed_ids: Array[String] = []
	for goal_id in _completed_goal_ids.keys():
		completed_ids.append(str(goal_id))
	var rewarded_ids: Array[String] = []
	for goal_id in _rewarded_goal_ids.keys():
		rewarded_ids.append(str(goal_id))
	return {
		"completed_goal_ids": completed_ids,
		"rewarded_goal_ids": rewarded_ids
	}


func prepare_for_load() -> void:
	_loading_save_data = true


func load_save_data(data: Dictionary) -> void:
	_loading_save_data = true

	_completed_goal_ids.clear()
	_rewarded_goal_ids.clear()

	for raw_id in data.get("completed_goal_ids", []):
		_completed_goal_ids[StringName(str(raw_id))] = true

	for raw_id in data.get("rewarded_goal_ids", []):
		_rewarded_goal_ids[StringName(str(raw_id))] = true

	goals_changed.emit()

	call_deferred("_finish_loading_save_data")


func _finish_loading_save_data() -> void:
	_loading_save_data = false
	goals_changed.emit()


func _get_active_policy_id() -> StringName:
	if politics == null:
		return &""
	var policy := politics.get_active_policy()
	return &"" if policy == null else policy.id


func _get_authority() -> int:
	if politics != null: return politics.get_authority()
	return town_center_manager.authority if town_center_manager != null else 0

func _get_stability() -> int:
	if politics != null: return politics.get_stability()
	return town_center_manager.stability if town_center_manager != null else 0

func _get_approval() -> int:
	if politics != null: return politics.get_approval()
	return town_center_manager.approval if town_center_manager != null else 0
