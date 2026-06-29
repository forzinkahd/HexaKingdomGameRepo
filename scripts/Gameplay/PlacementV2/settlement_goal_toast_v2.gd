class_name SettlementGoalToastV2
extends MarginContainer

@export var goals_manager: SettlementGoalsManagerV2
@export var label: Label
@export var save_controller: GameSaveControllerV2

@export_group("Display")
@export var visible_seconds: float = 2.5
@export var prefix: String = "Quest completed: "
@export var use_goal_id: bool = true
@export var use_goal_display_name_if_not_id: bool = true

@export_group("Placement")
@export var center_horizontally_on_ready: bool = true
@export_range(0.0, 1.0) var vertical_screen_ratio: float = 0.66

var _timer: float = 0.0
var _is_loading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	if label == null:
		label = find_child("QuestCompletedLabel", true, false) as Label

	if save_controller == null:
		save_controller = get_tree().get_first_node_in_group("game_save_controller") as GameSaveControllerV2

	_connect_save_controller()

	if center_horizontally_on_ready:
		call_deferred("_apply_screen_position")

	reconnect_manager()


func _process(delta: float) -> void:
	if not visible:
		return

	_timer -= delta

	if _timer <= 0.0:
		hide_message()


func set_goals_manager(source_manager: SettlementGoalsManagerV2) -> void:
	if goals_manager == source_manager:
		return

	_disconnect_manager()
	goals_manager = source_manager
	reconnect_manager()


func reconnect_manager() -> void:
	_disconnect_manager()

	if goals_manager == null:
		return

	if not goals_manager.goal_completed.is_connected(_on_goal_completed):
		goals_manager.goal_completed.connect(_on_goal_completed)


func show_message(message: String) -> void:
	if _is_loading:
		return

	if label != null:
		label.text = message
	else:
		push_warning("SettlementGoalToastV2: label missing.")

	_timer = visible_seconds
	show()
	move_to_front()

	if center_horizontally_on_ready:
		_apply_screen_position()


func hide_message() -> void:
	_timer = 0.0

	if label != null:
		label.text = ""

	hide()


func prepare_for_load() -> void:
	_is_loading = true
	hide_message()


func finish_load() -> void:
	_is_loading = false
	hide_message()


func _on_goal_completed(goal: SettlementGoalDefinitionV2) -> void:
	if _is_loading:
		return

	if goal == null:
		return

	var goal_text := ""

	if use_goal_id:
		goal_text = str(goal.id)
	elif use_goal_display_name_if_not_id:
		goal_text = goal.display_name
	else:
		goal_text = str(goal.id)

	show_message(prefix + goal_text)


func _connect_save_controller() -> void:
	if save_controller == null:
		return

	if save_controller.has_signal("load_started"):
		if not save_controller.load_started.is_connected(prepare_for_load):
			save_controller.load_started.connect(prepare_for_load)

	if save_controller.has_signal("load_finished"):
		if not save_controller.load_finished.is_connected(finish_load):
			save_controller.load_finished.connect(finish_load)


func _apply_screen_position() -> void:
	var viewport_size := get_viewport_rect().size
	var target_center := Vector2(
		viewport_size.x * 0.5,
		viewport_size.y * vertical_screen_ratio
	)

	var own_size := size

	if own_size.x <= 0.0 or own_size.y <= 0.0:
		own_size = get_combined_minimum_size()

	position = target_center - own_size * 0.5


func _disconnect_manager() -> void:
	if goals_manager == null:
		return

	if goals_manager.goal_completed.is_connected(_on_goal_completed):
		goals_manager.goal_completed.disconnect(_on_goal_completed)
