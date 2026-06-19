class_name PolicyMenuButtonV2
extends Button

signal policy_pressed(policy: PolicyDefinitionV2)

@export var selected_prefix: String = "▶ "
@export var show_description: bool = true
@export var show_effects: bool = true

var policy: PolicyDefinitionV2
var selected: bool = false


func setup(source_policy: PolicyDefinitionV2) -> void:
	policy = source_policy
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	_update_text()


func set_selected(value: bool) -> void:
	selected = value
	button_pressed = selected
	_update_text()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	_update_text()


func _on_pressed() -> void:
	if policy == null:
		return

	policy_pressed.emit(policy)


func _update_text() -> void:
	if policy == null:
		text = "Missing Policy"
		disabled = true
		return

	disabled = false

	var lines: Array[String] = []
	var title := policy.display_name

	if selected:
		title = selected_prefix + title

	lines.append(title)
	lines.append(PolicyDefinitionV2.category_name(policy.category))

	if show_description and policy.description != "":
		lines.append(policy.description)

	if show_effects:
		lines.append(policy.status_summary())
		lines.append(policy.production_summary())

	var influence := policy.influence_summary()
	if influence != "No influence change":
		lines.append(influence)

	text = "\n".join(lines)
