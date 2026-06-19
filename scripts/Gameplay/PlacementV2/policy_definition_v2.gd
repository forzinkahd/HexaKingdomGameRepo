class_name PolicyDefinitionV2
extends Resource

enum PolicyCategory {
	ECONOMY,
	LABOR,
	EXPANSION,
	ENVIRONMENT,
	POLITICS
}

@export var id: StringName = &"policy"
@export var display_name: String = "Policy"
@export_multiline var description: String = ""
@export var category: PolicyCategory = PolicyCategory.POLITICS

@export_group("Status Effects")
@export_range(-100, 100) var authority_delta: int = 0
@export_range(-100, 100) var stability_delta: int = 0
@export_range(-100, 100) var approval_delta: int = 0

@export_group("Production Multipliers")
@export_range(0.0, 5.0) var wood_multiplier: float = 1.0
@export_range(0.0, 5.0) var stone_multiplier: float = 1.0
@export_range(0.0, 5.0) var food_multiplier: float = 1.0
@export_range(0.0, 5.0) var gold_multiplier: float = 1.0

@export_group("Town Influence")
@export_range(-1.0, 1.0) var minimum_efficiency_bonus: float = 0.0
@export_range(-16, 16) var full_efficiency_radius_delta: int = 0
@export_range(-16, 16) var minimum_efficiency_radius_delta: int = 0


func status_summary() -> String:
	var parts: Array[String] = []

	if authority_delta != 0:
		parts.append("Authority %+d" % [authority_delta])
	if stability_delta != 0:
		parts.append("Stability %+d" % [stability_delta])
	if approval_delta != 0:
		parts.append("Approval %+d" % [approval_delta])

	if parts.is_empty():
		return "No status change"

	return ", ".join(parts)


func production_summary() -> String:
	var parts: Array[String] = []

	if not is_equal_approx(wood_multiplier, 1.0):
		parts.append("Wood x%.2f" % [wood_multiplier])
	if not is_equal_approx(stone_multiplier, 1.0):
		parts.append("Stone x%.2f" % [stone_multiplier])
	if not is_equal_approx(food_multiplier, 1.0):
		parts.append("Food x%.2f" % [food_multiplier])
	if not is_equal_approx(gold_multiplier, 1.0):
		parts.append("Gold x%.2f" % [gold_multiplier])

	if parts.is_empty():
		return "No production change"

	return ", ".join(parts)


func influence_summary() -> String:
	var parts: Array[String] = []

	if not is_equal_approx(minimum_efficiency_bonus, 0.0):
		parts.append("Minimum efficiency %+d%%" % [int(round(minimum_efficiency_bonus * 100.0))])
	if full_efficiency_radius_delta != 0:
		parts.append("Full radius %+d" % [full_efficiency_radius_delta])
	if minimum_efficiency_radius_delta != 0:
		parts.append("Falloff radius %+d" % [minimum_efficiency_radius_delta])

	if parts.is_empty():
		return "No influence change"

	return ", ".join(parts)


func full_summary() -> String:
	return "%s\n%s\n%s" % [status_summary(), production_summary(), influence_summary()]


static func category_name(value: int) -> String:
	match value:
		PolicyCategory.ECONOMY:
			return "Economy"
		PolicyCategory.LABOR:
			return "Labor"
		PolicyCategory.EXPANSION:
			return "Expansion"
		PolicyCategory.ENVIRONMENT:
			return "Environment"
		PolicyCategory.POLITICS:
			return "Politics"
		_:
			return "Unknown"
