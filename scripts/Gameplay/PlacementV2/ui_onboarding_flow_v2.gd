class_name UIOnboardingFlowV2
extends Node

@export var intro_panel: Control
@export var controls_panel: Control
@export var build_menu_panel: Control
@export var goals_panel: Control
@export var town_center_panel: Control

@export var hide_gameplay_panels_on_ready: bool = true
@export var show_controls_after_intro: bool = true
@export var show_build_menu_after_intro: bool = true
@export var show_goals_after_intro: bool = true
@export var show_town_center_after_intro: bool = false


func _ready() -> void:
	var skip_intro_for_session : Variant = SaveGameManagerV2.consume_skip_intro_on_next_game_start()
	var show_intro : Variant = not skip_intro_for_session

	if show_intro:
		if hide_gameplay_panels_on_ready:
			_set_gameplay_panels_visible(false)

		if intro_panel != null:
			intro_panel.show()

			if intro_panel.has_signal("dismissed"):
				if not intro_panel.dismissed.is_connected(_on_intro_dismissed):
					intro_panel.dismissed.connect(_on_intro_dismissed)
	else:
		if intro_panel != null:
			intro_panel.hide()

		_show_default_gameplay_panels()


func _on_intro_dismissed() -> void:
	SaveGameManagerV2.mark_intro_dismissed()
	_show_default_gameplay_panels()


func _set_gameplay_panels_visible(value: bool) -> void:
	if controls_panel != null:
		controls_panel.visible = value

	if build_menu_panel != null:
		build_menu_panel.visible = value

	if goals_panel != null:
		goals_panel.visible = value

	if town_center_panel != null:
		town_center_panel.visible = value


func _show_default_gameplay_panels() -> void:
	if controls_panel != null:
		controls_panel.visible = show_controls_after_intro

	if build_menu_panel != null:
		build_menu_panel.visible = show_build_menu_after_intro

	if goals_panel != null:
		goals_panel.visible = show_goals_after_intro

	if town_center_panel != null:
		town_center_panel.visible = show_town_center_after_intro
