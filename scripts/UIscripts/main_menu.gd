class_name MainMenuV2
extends Control

@export_file("*.tscn") var game_scene_path: String = "res://Scenes/GameScene.tscn"
@export var continue_button: Button
@export var new_game_button: Button
@export var quit_button: Button


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	continue_button.disabled = not SaveGameManagerV2.save_exists()


func _on_new_game_pressed() -> void:
	SaveGameManagerV2.start_new_game = true
	get_tree().change_scene_to_file(game_scene_path)


func _on_continue_pressed() -> void:
	SaveGameManagerV2.load_requested = true
	get_tree().change_scene_to_file(game_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
