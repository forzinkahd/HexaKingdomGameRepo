class_name TownPoliticsManagerV2
extends Node

signal active_policy_changed(policy: PolicyDefinitionV2)
signal politics_changed
signal policy_availability_changed

@export var town_center_manager: TownCenterManagerV2
@export var production: WorldProductionV2
@export var registry: BuildingRegistryV2
@export var available_policies: Array[PolicyDefinitionV2] = []

@export_group("Base Political Status")
@export_range(0, 100) var base_authority: int = 50
@export_range(0, 100) var base_stability: int = 50
@export_range(0, 100) var base_approval: int = 50

@export_group("Base Town Influence")
@export_range(0.0, 1.0) var base_minimum_efficiency: float = 0.35
@export_range(0, 64) var base_full_efficiency_radius: int = 4
@export_range(1, 128) var base_minimum_efficiency_radius: int = 14

@export_group("Status Consequences")
@export var enable_status_consequences: bool = true
@export_range(0, 100) var low_approval_threshold: int = 30
@export_range(0.0, 1.0) var low_approval_production_penalty: float = 0.10
@export_range(0, 100) var low_stability_threshold: int = 30
@export_range(0.0, 1.0) var low_stability_minimum_efficiency_penalty: float = 0.10
@export_range(0, 100) var high_approval_threshold: int = 70
@export_range(0.0, 1.0) var high_approval_food_bonus: float = 0.05

var active_policy: PolicyDefinitionV2

func _ready() -> void:
	if town_center_manager == null:
		town_center_manager = get_node_or_null("../TownCenterManagerV2") as TownCenterManagerV2
	if production == null:
		production = get_node_or_null("../WorldProductionV2") as WorldProductionV2
	if registry == null:
		registry = get_node_or_null("../BuildingRegistryV2") as BuildingRegistryV2
	if registry != null and not registry.registry_changed.is_connected(_on_registry_changed):
		registry.registry_changed.connect(_on_registry_changed)
	_apply_current_effects()

func set_active_policy(policy: PolicyDefinitionV2) -> void:
	if policy != null and not is_policy_available(policy):
		push_warning("Policy is not available: %s" % [policy.display_name])
		return
	if active_policy == policy:
		return
	active_policy = policy
	_apply_current_effects()
	active_policy_changed.emit(active_policy)
	politics_changed.emit()

func clear_active_policy() -> void:
	set_active_policy(null)

func get_active_policy() -> PolicyDefinitionV2:
	return active_policy

func is_policy_available(policy: PolicyDefinitionV2) -> bool:
	return get_policy_missing_requirements(policy).is_empty()

func get_policy_missing_requirements(policy: PolicyDefinitionV2) -> Array[String]:
	var missing: Array[String] = []
	if policy == null:
		missing.append("No policy")
		return missing
	for building_id in policy.required_building_ids:
		if registry == null or not registry.has_building(building_id):
			missing.append("Requires building: %s" % [str(building_id)])
	if base_authority < policy.minimum_authority:
		missing.append("Requires Authority >= %d" % [policy.minimum_authority])
	if base_stability < policy.minimum_stability:
		missing.append("Requires Stability >= %d" % [policy.minimum_stability])
	if base_approval < policy.minimum_approval:
		missing.append("Requires Approval >= %d" % [policy.minimum_approval])
	return missing

func policy_requirement_reason(policy: PolicyDefinitionV2) -> String:
	var missing := get_policy_missing_requirements(policy)
	return "Available" if missing.is_empty() else "; ".join(missing)

func get_authority() -> int:
	return clampi(base_authority + (active_policy.authority_delta if active_policy != null else 0), 0, 100)
func get_stability() -> int:
	return clampi(base_stability + (active_policy.stability_delta if active_policy != null else 0), 0, 100)
func get_approval() -> int:
	return clampi(base_approval + (active_policy.approval_delta if active_policy != null else 0), 0, 100)

func get_status_summary() -> String:
	return "Authority %d/100 | Stability %d/100 | Approval %d/100" % [get_authority(), get_stability(), get_approval()]

func get_policy_summary() -> String:
	return "No active policy" if active_policy == null else "%s: %s" % [active_policy.display_name, active_policy.production_summary()]

func get_consequence_summary() -> String:
	if not enable_status_consequences:
		return "Status consequences disabled"
	var parts: Array[String] = []
	if get_approval() < low_approval_threshold:
		parts.append("Low approval: all production -%d%%" % [int(round(low_approval_production_penalty * 100.0))])
	if get_stability() < low_stability_threshold:
		parts.append("Low stability: distant production penalty worsens")
	if get_approval() >= high_approval_threshold:
		parts.append("High approval: food production +%d%%" % [int(round(high_approval_food_bonus * 100.0))])
	return "No active status consequence" if parts.is_empty() else "; ".join(parts)

func _on_registry_changed() -> void:
	if active_policy != null and not is_policy_available(active_policy):
		active_policy = null
		_apply_current_effects()
		active_policy_changed.emit(active_policy)
	policy_availability_changed.emit()
	politics_changed.emit()

func _apply_current_effects() -> void:
	_apply_status_to_town()
	_apply_production_effects()
	_apply_town_influence_effects()

func _apply_status_to_town() -> void:
	if town_center_manager == null:
		return
	town_center_manager.authority = get_authority()
	town_center_manager.stability = get_stability()
	town_center_manager.approval = get_approval()

func _apply_production_effects() -> void:
	if production == null:
		return
	var wood := active_policy.wood_multiplier if active_policy != null else 1.0
	var stone := active_policy.stone_multiplier if active_policy != null else 1.0
	var food := active_policy.food_multiplier if active_policy != null else 1.0
	var gold := active_policy.gold_multiplier if active_policy != null else 1.0
	if enable_status_consequences:
		if get_approval() < low_approval_threshold:
			var penalty := maxf(0.0, 1.0 - low_approval_production_penalty)
			wood *= penalty; stone *= penalty; food *= penalty; gold *= penalty
		if get_approval() >= high_approval_threshold:
			food *= 1.0 + high_approval_food_bonus
	if production.has_method("set_policy_multipliers"):
		production.set_policy_multipliers(wood, stone, food, gold)
	else:
		push_warning("WorldProductionV2 needs set_policy_multipliers(wood, stone, food, gold).")

func _apply_town_influence_effects() -> void:
	if town_center_manager == null:
		return
	var min_eff := base_minimum_efficiency + (active_policy.minimum_efficiency_bonus if active_policy != null else 0.0)
	var full_r := base_full_efficiency_radius + (active_policy.full_efficiency_radius_delta if active_policy != null else 0)
	var min_r := base_minimum_efficiency_radius + (active_policy.minimum_efficiency_radius_delta if active_policy != null else 0)
	if enable_status_consequences and get_stability() < low_stability_threshold:
		min_eff -= low_stability_minimum_efficiency_penalty
	town_center_manager.minimum_efficiency = clamp(min_eff, 0.0, 1.0)
	town_center_manager.full_efficiency_radius = max(0, full_r)
	town_center_manager.minimum_efficiency_radius = max(town_center_manager.full_efficiency_radius + 1, min_r)
