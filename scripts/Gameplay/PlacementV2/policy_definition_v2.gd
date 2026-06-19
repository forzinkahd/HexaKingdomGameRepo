class_name PolicyDefinitionV2
extends Resource

enum PolicyCategory { ECONOMY, LABOR, EXPANSION, ENVIRONMENT, POLITICS }

@export var id: StringName = &"policy"
@export var display_name: String = "Policy"
@export_multiline var description: String = ""
@export var category: PolicyCategory = PolicyCategory.POLITICS

@export_group("Requirements")
@export var required_building_ids: Array[StringName] = []
@export_range(0, 100) var minimum_authority: int = 0
@export_range(0, 100) var minimum_stability: int = 0
@export_range(0, 100) var minimum_approval: int = 0

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

func requirement_summary() -> String:
	var parts: Array[String] = []
	if not required_building_ids.is_empty():
		var ids: Array[String] = []
		for id_value in required_building_ids:
			ids.append(str(id_value))
		parts.append("Buildings: %s" % [", ".join(ids)])
	if minimum_authority > 0:
		parts.append("Authority >= %d" % [minimum_authority])
	if minimum_stability > 0:
		parts.append("Stability >= %d" % [minimum_stability])
	if minimum_approval > 0:
		parts.append("Approval >= %d" % [minimum_approval])
	return "No requirements" if parts.is_empty() else "; ".join(parts)

func status_summary() -> String:
	var parts: Array[String] = []
	if authority_delta != 0:
		parts.append("Authority %+d" % [authority_delta])
	if stability_delta != 0:
		parts.append("Stability %+d" % [stability_delta])
	if approval_delta != 0:
		parts.append("Approval %+d" % [approval_delta])
	return "No status change" if parts.is_empty() else ", ".join(parts)

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
	return "No production change" if parts.is_empty() else ", ".join(parts)

func influence_summary() -> String:
	var parts: Array[String] = []
	if not is_equal_approx(minimum_efficiency_bonus, 0.0):
		parts.append("Minimum efficiency %+d%%" % [int(round(minimum_efficiency_bonus * 100.0))])
	if full_efficiency_radius_delta != 0:
		parts.append("Full radius %+d" % [full_efficiency_radius_delta])
	if minimum_efficiency_radius_delta != 0:
		parts.append("Falloff radius %+d" % [minimum_efficiency_radius_delta])
	return "No influence change" if parts.is_empty() else ", ".join(parts)

func consequence_warning() -> String:
	var warnings: Array[String] = []
	if approval_delta <= -10:
		warnings.append("Approval drops noticeably.")
	if stability_delta <= -10:
		warnings.append("Stability drops noticeably.")
	if wood_multiplier < 1.0:
		warnings.append("Wood production decreases.")
	if food_multiplier < 1.0:
		warnings.append("Food production decreases.")
	if stone_multiplier > 1.0:
		warnings.append("Stone production increases.")
	if minimum_efficiency_bonus > 0.0:
		warnings.append("Distant production penalty is softened.")
	return "No major warning" if warnings.is_empty() else " ".join(warnings)

func full_summary() -> String:
	return "%s\n%s\n%s\n%s" % [requirement_summary(), status_summary(), production_summary(), influence_summary()]

static func category_name(value: int) -> String:
	match value:
		PolicyCategory.ECONOMY: return "Economy"
		PolicyCategory.LABOR: return "Labor"
		PolicyCategory.EXPANSION: return "Expansion"
		PolicyCategory.ENVIRONMENT: return "Environment"
		PolicyCategory.POLITICS: return "Politics"
		_: return "Unknown"
