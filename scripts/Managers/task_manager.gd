extends Node
class_name TaskManager

@export var resources_root: Node3D
@export var town_center_drop_voxel_required: bool = true

var active_task: Dictionary = {}		# 1-task prototype


func has_task() -> bool:
	return not active_task.is_empty()


func clear_task() -> void:
	active_task.clear()


func get_task_type() -> StringName:
	return active_task.get("type", &"") as StringName


func get_treecluster() -> TreeCluster:
	return active_task.get("tree") as TreeCluster


func get_target_voxel() -> Voxel:
	return active_task.get("voxel") as Voxel


func create_chop_task(tree: TreeCluster, target_voxel: Voxel) -> bool:
	if tree == null or not is_instance_valid(tree):
		return false
	if target_voxel == null:
		return false
	if has_task():
		return false
	if not tree.can_harvest():
		return false

	# claim it here (optional but recommended)
	tree.is_being_chopped = true

	active_task = {
		"type": &"chop_tree",
		"tree": tree,
		"voxel": target_voxel
	}
	return true
