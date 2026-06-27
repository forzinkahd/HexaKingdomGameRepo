class_name UIPanelToggleInputBootstrapV2
extends Node

# Optional helper. Attach once temporarily or keep it in the scene if you prefer
# creating input actions from code instead of Project Settings.

@export var create_actions_on_ready: bool = true


func _ready() -> void:
	if not create_actions_on_ready:
		return

	# F Keys mapping
	_ensure_key_action(&"ToggleTownInfluenceOverlay", KEY_F1)
	_ensure_key_action(&"ToggleTownInfoPanel", KEY_F2)
	_ensure_key_action(&"ToggleSelectedBuildingPanel", KEY_F3)
	#_ensure_key_action(&"ToggleProductionPanel", KEY_F4)
	#_ensure_key_action(&"ToggleTownInfluenceOverlay", KEY_F5)
	_ensure_key_action(&"ToggleRegistryPanel", KEY_F6)
	_ensure_key_action(&"ToggleResourceNodes", KEY_F7)
	_ensure_key_action(&"ToggleAllDebugPanels", KEY_F8)


func _ensure_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)
