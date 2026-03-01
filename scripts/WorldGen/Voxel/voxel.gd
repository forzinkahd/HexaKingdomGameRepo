class_name Voxel

enum Overlay { NONE, ROAD, RIVER }
var overlay: Overlay = Overlay.NONE
#var overlay_mask: int = 0


var grid_position_xyz : Vector3i
var grid_position_xz : Vector2i
var world_position : Vector3

var type = VoxelData.voxel_type.GRASS
var noise : float = 0.0
var buffer : bool = false
var water : bool = false
var air_probability : float = 0
var surface_voxel := false
var is_base_grass_cap: bool = false

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

# future proof decoration
var decoration_id: StringName = &""

# connectivity bitmasks, 6 bits (one per side)
# bit i == 1 means "connected on side i"
var road_mask: int = 0
var river_mask: int = 0

var road_variant_override: int = -1
var river_variant_override: int = -1
var road_yaw_override: float = 0.0
var has_road_yaw_override: bool = false

# movement / placement flags
var walkable: bool = true
var move_cost: float = 1.0  # later: road cheaper, mud higher, etc.


# coastal surface
var is_sea: bool = false
var coast_mask: int = 0

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


var road_preview: bool = false

func has_road_or_preview() -> bool:
	return overlay == Overlay.ROAD or road_preview


func has_road() -> bool:
	return overlay == Overlay.ROAD


func has_river() -> bool:
	return overlay == Overlay.RIVER


func can_place_road() -> bool:
	push_warning("see placement_rules.gd")
	if buffer: return false
	if has_building(): return false
	if has_resource(): return false
	if water: return false
	if overlay == Overlay.RIVER: return false
	return true


func can_place_river() -> bool:
	push_warning("see placement_rules.gd")
	if has_building(): return false
	if overlay == Overlay.ROAD: return false
	return true
