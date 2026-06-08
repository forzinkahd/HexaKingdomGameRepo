extends Camera3D

@export_category("Movement")
@export var movespeed: float = 40.0
@export var zoomspeed: float = 1.5
@export var zoom := Vector2(20.0, 90.0)
@export var height := Vector2(0.0, 40.0)
@export var rot := Vector2(-10.0, -80.0)
@export var sun: DirectionalLight3D

@export_category("Mouse Orbit")
@export var orbit_button: MouseButton = MOUSE_BUTTON_MIDDLE
@export var orbit_sensitivity: float = 0.004
@export var pitch_sensitivity: float = 0.004
@export var invert_orbit_x: bool = false
@export var invert_orbit_y: bool = false
@export var ignore_orbit_over_ui: bool = true

@export_category("Orbit Raycast")
@export var ray_length: float = 4000.0
@export var fallback_orbit_plane_y: float = 0.0

var parent: Node3D
var orbiting: bool = false
var orbit_pivot: Vector3 = Vector3.ZERO


func _ready() -> void:
	parent = get_parent() as Node3D
	adjust_height()
	adjust_rotation()
	make_current()


func _process(delta: float) -> void:
	move_camera(delta)


func move_camera(delta: float) -> void:
	if parent == null:
		return

	var move_vector: Vector3 = Vector3.ZERO

	if Input.is_action_pressed("MoveForward"):
		move_vector += -parent.transform.basis.z

	if Input.is_action_pressed("MoveBackwards"):
		move_vector += parent.transform.basis.z

	if Input.is_action_pressed("MoveLeft"):
		move_vector += -parent.transform.basis.x

	if Input.is_action_pressed("MoveRight"):
		move_vector += parent.transform.basis.x

	if Input.is_action_pressed("RotateCameraLeft"):
		parent.rotate(Vector3.UP, 0.01)

	if Input.is_action_pressed("RotateCameraRight"):
		parent.rotate(Vector3.UP, -0.01)

	if move_vector != Vector3.ZERO:
		move_vector = move_vector.normalized() * movespeed * delta
		parent.position += move_vector


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			change_fov(mb.button_index)
			adjust_height()
			adjust_rotation()
			adjust_shadows()
			return

		if mb.button_index == orbit_button:
			if mb.pressed:
				if ignore_orbit_over_ui and _is_pointer_over_ui():
					return

				_start_orbit_without_jump(mb.position)
			else:
				orbiting = false

			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and orbiting:
		var motion := event as InputEventMouseMotion
		_orbit_from_mouse_motion(motion.relative)
		get_viewport().set_input_as_handled()


func _start_orbit_without_jump(screen_position: Vector2) -> void:
	orbit_pivot = _get_orbit_pivot_from_screen(screen_position)
	orbiting = true

	# Important:
	# Do not move parent here.
	# Do not move camera here.
	# Do not call look_at here.
	# This prevents the press-time camera snap.


func _orbit_from_mouse_motion(relative: Vector2) -> void:
	if parent == null:
		return

	var yaw_direction := -1.0 if invert_orbit_x else 1.0
	var pitch_direction := -1.0 if invert_orbit_y else 1.0

	var yaw_delta := -relative.x * orbit_sensitivity * yaw_direction
	var pitch_delta := -relative.y * pitch_sensitivity * pitch_direction

	if abs(yaw_delta) > 0.000001:
		_rotate_parent_around_pivot(Vector3.UP, yaw_delta)

	if abs(pitch_delta) > 0.000001:
		var pitch_axis := global_transform.basis.x.normalized()
		_rotate_parent_around_pivot(pitch_axis, pitch_delta)


func _rotate_parent_around_pivot(axis: Vector3, angle: float) -> void:
	if parent == null:
		return

	if axis.length() <= 0.0001:
		return

	var old_transform := parent.global_transform
	var relative_position := old_transform.origin - orbit_pivot

	var rotation_basis := Basis(axis.normalized(), angle)

	old_transform.origin = orbit_pivot + rotation_basis * relative_position
	old_transform.basis = rotation_basis * old_transform.basis

	parent.global_transform = old_transform


func _get_orbit_pivot_from_screen(screen_position: Vector2) -> Vector3:
	var origin := project_ray_origin(screen_position)
	var direction := project_ray_normal(screen_position)
	var end := origin + direction * ray_length

	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var result := get_world_3d().direct_space_state.intersect_ray(params)

	if not result.is_empty():
		return result.position

	return _ray_plane_fallback(origin, direction, fallback_orbit_plane_y)


func _ray_plane_fallback(origin: Vector3, direction: Vector3, plane_y: float) -> Vector3:
	if abs(direction.y) < 0.0001:
		return parent.global_position if parent != null else Vector3.ZERO

	var t := (plane_y - origin.y) / direction.y

	if t < 0.0:
		return parent.global_position if parent != null else Vector3.ZERO

	return origin + direction * t


func _is_pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()

	while hovered != null:
		if hovered.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true

		hovered = hovered.get_parent_control()

	return false


func change_fov(index: int) -> void:
	if index == MOUSE_BUTTON_WHEEL_UP:
		fov = max(zoom.x, fov - zoomspeed)
	elif index == MOUSE_BUTTON_WHEEL_DOWN:
		fov = min(zoom.y, fov + zoomspeed)


func adjust_height() -> void:
	var new_height := inverse_lerp(zoom.x, zoom.y, fov)
	position.y = lerpf(height.x, height.y, new_height)


func adjust_rotation() -> void:
	var min_r := deg_to_rad(rot.x)
	var max_r := deg_to_rad(rot.y)
	var new_rot := inverse_lerp(zoom.x, zoom.y, fov)
	rotation.x = lerpf(min_r, max_r, new_rot)


func adjust_shadows() -> void:
	if sun == null:
		return

	if fov < 40 or position.y < 20:
		sun.shadow_enabled = true
	elif sun.shadow_enabled:
		sun.shadow_enabled = false
