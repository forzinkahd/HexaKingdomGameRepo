class_name PolicyMenuButtonV2
extends Button

signal policy_pressed(policy: PolicyDefinitionV2)

@export var selected_prefix: String = "▶ "
@export var locked_prefix: String = "🔒 "
@export var show_description: bool = true
@export var show_requirements: bool = true
@export var show_effects: bool = true
@export var show_warning: bool = true

var policy: PolicyDefinitionV2
var politics: TownPoliticsManagerV2
var selected: bool = false
var available: bool = true

func setup(source_policy: PolicyDefinitionV2, source_politics: TownPoliticsManagerV2 = null) -> void:
	policy = source_policy
	politics = source_politics
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	_refresh()

func set_politics(source_politics: TownPoliticsManagerV2) -> void:
	politics = source_politics
	_refresh()

func set_selected(value: bool) -> void:
	selected = value
	button_pressed = selected
	_refresh()

func refresh_availability() -> void:
	_refresh()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_refresh()

func _on_pressed() -> void:
	if policy == null:
		return
	if not available:
		button_pressed = selected
		return
	policy_pressed.emit(policy)

func _refresh() -> void:
	if policy == null:
		text = "Missing Policy"
		disabled = true
		return
	available = true if politics == null else politics.is_policy_available(policy)
	disabled = not available
	var lines: Array[String] = []
	var title := policy.display_name
	if selected:
		title = selected_prefix + title
	elif not available:
		title = locked_prefix + title
	lines.append(title)
	lines.append(PolicyDefinitionV2.category_name(policy.category))
	if show_description and policy.description != "":
		lines.append(policy.description)
	if show_requirements:
		lines.append(politics.policy_requirement_reason(policy) if politics != null and not available else policy.requirement_summary())
	if show_effects:
		lines.append(policy.status_summary())
		lines.append(policy.production_summary())
		var influence := policy.influence_summary()
		if influence != "No influence change":
			lines.append(influence)
	if show_warning:
		var warning := policy.consequence_warning()
		if warning != "No major warning":
			lines.append("Warning: %s" % [warning])
	text = "\n".join(lines)
	modulate = Color(0.5,0.5,0.5,0.7) if not available else Color(1,1,1,1)
