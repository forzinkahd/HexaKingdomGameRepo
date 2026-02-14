class_name Voxel

var grid_position_xyz : Vector3i
var grid_position_xz : Vector2i
var world_position : Vector3

var type = VoxelData.voxel_type.GRASS
var noise : float = 0.0
var buffer : bool = false
var water : bool = false
var air_probability : float = 0
var surface_voxel := false

var neighbors = []
var placeable = true			# see voxel_generator.gd
var occupier : Unit
var collider

var height_units: int = 0	# column height in half-steps

# future proof building slot
var building_id: StringName = &""
var building_node: Node3D = null
var building_rotation_y: float = 0.0

# future proof NatResources slot
var resource_id: StringName = &""

func has_resource() -> bool:
	return resource_id != &""


func has_building() -> bool:
	return building_id != &""


func clear_resource() -> void:
	resource_id = &""


func can_place_building() -> bool:
	if not placeable:
		push_warning("not placeable here at %s building_id=%s" % [grid_position_xz, building_id])
		return false
	if has_building():
		push_warning("already has a building")
		return false
	if has_resource():
		push_warning("voxel has resource")
		return false
	if occupier != null:
		push_warning("occupier detected")
		return false
	#if water:
	#	return false
	return true
