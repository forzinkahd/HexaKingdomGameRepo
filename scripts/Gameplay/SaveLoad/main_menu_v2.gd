class_name MainMenuV2
extends Control

@export_file("*.tscn") var game_scene_path: String = "res://Scenes/GameScene.tscn"
@export var new_game_button: Button
@export var continue_button: Button
@export var quit_button: Button


func _ready() -> void:
	if new_game_button != null and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button != null:
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
		continue_button.disabled = not SaveGameManagerV2.save_exists()
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)


func _on_new_game_pressed() -> void:
	SaveGameManagerV2.request_new_game()
	get_tree().change_scene_to_file(game_scene_path)


func _on_continue_pressed() -> void:
	if SaveGameManagerV2.request_load_game():
		get_tree().change_scene_to_file(game_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
