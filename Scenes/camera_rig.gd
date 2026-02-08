extends Node3D

@export var cam: Camera3D
@export var sensitivity := 0.005
@export var min_pitch := deg_to_rad(-65.0)
@export var max_pitch := deg_to_rad(65.0)
@export var max_raycast_dist := 5000.0

var orbiting := false
var pivot := Vector3.ZERO
var pitch: float = 0.0

func _ready() -> void:
	if cam == null:
		push_error("CameraRig: 'cam' is not assigned.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		orbiting = event.pressed
		if orbiting:
			pivot = _pick_pivot_under_mouse()
			# Optional: capture mouse while orbiting
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and orbiting:
		_orbit(event.relative)

func _orbit(mouse_delta: Vector2) -> void:
	# Yaw around global up at pivot
	var yaw_angle := -mouse_delta.x * sensitivity
	_rotate_around_point(pivot, Vector3.UP, yaw_angle)

	# Pitch around the camera rig's RIGHT axis at pivot (after yaw)
	var right_axis: Vector3 = global_transform.basis.x.normalized()
	var pitch_delta: float = -mouse_delta.y * sensitivity
	var new_pitch: float = clamp(pitch + pitch_delta, min_pitch, max_pitch)
	var applied: float = new_pitch - pitch
	pitch = new_pitch

	if abs(applied) > 0.000001:
		_rotate_around_point(pivot, right_axis, applied)

func _rotate_around_point(point: Vector3, axis: Vector3, angle: float) -> void:
	# Rotate position around pivot
	var t := global_transform
	t.origin = point + (t.origin - point).rotated(axis, angle)
	# Rotate orientation around same axis
	t.basis = t.basis.rotated(axis, angle)
	global_transform = t

func _pick_pivot_under_mouse() -> Vector3:
	var vp := get_viewport()
	var mouse_pos := vp.get_mouse_position()

	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var end := origin + dir * max_raycast_dist

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	# Optional: if you have specific layers, set query.collision_mask here.
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit and hit.has("position"):
		return hit["position"]

	# Fallback: intersect with y=0 plane if ray hits nothing
	var plane := Plane(Vector3.UP, 0.0)
	var t: Variant = plane.intersects_ray(origin, dir)
	if t != null:
		return origin + dir * float(t)

	return global_transform.origin
