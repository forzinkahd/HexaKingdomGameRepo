extends Node3D
class_name TreeCluster

@export var logs_scene: PackedScene
@export var logs_count: int = 3
@export var chop_time: float = 1.5
@export var visual: Node3D

var is_depleted: bool = false
var is_being_chopped: bool = false

var _shake_tween: Tween
var squash_amount: float = 0.14
var squash_time: float = 0.09
var squash_y_bias: float = 0.65
var _base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	if visual != null:
		_base_scale = visual.scale


func can_harvest() -> bool:
	return not is_depleted and not is_being_chopped

func start_shake() -> void:
	if visual == null:
		return
	
	if _shake_tween != null:
		_shake_tween.kill()
	
	visual.scale = _base_scale
	
	var y_down := 1.0 - squash_amount * squash_y_bias
	var xz_up := 1.0 + squash_amount
	
	var squish := Vector3(_base_scale.x * xz_up, _base_scale.y * y_down, _base_scale.z * xz_up)
	var relax := _base_scale
	
	_shake_tween = get_tree().create_tween()
	_shake_tween.set_loops()

	# Squish -> relax loop (use sine for organic feel)
	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.set_ease(Tween.EASE_IN_OUT)

	_shake_tween.tween_property(visual, "scale", squish, squash_time)
	_shake_tween.tween_property(visual, "scale", relax, squash_time)
	
	"""if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = get_tree().create_tween()
	_shake_tween.set_loops()
	# tiny rotation wobble for “gamefeel”
	_shake_tween.tween_property(self, "rotation:y", rotation.y + deg_to_rad(3.0), 0.08)
	_shake_tween.tween_property(self, "rotation:y", rotation.y - deg_to_rad(3.0), 0.08)"""

func stop_shake() -> void:
	if not is_inside_tree():
		return
	if visual == null:
		return

	if _shake_tween != null:
		_shake_tween.kill()
		_shake_tween = null

	# Snap back cleanly
	visual.scale = _base_scale


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

		# represent the whole cluster as one pickup
		inst.amount = logs_count

		spawn_root.add_child(inst)

		# place at cluster center (tiny random offset is fine)
		var off := Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.25, 0.25))
		inst.global_position = Vector3(global_position.x + off.x, spawn_y + 0.08, global_position.z + off.z)

		out.append(inst)

	queue_free()
	return out



func chop_and_harvest(resource_root: Node3D, spawn_y: float) -> Array[LogPickup]:
	if is_depleted:
		return []

	# allow TaskManager to be the “owner” of is_being_chopped
	start_shake()
	await get_tree().create_timer(chop_time).timeout

	if not is_inside_tree():
		is_being_chopped = false # release claim if cancelled
		stop_shake()
		return []

	stop_shake()
	return harvest_spawn_logs(resource_root, spawn_y)
