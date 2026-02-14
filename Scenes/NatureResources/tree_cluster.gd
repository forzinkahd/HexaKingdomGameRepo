extends Node3D
class_name TreeCluster

@export var logs_scene: PackedScene
@export var logs_count: int = 3
@export var chop_time: float = 1.5

@export var squish_y: float = 0.82                  # smaller = more squish
@export var squish_xz: float = 1.10                 # bigger = more bulge
@export var squish_in_time: float = 0.08
@export var squish_out_time: float = 0.30

@onready var _squish_target: Node3D = $Visual

var home_voxel: Voxel = null
var is_depleted: bool = false
var is_being_chopped: bool = false
var _shake_tween: Tween
var _base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	if _squish_target != null:
		_base_scale = _squish_target.scale

func can_harvest() -> bool:
	return not is_depleted and not is_being_chopped

func start_shake() -> void:
	if _squish_target == null:
		# fallback: do nothing instead of breaking
		return

	if _shake_tween != null and is_instance_valid(_shake_tween):
		_shake_tween.kill()

	_shake_tween = get_tree().create_tween()
	_shake_tween.set_loops() # infinite until stop_shake()

	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.set_ease(Tween.EASE_IN_OUT)

	var intensity := 1.0 + float(logs_count) * 0.01
	var squished := Vector3(_base_scale.x * squish_xz * intensity, _base_scale.y * squish_y / intensity, _base_scale.z * squish_xz * intensity)

	# squash -> rebound -> back to base
	_shake_tween.tween_property(_squish_target, "scale", squished, squish_in_time)
	_shake_tween.tween_property(_squish_target, "scale", _base_scale * 1.03, 0.06)
	_shake_tween.tween_property(_squish_target, "scale", _base_scale, squish_out_time)

func stop_shake() -> void:
	# don’t early-return if freed; just guard properly
	if _shake_tween != null and is_instance_valid(_shake_tween):
		_shake_tween.kill()
	_shake_tween = null

	if _squish_target != null and is_instance_valid(_squish_target):
		_squish_target.scale = _base_scale

func harvest_spawn_logs(spawn_root: Node3D, spawn_y: float) -> Array[LogPickup]:
	if is_depleted:
		return []
	is_depleted = true
	stop_shake()

	var out: Array[LogPickup] = []
	if logs_scene != null and spawn_root != null:
		var inst := logs_scene.instantiate() as LogPickup
		if inst == null:
			push_warning("logs_scene root must be LogPickup.")
			return []

		inst.amount = logs_count
		spawn_root.add_child(inst)

		var off := Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
		inst.global_position = Vector3(global_position.x + off.x, spawn_y + 0.08, global_position.z + off.z)
		out.append(inst)
	
	if home_voxel != null:
		home_voxel.clear_resource()
	
	queue_free()
	return out

func chop_and_harvest(resource_root: Node3D, spawn_y: float) -> Array[LogPickup]:
	if is_depleted:
		return []

	start_shake()
	await get_tree().create_timer(chop_time).timeout

	if not is_inside_tree():
		is_being_chopped = false
		stop_shake()
		return []

	stop_shake()
	return harvest_spawn_logs(resource_root, spawn_y)
