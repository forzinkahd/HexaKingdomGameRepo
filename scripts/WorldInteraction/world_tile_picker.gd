class_name WorldTilePicker
extends Node

signal tile_selected(tile: WorldTile, visual_node: Node3D)

@export var camera: Camera3D
@export var ray_length: float = 2000.0
@export var print_debug: bool = false
@export var ignore_clicks_over_ui: bool = true

var selected_tile: WorldTile
var selected_node: Node3D


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if ignore_clicks_over_ui and _is_pointer_over_ui():
				return

			if _pick_tile(mb.position):
				get_viewport().set_input_as_handled()


func _is_pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()

	while hovered != null:
		if hovered.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true

		hovered = hovered.get_parent_control()

	return false


func _pick_tile(screen_position: Vector2) -> bool:
	if camera == null:
		camera = get_viewport().get_camera_3d()

	if camera == null:
		push_warning("WorldTilePicker: no camera available.")
		return false

	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var end := origin + direction * ray_length

	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var result := camera.get_world_3d().direct_space_state.intersect_ray(params)

	if result.is_empty():
		return false

	var collider := result.get("collider") as Object
	var node := collider as Node

	while node != null:
		if node.has_meta("world_tile"):
			selected_tile = node.get_meta("world_tile")
			selected_node = _find_node3d_with_tile(node)

			if selected_node == null:
				selected_node = node as Node3D

			if print_debug:
				_print_tile(selected_tile)

			tile_selected.emit(selected_tile, selected_node)
			return true

		node = node.get_parent()

	return false


func _find_node3d_with_tile(start: Node) -> Node3D:
	var node := start

	while node != null:
		if node is Node3D and node.has_meta("world_tile"):
			return node as Node3D

		node = node.get_parent()

	return null


func _print_tile(tile: WorldTile) -> void:
	print(
		"Selected tile: coord=", tile.coord,
		" height=", tile.height_units,
		" terrain=", tile.terrain_kind,
		" water=", tile.water_kind,
		" biome=", tile.biome_kind,
		" coast_mask=", tile.coast_mask,
		" walkable=", tile.walkable,
		" buildable=", tile.buildable
	)
