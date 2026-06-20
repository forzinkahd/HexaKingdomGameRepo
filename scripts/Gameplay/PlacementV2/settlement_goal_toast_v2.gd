class_name SettlementGoalToastV2
extends Label

@export var goals_manager: SettlementGoalsManagerV2
@export var visible_seconds: float = 3.0
@export var prefix: String = "Goal complete: "

var _timer: float = 0.0

func _ready() -> void:
	visible = false
	if goals_manager == null:
		goals_manager = get_node_or_null("../SettlementGoalsManagerV2") as SettlementGoalsManagerV2
	if goals_manager != null and not goals_manager.goal_completed.is_connected(_on_goal_completed):
		goals_manager.goal_completed.connect(_on_goal_completed)

func _process(delta: float) -> void:
	if not visible: return
	_timer -= delta
	if _timer <= 0.0: visible = false

func _on_goal_completed(goal: SettlementGoalDefinitionV2) -> void:
	if goal == null: return
	text = prefix + goal.display_name
	_timer = visible_seconds
	visible = true
