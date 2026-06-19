class_name PolicyMenuV2
extends Control

@export var politics: TownPoliticsManagerV2
@export var button_container: Container
@export var button_scene: PackedScene

@export_group("Display")
@export var status_label: Label
@export var active_policy_label: Label
@export var fallback_button_min_size: Vector2 = Vector2(260.0, 120.0)
@export var show_clear_policy_button: bool = true

var _buttons_by_policy: Dictionary = {}
var _clear_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	if politics == null:
		politics = get_node_or_null("../TownPoliticsManagerV2") as TownPoliticsManagerV2

	#if button_container == null:
		#button_container = self as Container

	if button_container != null:
		button_container.mouse_filter = Control.MOUSE_FILTER_PASS

	if politics != null:
		if not politics.active_policy_changed.is_connected(_on_active_policy_changed):
			politics.active_policy_changed.connect(_on_active_policy_changed)

		if not politics.politics_changed.is_connected(_refresh_status):
			politics.politics_changed.connect(_refresh_status)

	_rebuild_buttons()
	_refresh_status()
	_update_selected_buttons()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _rebuild_buttons() -> void:
	if button_container == null:
		push_warning("PolicyMenuV2: missing button_container.")
		return

	for child in button_container.get_children():
		child.queue_free()

	_buttons_by_policy.clear()

	if show_clear_policy_button:
		_clear_button = Button.new()
		_clear_button.text = "No Active Policy"
		_clear_button.custom_minimum_size = Vector2(fallback_button_min_size.x, 48.0)
		_clear_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_clear_button.toggle_mode = true

		if not _clear_button.pressed.is_connected(_on_clear_policy_pressed):
			_clear_button.pressed.connect(_on_clear_policy_pressed)

		button_container.add_child(_clear_button)

	if politics == null:
		return

	for policy in politics.available_policies:
		if policy == null:
			continue

		var button := _create_policy_button(policy)
		button_container.add_child(button)
		_buttons_by_policy[policy] = button


func _create_policy_button(policy: PolicyDefinitionV2) -> PolicyMenuButtonV2:
	var button: PolicyMenuButtonV2 = null

	if button_scene != null:
		button = button_scene.instantiate() as PolicyMenuButtonV2

	if button == null:
		button = PolicyMenuButtonV2.new()
		button.custom_minimum_size = fallback_button_min_size
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.setup(policy)

	if not button.policy_pressed.is_connected(_on_policy_pressed):
		button.policy_pressed.connect(_on_policy_pressed)

	return button


func _on_policy_pressed(policy: PolicyDefinitionV2) -> void:
	if politics == null:
		return

	politics.set_active_policy(policy)


func _on_clear_policy_pressed() -> void:
	if politics == null:
		return

	politics.clear_active_policy()


func _on_active_policy_changed(_policy: PolicyDefinitionV2) -> void:
	_update_selected_buttons()
	_refresh_status()


func _update_selected_buttons() -> void:
	if politics == null:
		return

	var active := politics.get_active_policy()

	if _clear_button != null:
		_clear_button.button_pressed = active == null

	for policy in _buttons_by_policy.keys():
		var button := _buttons_by_policy[policy] as PolicyMenuButtonV2

		if button != null:
			button.set_selected(policy == active)


func _refresh_status(_arg = null) -> void:
	if politics == null:
		if status_label != null:
			status_label.text = "Politics missing"
		return

	if status_label != null:
		status_label.text = politics.get_status_summary()

	if active_policy_label != null:
		if politics.active_policy == null:
			active_policy_label.text = "Active policy: none"
		else:
			active_policy_label.text = "Active policy: %s" % [politics.active_policy.display_name]
