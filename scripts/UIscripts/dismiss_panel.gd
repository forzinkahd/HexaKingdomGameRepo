class_name DismissiblePanel
extends Control

# Use for any panel that needs to disappear but can be reopened.

signal dismissed

@export var dismiss_button: Button
@export var free_on_dismiss: bool = false


func _ready() -> void:
	if dismiss_button != null:
		dismiss_button.pressed.connect(dismiss)


func dismiss() -> void:
	SaveGameManagerV2.mark_intro_dismissed()
	
	dismissed.emit()

	if free_on_dismiss:
		queue_free()
	else:
		hide()


func open() -> void:
	show()
