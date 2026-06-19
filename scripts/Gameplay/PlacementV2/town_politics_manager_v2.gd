class_name TownPoliticsManagerV2
extends Node

signal active_policy_changed(policy: PolicyDefinitionV2)
signal politics_changed

@export var town_center_manager: TownCenterManagerV2
@export var production: WorldProductionV2
@export var available_policies: Array[PolicyDefinitionV2] = []

@export_group("Base Political Status")
@export_range(0, 100) var base_authority: int = 50
@export_range(0, 100) var base_stability: int = 50
@export_range(0, 100) var base_approval: int = 50

@export_group("Base Town Influence")
@export_range(0.0, 1.0) var base_minimum_efficiency: float = 0.35
@export_range(0, 64) var base_full_efficiency_radius: int = 4
@export_range(1, 128) var base_minimum_efficiency_radius: int = 14

@export var apply_base_values_on_ready: bool = true
@export var clear_policy_on_missing_town_center: bool = false

var active_policy: PolicyDefinitionV2


func _ready() -> void:
	if town_center_manager == null:
		town_center_manager = get_node_or_null("../TownCenterManagerV2") as TownCenterManagerV2

	if production == null:
		production = get_node_or_null("../WorldProductionV2") as WorldProductionV2

	if town_center_manager != null and not town_center_manager.town_center_changed.is_connected(_on_town_center_changed):
		town_center_manager.town_center_changed.connect(_on_town_center_changed)

	if apply_base_values_on_ready:
		_apply_current_policy_effects()


func set_active_policy(policy: PolicyDefinitionV2) -> void:
	if active_policy == policy:
		return

	active_policy = policy
	_apply_current_policy_effects()
	active_policy_changed.emit(active_policy)
	politics_changed.emit()


func clear_active_policy() -> void:
	set_active_policy(null)


func get_active_policy() -> PolicyDefinitionV2:
	return active_policy


func has_active_policy() -> bool:
	return active_policy != null


func get_policy_by_id(policy_id: StringName) -> PolicyDefinitionV2:
	for policy in available_policies:
		if policy != null and policy.id == policy_id:
			return policy

	return null


func get_status_summary() -> String:
	return "Authority %d/100 | Stability %d/100 | Approval %d/100" % [
		get_authority(), get_stability(), get_approval()
	]


func get_policy_summary() -> String:
	if active_policy == null:
		return "No active policy"

	return "%s: %s" % [active_policy.display_name, active_policy.production_summary()]


func get_authority() -> int:
	var delta := 0
	if active_policy != null:
		delta = active_policy.authority_delta

	return clampi(base_authority + delta, 0, 100)


func get_stability() -> int:
	var delta := 0
	if active_policy != null:
		delta = active_policy.stability_delta

	return clampi(base_stability + delta, 0, 100)


func get_approval() -> int:
	var delta := 0
	if active_policy != null:
		delta = active_policy.approval_delta

	return clampi(base_approval + delta, 0, 100)


func _on_town_center_changed(town_center: PlacedBuildingV2) -> void:
	if town_center == null and clear_policy_on_missing_town_center:
		clear_active_policy()
	else:
		_apply_current_policy_effects()


func _apply_current_policy_effects() -> void:
	_apply_status_effects()
	_apply_production_effects()
	_apply_town_influence_effects()


func _apply_status_effects() -> void:
	if town_center_manager == null:
		return

	town_center_manager.authority = get_authority()
	town_center_manager.stability = get_stability()
	town_center_manager.approval = get_approval()


func _apply_production_effects() -> void:
	if production == null:
		return

	if active_policy == null:
		production.set_policy_multipliers(1.0, 1.0, 1.0, 1.0)
		return

	production.set_policy_multipliers(
		active_policy.wood_multiplier,
		active_policy.stone_multiplier,
		active_policy.food_multiplier,
		active_policy.gold_multiplier
	)


func _apply_town_influence_effects() -> void:
	if town_center_manager == null:
		return

	var min_efficiency := base_minimum_efficiency
	var full_radius := base_full_efficiency_radius
	var minimum_radius := base_minimum_efficiency_radius

	if active_policy != null:
		min_efficiency += active_policy.minimum_efficiency_bonus
		full_radius += active_policy.full_efficiency_radius_delta
		minimum_radius += active_policy.minimum_efficiency_radius_delta

	town_center_manager.minimum_efficiency = clamp(min_efficiency, 0.0, 1.0)
	town_center_manager.full_efficiency_radius = max(0, full_radius)
	town_center_manager.minimum_efficiency_radius = max(
		town_center_manager.full_efficiency_radius + 1,
		minimum_radius
	)
