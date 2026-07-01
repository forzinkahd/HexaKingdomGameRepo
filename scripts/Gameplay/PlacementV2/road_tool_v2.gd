class_name RoadToolV2
extends Node

signal road_mode_changed(enabled: bool)
signal road_preview_changed(tile: WorldTile, valid: bool, reason: String)

@export var picker: WorldTilePicker
@export var road_network: RoadNetworkV2
@export var cursor_feedback: PlacementCursorFeedbackV2
@export var tile_query: WorldTileQueryV2

@export_group("Input")
@export var toggle_action: StringName = &"toggle_road_tool"
@export var place_action: StringName = &"place_road"
@export var fallback_place_mouse_button: MouseButton = MOUSE_BUTTON_RIGHT

@export_group("Behavior")
@export var enabled: bool = false
@export var hide_building_preview_while_active: bool = true
@export var show_cursor_feedback: bool = true

var current_tile: WorldTile
var current_visual_node: Node3D


func _ready() -> void:
	add_to_group("road_tool")
	
	if picker == null:
		picker = get_node_or_null("../WorldTilePicker") as WorldTilePicker
	
	if road_network == null:
		road_network = get_node_or_null("../RoadNetworkV2") as RoadNetworkV2
	
	if picker != null:
		if not picker.tile_selected.is_connected(_on_tile_selected):
			picker.tile_selected.connect(_on_tile_selected)
	
	if tile_query == null:
		tile_query = get_node_or_null("../WorldTileQueryV2") as WorldTileQueryV2
	
	set_enabled(enabled)


func _input(event: InputEvent) -> void:
	if toggle_action != &"" and event.is_action_pressed(toggle_action):
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()
		return

	if not enabled:
		return

	if place_action != &"" and event.is_action_pressed(place_action):
		_try_place_current_road()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == fallback_place_mouse_button and mb.pressed:
			_try_place_current_road()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not enabled:
		return
	
	_refresh_current_tile_from_mouse()
	_update_feedback()


func set_enabled(value: bool) -> void:
	enabled = value
	road_mode_changed.emit(enabled)

	if not enabled:
		if cursor_feedback != null:
			cursor_feedback.hide_feedback()
	else:
		_update_feedback()


func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	current_tile = tile
	current_visual_node = visual_node

	if enabled:
		_update_feedback()


func _try_place_current_road() -> bool:
	if road_network == null:
		return false
	
	_refresh_current_tile_from_mouse()
	
	if current_tile == null:
		_update_feedback()
		return false
	
	var ok := road_network.place_road(current_tile, current_visual_node, false)
	
	_update_feedback()
	return ok


func _update_feedback() -> void:
	if not show_cursor_feedback:
		return
	
	if cursor_feedback == null:
		return
	
	if not enabled:
		cursor_feedback.hide_feedback()
		return
	
	if road_network == null:
		cursor_feedback.show_feedback("Road tool missing", get_viewport().get_mouse_position())
		return
	
	if current_tile == null:
		cursor_feedback.show_feedback("Road: select tile", get_viewport().get_mouse_position())
		return
	
	var reason := road_network.get_road_invalid_reason(current_tile)
	var lines: Array[String] = []
	
	if reason == "":
		lines.append("Road: VALID")
		lines.append("Cost: " + _road_cost_text())
	else:
		lines.append("Road: INVALID")
		lines.append(reason)
	
	cursor_feedback.show_feedback(
		"\n".join(lines),
		get_viewport().get_mouse_position()
	)
	
	road_preview_changed.emit(current_tile, reason == "", reason)


func _refresh_current_tile_from_mouse() -> void:
	if tile_query == null:
		return
	
	var result := tile_query.query_mouse()
	
	if result.is_empty():
		current_tile = null
		current_visual_node = null
		return
	
	current_tile = result.get("tile") as WorldTile
	current_visual_node = result.get("visual_node") as Node3D


func _road_cost_text() -> String:
	if road_network == null:
		return "unknown"

	var parts: Array[String] = []

	if road_network.cost_wood > 0:
		parts.append("Wood %d" % [road_network.cost_wood])

	if road_network.cost_stone > 0:
		parts.append("Stone %d" % [road_network.cost_stone])

	if parts.is_empty():
		return "Free"

	return ", ".join(parts)
