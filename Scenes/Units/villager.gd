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


func _terrain_cap_y_at(world_xz: Vector3) -> float:
	var from := world_xz + Vector3(0.0, height_ray_start, 0.0)
	var to   := from + Vector3(0.0, -height_ray_length, 0.0)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = voxel_collision_mask

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return global_position.y

	# Determine which voxel that ray hit
	var collider := hit["collider"] as Object
	if collider == null:
		return global_position.y

	var chunk := collider
	while chunk != null and not (chunk is Chunk):
		chunk = chunk.get_parent()
	if chunk == null:
		return global_position.y

	var hd := HitData.new()
	hd.object = collider
	hd.point = hit["position"]
	hd.normal = hit["normal"]

	var v := (chunk as Chunk).voxel_at_point(hd)
	if v == null:
		return global_position.y

	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5) + ground_offset
