extends CharacterBody3D
class_name Unit

@export_category("Data")
@export var unit_name: String = "Unit"
@export var max_health: int = 10
@export var ground_offset: float = 0.02

@onready var selection_ring: Node3D = get_node_or_null("SelectionRing") as Node3D

signal reached_target
signal control_mode_changed(new_mode: int)

enum ControlMode {AUTO, MANUAL}

var current_health: int = 10
var occupied_voxel: Voxel = null
var control_mode: int = ControlMode.AUTO

func _ready() -> void:
	current_health = max_health


func set_control_mode(m: int) -> void:
	if control_mode == m:
		return
	control_mode = m
	control_mode_changed.emit(control_mode)


func toggle_selected(on: bool) -> void:
	if selection_ring != null:
		selection_ring.visible = on


func place_on_voxel(v: Voxel) -> void:
	leave_tile()
	occupied_voxel = v
	if v != null:
		# if your Voxel supports this:
		if v.has_method("set_occupier"):
			v.call("set_occupier", self)
		elif v.get("occupier") != null or true:
			# only do this if Voxel actually has property 'occupier'
			# if it doesn't, remove this block
			v.occupier = self

		global_position = Vector3(v.world_position.x, _cap_y(v) + ground_offset, v.world_position.z)


func leave_tile() -> void:
	if occupied_voxel != null:
		# same note as above regarding occupier
		if occupied_voxel.get("occupier") == self:
			occupied_voxel.occupier = null
	occupied_voxel = null


func _cap_y(v: Voxel) -> float:
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5)


# ---- Command Surface (base defaults) ----
func can_receive_move_commands() -> bool:
	return false

func command_move_to_voxel(_v: Voxel) -> void:
	# override in subclasses that can move
	pass

func command_stop() -> void:
	# override if needed
	pass
