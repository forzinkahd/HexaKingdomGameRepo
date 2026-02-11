extends Node3D
class_name TreeCluster

@export var logs_scene: PackedScene
@export var logs_count: int = 3
@export var chop_time: float = 1.5

var is_depleted: bool = false
var is_being_chopped = false
var _shake_tween: Tween

func can_harvest() -> bool:
	return not is_depleted and not is_being_chopped

func start_shake() -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = get_tree().create_tween()
	_shake_tween.set_loops()
	# tiny rotation wobble for “gamefeel”
	_shake_tween.tween_property(self, "rotation:y", rotation.y + deg_to_rad(3.0), 0.08)
	_shake_tween.tween_property(self, "rotation:y", rotation.y - deg_to_rad(3.0), 0.08)

func stop_shake() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_shake_tween) and _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = null
	rotation.y = snapped(rotation.y, deg_to_rad(1.0))

func harvest_spawn_logs(spawn_root: Node3D) -> Array[Node3D]:
	if is_depleted:
		return []
	is_depleted = true
	stop_shake()

	var out: Array[Node3D] = []
	if logs_scene != null and spawn_root != null:
		for i in range(logs_count):
			var inst := logs_scene.instantiate() as Node3D
			# small random scatter around cluster center
			var off := Vector3(randf_range(-0.3,0.3), 0.0, randf_range(-0.3,0.3))
			inst.position = global_position + off
			spawn_root.add_child(inst)
			out.append(inst)

	# “poof away”
	queue_free()
	return out


func chop_and_harvest(resource_root: Node3D) -> Array[Node3D]:
	if is_depleted:
		return []
	is_being_chopped = true

	start_shake()
	await get_tree().create_timer(chop_time).timeout

	# if removed mid-chop, unlock and abort
	if not is_inside_tree():
		is_being_chopped = false
		return []

	stop_shake()
	var out := harvest_spawn_logs(resource_root)
	# harvest_spawn_logs() queue_free()'s the tree, so nothing after this should touch it
	return out
