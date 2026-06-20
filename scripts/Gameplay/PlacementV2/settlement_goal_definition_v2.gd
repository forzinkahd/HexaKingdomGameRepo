class_name SettlementGoalDefinitionV2
extends Resource

enum GoalType {
	RESOURCE_AMOUNT,
	BUILDING_COUNT,
	TOWN_CENTER_PLACED,
	ACTIVE_POLICY,
	APPROVAL_AT_LEAST,
	STABILITY_AT_LEAST,
	AUTHORITY_AT_LEAST
}

@export var id: StringName = &"goal"
@export var display_name: String = "Settlement Goal"
@export_multiline var description: String = ""
@export var goal_type: GoalType = GoalType.RESOURCE_AMOUNT

@export_group("Resource Target")
@export var target_resource: BuildingDefinition.ProducedResource = BuildingDefinition.ProducedResource.WOOD
@export_range(0, 999999) var target_amount: int = 100

@export_group("Building Target")
@export var target_building_id: StringName = &""
@export_range(1, 9999) var target_building_count: int = 1

@export_group("Politics Target")
@export var target_policy_id: StringName = &""
@export_range(0, 100) var target_status_value: int = 50

@export_group("Progression")
@export var prerequisite_goal_ids: Array[StringName] = []
@export var hidden_until_prerequisites_met: bool = false

@export_group("Reward")
@export var auto_grant_reward: bool = false
@export_range(0, 999999) var reward_wood: int = 0
@export_range(0, 999999) var reward_stone: int = 0
@export_range(0, 999999) var reward_food: int = 0
@export_range(0, 999999) var reward_gold: int = 0


func target_summary() -> String:
	match goal_type:
		GoalType.RESOURCE_AMOUNT:
			return "Collect %d %s" % [target_amount, BuildingDefinition.resource_name(target_resource)]
		GoalType.BUILDING_COUNT:
			return "Build %d x %s" % [target_building_count, str(target_building_id)]
		GoalType.TOWN_CENTER_PLACED:
			return "Build a Town Center"
		GoalType.ACTIVE_POLICY:
			return "Activate policy: %s" % [str(target_policy_id)]
		GoalType.APPROVAL_AT_LEAST:
			return "Reach Approval >= %d" % [target_status_value]
		GoalType.STABILITY_AT_LEAST:
			return "Reach Stability >= %d" % [target_status_value]
		GoalType.AUTHORITY_AT_LEAST:
			return "Reach Authority >= %d" % [target_status_value]
		_:
			return "Unknown target"


func reward_summary() -> String:
	var parts: Array[String] = []
	if reward_wood > 0: parts.append("Wood +%d" % [reward_wood])
	if reward_stone > 0: parts.append("Stone +%d" % [reward_stone])
	if reward_food > 0: parts.append("Food +%d" % [reward_food])
	if reward_gold > 0: parts.append("Gold +%d" % [reward_gold])
	return "No reward" if parts.is_empty() else ", ".join(parts)


func has_reward() -> bool:
	return reward_wood > 0 or reward_stone > 0 or reward_food > 0 or reward_gold > 0
