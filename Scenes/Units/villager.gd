extends CharacterBody3D
class_name Villager

signal reached_target

@export var move_speed: float = 3.0
@export var arrive_distance: float = 0.25
@export var height_ray_start: float = 10.0     # start ray above villager
@export var height_ray_length: float = 30.0    # how far down we check
@export var height_lerp_speed: float = 14.0    # how fast y follows ground
@export var ground_offset: float = 0.02        # tiny lift to avoid z-fighting
@export var voxel_collision_mask: int = 1      # set this to your voxels' physics layer mask
@export var carry_capacity: int = 5
@export var pickup_time: float = 0.5


var occupied_voxel: Voxel
var carrying_logs: int = 0

var _target_pos: Vector3
var _has_target: bool = false
var _moving: bool = false
var is_busy: bool = false

func place_on_voxel(v: Voxel) -> void:
	occupied_voxel = v
	global_position = Vector3(v.world_position.x, _cap_y(v), v.world_position.z)

func move_to_world(pos: Vector3) -> void:
	_target_pos = pos
	_has_target = true
	_moving = true

func await_reach_target() -> void:
	if not _moving:
		return
	await reached_target





func _physics_process(delta: float) -> void:
	# Always follow terrain Y (even while idle, looks nicer)
	var desired_y := _terrain_cap_y_at(global_position)
	global_position.y = lerp(global_position.y, desired_y, clamp(delta * height_lerp_speed, 0.0, 1.0))

	if not _has_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var to := _target_pos - global_position
	to.y = 0.0
	var dist := to.length()

	if dist <= arrive_distance:
		_has_target = false
		_moving = false
		velocity = Vector3.ZERO
		move_and_slide()
		reached_target.emit()
		return

	var dir: Vector3 = to / max(dist, 0.0001)
	velocity = dir * move_speed
	move_and_slide()


func _cap_y(v: Voxel) -> float:
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5)


func _terrain_cap_y_at(world_pos: Vector3) -> float:
	var key: Vector2i
	if WorldMap.is_map_staggered:
		key = _pick_offset_hex_xz(world_pos)
	else:
		key = _pick_axial_hex_xz(world_pos)

	var v: Voxel = WorldMap.surface_layer.get(key)
	if v == null:
		return global_position.y

	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5) + ground_offset


func _pick_axial_hex_xz(p: Vector3) -> Vector2i:
	var size: float = WorldMap.world_settings.voxel_size
	var sqrt3: float = sqrt(3.0)

	var px: float = p.x / size
	var pz: float = p.z / size

	var qf: float = (2.0 / 3.0) * px
	var rf: float = (-1.0 / 3.0) * px + (1.0 / sqrt3) * pz

	var xf: float = qf
	var zf: float = rf
	var yf: float = -xf - zf

	var rx: int = int(round(xf))
	var ry: int = int(round(yf))
	var rz: int = int(round(zf))

	var x_diff: float = abs(rx - xf)
	var y_diff: float = abs(ry - yf)
	var z_diff: float = abs(rz - zf)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector2i(rx, rz)


func _pick_offset_hex_xz(p: Vector3) -> Vector2i:
	var size: float = WorldMap.world_settings.voxel_size
	var sqrt3: float = sqrt(3.0)

	var col_f: float = (2.0 / 3.0) * (p.x / size)
	var col: int = int(round(col_f))

	var parity: int = ((col % 2) + 2) % 2
	var row_f: float = (p.z / (sqrt3 * size)) - float(parity) * 0.5
	var row: int = int(round(row_f))

	return Vector2i(col, row)


func can_carry_more() -> bool:
	return carrying_logs < carry_capacity


func pickup_log(log: LogPickup) -> bool:
	if log == null or not is_instance_valid(log):
		return false
	if not can_carry_more():
		return false
	carrying_logs += log.amount
	log.queue_free()
	return true
