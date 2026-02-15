extends CharacterBody3D
class_name Unit

@export_category("Data")
@export var unit_name: String = "Unit"
@export var max_health: int = 10
@export var ground_offset: float = 0.02

var current_health: int = 10
var occupied_voxel: Voxel = null

func _ready() -> void:
	current_health = max_health

func place_on_voxel(v: Voxel) -> void:
	leave_tile()
	occupied_voxel = v
	if v != null:
		v.occupier = self
		global_position = Vector3(v.world_position.x, _cap_y(v) + ground_offset, v.world_position.z)

func leave_tile() -> void:
	if occupied_voxel != null:
		occupied_voxel.occupier = null
	occupied_voxel = null

func _cap_y(v: Voxel) -> float:
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5)
