class_name PlacementCursorFeedbackV2
extends PanelContainer

@export var label: Label
@export var offset: Vector2 = Vector2(24.0, 24.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	if label == null:
		label = find_child("Label", true, false) as Label


func show_feedback(text: String, screen_position: Vector2) -> void:
	if text.strip_edges() == "":
		hide_feedback()
		return

	if label != null:
		label.text = text

	position = screen_position + offset
	visible = true
	move_to_front()


func hide_feedback() -> void:
	visible = false
	if label != null:
		label.text = ""
