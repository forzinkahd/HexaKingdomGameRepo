class_name BuildMenuButtonV2
extends Button

signal building_pressed(definition: BuildingDefinition)

@export var show_category: bool = true
@export var show_cost: bool = true
@export var show_production: bool = true
@export var show_unaffordable_reason: bool = true
@export var show_locked_reason: bool = true
@export var show_unique_reason: bool = true

@export var selected_prefix: String = "▶ "
@export var affordable_prefix: String = ""
@export var unaffordable_prefix: String = "✕ "
@export var locked_prefix: String = "🔒 "
@export var unique_blocked_prefix: String = "★ "

@export_group("Visual State")
@export var selected_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var normal_modulate: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var unaffordable_modulate: Color = Color(0.55, 0.55, 0.55, 0.75)
@export var locked_modulate: Color = Color(0.42, 0.42, 0.42, 0.65)
@export var unique_blocked_modulate: Color = Color(0.55, 0.48, 0.35, 0.75)

var definition: BuildingDefinition
var economy: WorldEconomyV2
var registry: BuildingRegistryV2

var selected: bool = false
var affordable: bool = true
var unlocked: bool = true
var unique_available: bool = true


func setup(
	source_definition: BuildingDefinition,
	source_economy: WorldEconomyV2 = null,
	source_registry: BuildingRegistryV2 = null
) -> void:
	definition = source_definition
	economy = source_economy
	registry = source_registry

	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true

	_refresh_state()


func set_economy(source_economy: WorldEconomyV2) -> void:
	economy = source_economy
	_refresh_state()


func set_registry(source_registry: BuildingRegistryV2) -> void:
	registry = source_registry
	_refresh_state()


func set_selected(value: bool) -> void:
	selected = value
	button_pressed = selected
	_refresh_state()


func refresh_availability() -> void:
	_refresh_state()


func refresh_affordability() -> void:
	_refresh_state()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	_refresh_state()


func _on_pressed() -> void:
	if definition == null:
		return

	if not unlocked or not affordable or not unique_available:
		button_pressed = selected
		return

	building_pressed.emit(definition)


func _refresh_state() -> void:
	_update_availability()
	_update_text()
	_update_visual_state()


func _update_availability() -> void:
	if definition == null:
		unlocked = false
		affordable = false
		unique_available = false
		disabled = true
		return

	if registry == null:
		unlocked = true
		unique_available = true
	else:
		unlocked = registry.is_unlocked(definition)
		unique_available = not registry.is_unique_limit_reached(definition)

	if economy == null:
		affordable = true
	else:
		affordable = economy.can_afford(definition)

	disabled = not unlocked or not affordable or not unique_available


func _update_text() -> void:
	if definition == null:
		text = "Missing Building"
		return

	var lines: Array[String] = []
	var title := definition.display_name

	if selected:
		title = selected_prefix + title
	elif not unlocked:
		title = locked_prefix + title
	elif not unique_available:
		title = unique_blocked_prefix + title
	elif not affordable:
		title = unaffordable_prefix + title
	else:
		title = affordable_prefix + title

	lines.append(title)

	if show_category:
		lines.append(BuildingDefinition.category_name(definition.category))

	if show_cost:
		lines.append("Cost: %s" % [definition.cost_summary()])

	if show_production:
		var production := definition.production_summary()
		if production != "None":
			lines.append("Produces: %s" % [production])

	if definition.footprint_radius > 0:
		lines.append("Footprint: r%d" % [definition.footprint_radius])

	if not unlocked and registry != null and show_locked_reason:
		lines.append(registry.unlock_reason(definition))
	elif not unique_available and registry != null and show_unique_reason:
		lines.append(registry.unique_reason(definition))
	elif not affordable and economy != null and show_unaffordable_reason:
		lines.append(economy.missing_cost_reason(definition))

	text = "\n".join(lines)


func _update_visual_state() -> void:
	if selected:
		modulate = selected_modulate
	elif not unlocked:
		modulate = locked_modulate
	elif not unique_available:
		modulate = unique_blocked_modulate
	elif not affordable:
		modulate = unaffordable_modulate
	else:
		modulate = normal_modulate
