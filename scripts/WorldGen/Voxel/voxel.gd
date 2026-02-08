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
var placeable = true
var occupier : Unit
var collider

var height_units: int = 0	# column height in half-steps

var has_town_center: bool = false
var town_center_rotation_y: float = 0.0
