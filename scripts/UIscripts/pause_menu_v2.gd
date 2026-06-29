class_name PauseMenuV2
extends Control

@export_file("*.tscn") var main_menu_scene_path: String = "res://Scenes/UIElements/main_menu.tscn"

@export var save_controller: GameSaveControllerV2

@export_group("Buttons")
@export var resume_button: Button
@export var save_button: Button
@export var load_button: Button
@export var main_menu_button: Button
@export var quit_button: Button

@export_group("Status")
@export var status_label: Label
@export var auto_clear_status_seconds: float = 2.5

@export_group("Input")
@export var toggle_pause_action: StringName = &"ui_cancel"
@export var pause_game_while_open: bool = true
@export var start_hidden: bool = true

var _status_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if save_controller == null:
		save_controller = get_tree().get_first_node_in_group("game_save_controller") as GameSaveControllerV2

	if resume_button != null and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)

	if save_button != null and not save_button.pressed.is_connected(_on_save_pressed):
		save_button.pressed.connect(_on_save_pressed)

	if load_button != null and not load_button.pressed.is_connected(_on_load_pressed):
		load_button.pressed.connect(_on_load_pressed)

	if main_menu_button != null and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)

	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	if start_hidden:
		hide_menu()
	else:
		show_menu()

	_refresh_buttons()


func _process(delta: float) -> void:
	if _status_timer <= 0.0:
		return

	_status_timer -= delta

	if _status_timer <= 0.0 and status_label != null:
		status_label.text = ""


func _input(event: InputEvent) -> void:
	if toggle_pause_action == &"":
		return

	if event.is_action_pressed(toggle_pause_action):
		toggle_menu()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()

	if pause_game_while_open:
		get_tree().paused = true

	_refresh_buttons()


func hide_menu() -> void:
	visible = false

	if pause_game_while_open:
		get_tree().paused = false


func toggle_menu() -> void:
	if visible:
		hide_menu()
	else:
		show_menu()


func _refresh_buttons() -> void:
	if load_button != null:
		load_button.disabled = not SaveGameManagerV2.save_exists()

	if save_button != null:
		save_button.disabled = save_controller == null


func _on_resume_pressed() -> void:
	hide_menu()


func _on_save_pressed() -> void:
	if save_controller == null:
		_set_status("Save failed: save controller missing.")
		return

	var was_paused := get_tree().paused
	get_tree().paused = false

	var ok := save_controller.save_game()

	get_tree().paused = was_paused

	if ok:
		_set_status("Game saved.")
		_refresh_buttons()
	else:
		_set_status("Save failed.")


func _on_load_pressed() -> void:
	if save_controller == null:
		_set_status("Load failed: save controller missing.")
		return

	if not SaveGameManagerV2.save_exists():
		_set_status("Load failed: no save file.")
		_refresh_buttons()
		return

	var was_paused := get_tree().paused
	get_tree().paused = false

	var ok := save_controller.load_game()

	get_tree().paused = was_paused

	if ok:
		_set_status("Game loaded.")
		_refresh_buttons()
	else:
		_set_status("Load failed.")


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

	_status_timer = auto_clear_status_seconds
