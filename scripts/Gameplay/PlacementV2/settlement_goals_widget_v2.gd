class_name SettlementGoalsWidgetV2
extends Control

@export var goals_manager: SettlementGoalsManagerV2

@export_group("Child Nodes")
@export var goals_panel: SettlementGoalsPanelV2

@export_group("Behavior")
@export var find_children_on_ready: bool = true
@export var find_manager_by_group: bool = true
@export var manager_group_name: StringName = &"settlement_goals_manager"

@export_group("Panel Display")
@export var title: String = "Welcome to the New Realm"
@export_multiline var intro_text: String = "Begin by securing the first materials and establishing your settlement."
@export var show_completed_goals: bool = true
@export var show_locked_goals: bool = true
@export var show_rewards: bool = true
@export var show_progress_percent: bool = true


func _ready() -> void:
	var save_controller := get_tree().get_first_node_in_group("game_save_controller") as GameSaveControllerV2
	
	if save_controller != null:
		if save_controller.has_signal("load_started"):
			if not save_controller.load_started.is_connected(_on_load_started):
				save_controller.load_started.connect(_on_load_started)
	
		if save_controller.has_signal("load_finished"):
			if not save_controller.load_finished.is_connected(_on_load_finished):
				save_controller.load_finished.connect(_on_load_finished)
	
	if goals_manager == null and find_manager_by_group:
		goals_manager = get_tree().get_first_node_in_group(manager_group_name) as SettlementGoalsManagerV2

	if find_children_on_ready and goals_panel == null:
		goals_panel = find_child("SettlementGoalsPanel", true, false) as SettlementGoalsPanelV2

	_apply_references()
	_apply_display_settings()


func set_goals_manager(source_manager: SettlementGoalsManagerV2) -> void:
	goals_manager = source_manager
	_apply_references()


func open() -> void:
	show()


func close() -> void:
	hide()


func toggle() -> void:
	visible = not visible


func _apply_references() -> void:
	if goals_panel != null:
		goals_panel.goals_manager = goals_manager
		goals_panel.refresh_panel()


func _apply_display_settings() -> void:
	if goals_panel != null:
		goals_panel.title = title
		goals_panel.intro_text = intro_text
		goals_panel.show_completed_goals = show_completed_goals
		goals_panel.show_locked_goals = show_locked_goals
		goals_panel.show_rewards = show_rewards
		goals_panel.show_progress_percent = show_progress_percent
		goals_panel.refresh_panel()


func _on_load_started() -> void:
	goals_panel.title = "Loading goals..."
	
	
func _on_load_finished() -> void:
	call_deferred("_refresh_after_load")


func _refresh_after_load() -> void:
	if goals_manager != null:
		if goals_manager.has_signal("goals_changed"):
			# optional, not necessary if already connected
			pass
	
	goals_panel.refresh_panel()
