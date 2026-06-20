class_name SettlementGoalsPanelV2
extends Label

@export var goals_manager: SettlementGoalsManagerV2
@export_group("Display")
@export var title: String = "Welcome to the New Kingdom"
@export_multiline var intro_text: String = "Begin by securing the first materials and establishing your settlement."
@export var show_completed_goals: bool = true
@export var show_locked_goals: bool = true
@export var show_rewards: bool = true
@export var show_progress_percent: bool = true
@export var refresh_seconds: float = 0.25

var _elapsed: float = 0.0

func _ready() -> void:
	if goals_manager == null:
		goals_manager = get_node_or_null("../SettlementGoalsManagerV2") as SettlementGoalsManagerV2
	if goals_manager != null:
		if not goals_manager.goals_changed.is_connected(_refresh): goals_manager.goals_changed.connect(_refresh)
		if not goals_manager.goal_completed.is_connected(_on_goal_completed): goals_manager.goal_completed.connect(_on_goal_completed)
	_refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= refresh_seconds:
		_elapsed = 0.0
		_refresh()

func _on_goal_completed(_goal: SettlementGoalDefinitionV2) -> void:
	_refresh()

func _refresh(_arg = null) -> void:
	var lines: Array[String] = []
	lines.append(title)
	lines.append("--------------------")
	if intro_text != "":
		lines.append(intro_text)
		lines.append("")
	if goals_manager == null:
		lines.append("SettlementGoalsManagerV2 missing")
		text = "\n".join(lines)
		return
	var visible_goals := goals_manager.get_visible_goals()
	lines.append("Progress: %d / %d" % [goals_manager.get_visible_completed_count(), visible_goals.size()])
	lines.append("")
	for goal in visible_goals:
		var complete := goals_manager.is_goal_completed(goal)
		var prereq_met := goals_manager.are_prerequisites_met(goal)
		if complete and not show_completed_goals: continue
		if not prereq_met and not show_locked_goals: continue
		lines.append(_format_goal(goal, complete, prereq_met))
		lines.append("")
	text = "\n".join(lines)

func _format_goal(goal: SettlementGoalDefinitionV2, complete: bool, prereq_met: bool) -> String:
	var lines: Array[String] = []
	var prefix := "□"
	if complete: prefix = "✓"
	elif not prereq_met: prefix = "LOCKED"
	lines.append("%s %s" % [prefix, goal.display_name])
	if goal.description != "": lines.append(goal.description)
	lines.append("Target: %s" % [goal.target_summary()])
	lines.append("Progress: %s" % [goals_manager.get_goal_progress_text(goal)])
	if show_progress_percent and prereq_met:
		lines.append("Completion: %d%%" % [int(round(goals_manager.get_goal_completion_ratio(goal) * 100.0))])
	if show_rewards and goal.has_reward():
		lines.append("Reward: %s" % [goal.reward_summary()])
	return "\n".join(lines)
