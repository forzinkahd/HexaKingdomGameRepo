#class_name SaveGameManagerV2
extends Node

signal save_completed(path: String)
signal load_completed(path: String)
signal save_failed(path: String, reason: String)
signal load_failed(path: String, reason: String)

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save_slot_1.json"
const PREFS_PATH := "user://player_prefs.json"

var start_new_game: bool = false
var load_requested: bool = false
var pending_loaded_data: Dictionary = {}

var intro_dismissed: bool = false
var skip_intro_on_next_game_start: bool = false


func _ready() -> void:
	load_preferences()


func save_exists(path: String = DEFAULT_SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


func request_new_game() -> void:
	start_new_game = true
	load_requested = false
	pending_loaded_data.clear()

	# If the player has dismissed the intro before, keep it hidden.
	skip_intro_on_next_game_start = intro_dismissed


func request_load_game(path: String = DEFAULT_SAVE_PATH) -> bool:
	var data := load_from_disk(path)

	if data.is_empty():
		return false

	pending_loaded_data = data
	load_requested = true
	start_new_game = false

	# Continue Game should never show the intro.
	skip_intro_on_next_game_start = true

	return true


func consume_skip_intro_on_next_game_start() -> bool:
	var result := skip_intro_on_next_game_start
	skip_intro_on_next_game_start = false
	return result


func consume_pending_loaded_data() -> Dictionary:
	var data := pending_loaded_data.duplicate(true)
	pending_loaded_data.clear()
	load_requested = false
	return data


func save_to_disk(data: Dictionary, path: String = DEFAULT_SAVE_PATH) -> bool:
	data["version"] = SAVE_VERSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var reason := "Could not open save file for writing: %s" % [str(FileAccess.get_open_error())]
		push_warning(reason)
		save_failed.emit(path, reason)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit(path)
	print("SaveGameManagerV2: saved to ", path)
	print("Global save path: ", ProjectSettings.globalize_path(path))
	return true


func load_from_disk(path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		var reason := "Save file does not exist."
		push_warning("SaveGameManagerV2: " + reason + " " + path)
		load_failed.emit(path, reason)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var reason := "Could not open save file for reading: %s" % [str(FileAccess.get_open_error())]
		push_warning(reason)
		load_failed.emit(path, reason)
		return {}
	var json_text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		var reason := "Save file is not a valid JSON dictionary."
		push_warning(reason)
		load_failed.emit(path, reason)
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) > SAVE_VERSION:
		var reason := "Save version is newer than this game version."
		push_warning(reason)
		load_failed.emit(path, reason)
		return {}
	load_completed.emit(path)
	print("SaveGameManagerV2: loaded from ", path)
	return data


func delete_save(path: String = DEFAULT_SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func load_preferences() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		intro_dismissed = false
		return

	var file := FileAccess.open(PREFS_PATH, FileAccess.READ)

	if file == null:
		intro_dismissed = false
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		intro_dismissed = false
		return

	intro_dismissed = bool(parsed.get("intro_dismissed", false))


func save_preferences() -> void:
	var data := {
		"intro_dismissed": intro_dismissed
	}

	var file := FileAccess.open(PREFS_PATH, FileAccess.WRITE)

	if file == null:
		push_warning("SaveGameManagerV2: could not save preferences.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func mark_intro_dismissed() -> void:
	intro_dismissed = true
	save_preferences()


func should_show_intro() -> bool:
	return not intro_dismissed
