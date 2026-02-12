extends Node3D
class_name BuilderWorkshop

@export var train_cost_logs: int = 3
@export var spawn_point_path: NodePath = NodePath("SpawnPoint")

var _spawn_point: Node3D

func _ready() -> void:
	_spawn_point = get_node_or_null(spawn_point_path) as Node3D
	add_to_group("buildings")
	add_to_group("workshop")


func can_train_builder() -> bool:
	return WorldMap.wood_logs >= train_cost_logs


func train_builder(unit_manager: UnitManager) -> Builder:
	if unit_manager == null:
		return null
	if not can_train_builder():
		return null
	
	WorldMap.wood_logs -= train_cost_logs
	
	var spawn_pos := global_position
	if _spawn_point != null:
		spawn_pos = _spawn_point.global_position
	else:
		spawn_pos += Vector3(0.6, 0.0, 0.0)
	
	return unit_manager.spawn_builder_at_world_pos(spawn_pos)
