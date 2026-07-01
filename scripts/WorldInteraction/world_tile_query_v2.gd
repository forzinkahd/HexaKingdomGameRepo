class_name WorldTileQueryV2
extends Node

@export var camera: Camera3D
@export var ray_length: float = 2000.0
@export var collide_with_areas: bool = true
@export var collide_with_bodies: bool = true
@export var ignore_ui: bool = true


func query_mouse() -> Dictionary:
	return query_screen_position(get_viewport().get_mouse_position())


func query_screen_position(screen_position: Vector2) -> Dictionary:
	if ignore_ui and _is_pointer_over_ui():
		return {}

	if camera == null:
		camera = get_viewport().get_camera_3d()

	if camera == null:
		push_warning("WorldTileQueryV2: no camera available.")
		return {}

	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var end := origin + direction * ray_length

	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.collide_with_areas = collide_with_areas
	params.collide_with_bodies = collide_with_bodies

	var hit := camera.get_world_3d().direct_space_state.intersect_ray(params)

	if hit.is_empty():
		return {}

	return _extract_tile_result(hit)


func _extract_tile_result(hit: Dictionary) -> Dictionary:
	var collider := hit.get("collider") as Object
	var node := collider as Node

	while node != null:
		if node.has_meta("world_tile"):
			var tile = node.get_meta("world_tile")

			if tile is WorldTile:
				return {
					"tile": tile,
					"visual_node": _find_node3d_with_tile(node),
					"hit_position": hit.get("position", Vector3.ZERO),
					"collider": collider
				}

		node = node.get_parent()

	return {}


func _find_node3d_with_tile(start: Node) -> Node3D:
	var node := start

	while node != null:
		if node is Node3D and node.has_meta("world_tile"):
			return node as Node3D

		node = node.get_parent()

	return null


func _is_pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()

	while hovered != null:
		if hovered.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true

		hovered = hovered.get_parent_control()

	return false
