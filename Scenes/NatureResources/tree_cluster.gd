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
