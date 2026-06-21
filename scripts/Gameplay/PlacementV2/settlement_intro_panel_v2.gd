class_name SettlementIntroPanelV2
extends PanelContainer

signal intro_dismissed

@export var title_label: Label
@export var body_label: Label
@export var dismiss_button: Button

@export_group("Text")
@export var title_text: String = "Welcome to the New Kingdom"
@export_multiline var body_text: String = "A small group of settlers has arrived in an untouched land. Choose a safe place for the Town Center, gather wood and stone, and guide the first decisions of the settlement."

@export_group("Behavior")
@export var show_on_ready: bool = true
@export var pause_game_while_open: bool = false
@export var dismiss_action: StringName = &"ui_accept"

var dismissed: bool = false


func _ready() -> void:
	if title_label != null:
		title_label.text = title_text

	if body_label != null:
		body_label.text = body_text

	if dismiss_button != null and not dismiss_button.pressed.is_connected(dismiss):
		dismiss_button.pressed.connect(dismiss)

	visible = show_on_ready
	if pause_game_while_open and visible:
		get_tree().paused = true


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if dismiss_action != &"" and InputMap.has_action(dismiss_action):
		if event.is_action_pressed(dismiss_action):
			dismiss()
			get_viewport().set_input_as_handled()


func dismiss() -> void:
	if dismissed:
		return

	dismissed = true
	visible = false
	if pause_game_while_open:
		get_tree().paused = false
	intro_dismissed.emit()


func open_intro() -> void:
	dismissed = false
	visible = true
	if pause_game_while_open:
		get_tree().paused = true
