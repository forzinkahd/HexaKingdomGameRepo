class_name SettlementGoalsPanelV2
extends Label

@export var goals_manager: SettlementGoalsManagerV2

@export_group("Display")
@export var title: String = "Welcome to the New Realm"
@export_multiline var intro_text: String = "Begin by securing the first materials and establishing your settlement."
@export var show_completed_goals: bool = true
@export var show_locked_goals: bool = true
@export var show_rewards: bool = true
@export var show_progress_percent: bool = true
@export var refresh_seconds: float = 0.25

@export_group("Formatting")
@export var completed_prefix: String = "✓"
@export var active_prefix: String = "□"
@export var locked_prefix: String = "🔒"
@export var section_separator: String = "--------------------"

var _elapsed: float = 0.0


func _ready() -> void:
	_connect_manager()
	refresh_panel()


func _process(delta: float) -> void:
	_elapsed += delta

	if _elapsed < refresh_seconds:
		return

	_elapsed = 0.0
	refresh_panel()


func set_goals_manager(source_manager: SettlementGoalsManagerV2) -> void:
	if goals_manager == source_manager:
		return

	_disconnect_manager()
	goals_manager = source_manager
	_connect_manager()
	refresh_panel()


func refresh_panel(_arg = null) -> void:
	var lines: Array[String] = []
	lines.append(title)
	lines.append(section_separator)

	if intro_text != "":
		lines.append(intro_text)
		lines.append("")

	if goals_manager == null:
		lines.append("SettlementGoalsManagerV2 missing")
		text = "\n".join(lines)
		return

	var visible_goals := goals_manager.get_visible_goals()
	var completed := goals_manager.get_visible_completed_count()

	lines.append("Progress: %d / %d" % [completed, visible_goals.size()])
	lines.append("")

	for goal in visible_goals:
		if goal == null:
			continue

		var complete := goals_manager.is_goal_completed(goal)
		var prereq_met := goals_manager.are_prerequisites_met(goal)

		if complete and not show_completed_goals:
			continue

		if not prereq_met and not show_locked_goals:
			continue

		lines.append(_format_goal(goal, complete, prereq_met))
		lines.append("")

	text = "\n".join(lines)


func _connect_manager() -> void:
	if goals_manager == null:
		return

	if not goals_manager.goals_changed.is_connected(refresh_panel):
		goals_manager.goals_changed.connect(refresh_panel)

	if not goals_manager.goal_completed.is_connected(_on_goal_completed):
		goals_manager.goal_completed.connect(_on_goal_completed)


func _disconnect_manager() -> void:
	if goals_manager == null:
		return

	if goals_manager.goals_changed.is_connected(refresh_panel):
		goals_manager.goals_changed.disconnect(refresh_panel)

	if goals_manager.goal_completed.is_connected(_on_goal_completed):
		goals_manager.goal_completed.disconnect(_on_goal_completed)


func _on_goal_completed(_goal: SettlementGoalDefinitionV2) -> void:
	refresh_panel()


func _format_goal(goal: SettlementGoalDefinitionV2, complete: bool, prereq_met: bool) -> String:
	var lines: Array[String] = []
	var prefix := active_prefix

	if complete:
		prefix = completed_prefix
	elif not prereq_met:
		prefix = locked_prefix

	lines.append("%s %s" % [prefix, goal.display_name])

	if goal.description != "":
		lines.append(goal.description)

	lines.append("Target: %s" % [goal.target_summary()])
	lines.append("Progress: %s" % [goals_manager.get_goal_progress_text(goal)])

	if show_progress_percent and prereq_met:
		lines.append("Completion: %d%%" % [
			int(round(goals_manager.get_goal_completion_ratio(goal) * 100.0))
		])

	if show_rewards and goal.has_reward():
		lines.append("Reward: %s" % [goal.reward_summary()])

	return "\n".join(lines)
