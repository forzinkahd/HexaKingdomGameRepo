extends Node

var map_as_dict : Dictionary[Vector3i, Voxel] = {}
var is_map_staggered = false
var world_settings : GenerationSettings
var noise_range : Vector2
var surface_layer: Dictionary[Vector2i, Voxel] = {}		# Overworking half steps

# protect unique buildings
var town_center_voxel: Voxel = null
var town_center_node: Node3D = null

var unique_buildings: Dictionary = {} # StringName -> Voxel

# Resource inventory
var wood_logs: int = 0

func has_town_center() -> bool:
	return town_center_voxel != null and is_instance_valid(town_center_node)


func has_unique_building(id: StringName) -> bool:
	return unique_buildings.has(id)


func register_unique_building(id: StringName, v: Voxel) -> void:
	unique_buildings[id] = v


## Construct a dictionary for our 2d top layer of voxels
func set_map(all_voxels, top_voxels):
	map_as_dict.clear()
	surface_layer.clear()
	
	for voxel : Voxel in all_voxels:
		map_as_dict[Vector3i(voxel.grid_position_xyz)] = voxel
	for t_voxel: Voxel in top_voxels:
		surface_layer[t_voxel.grid_position_xz] = t_voxel


func clear_map():
	map_as_dict.clear()


## Handy function for finding all neigbors of a voxel
func get_tile_neighbors_planar(voxel : Voxel) -> Array[Voxel]:
	var neighbors : Array[Voxel] = []
	var neighbor_positions = VoxelData.HEXAGONAL_NEIGHBOR_DIRECTIONS
	if is_map_staggered:
		if voxel.grid_position_xz.x % 2 == 0:
			neighbor_positions = VoxelData.NEIGHBOR_DIRECTIONS_EVEN
		else:
			neighbor_positions = VoxelData.NEIGHBOR_DIRECTIONS_ODD
			
	for direction in neighbor_positions:
		var neighbor_coords = Vector3i(
			voxel.grid_position_xz.x + int(direction.x), #x + dir
			 int(voxel.grid_position_xyz.y), # same y
			 voxel.grid_position_xz.y + int(direction.y)) #z + dir
			
		if neighbor_coords in map_as_dict:
			neighbors.append(map_as_dict[neighbor_coords])
	return neighbors


func get_tile_neighbors_surface(voxel: Voxel) -> Array[Voxel]:
	var neighbors: Array[Voxel] = []
	var neighbor_positions = VoxelData.HEXAGONAL_NEIGHBOR_DIRECTIONS

	if is_map_staggered:
		neighbor_positions = VoxelData.NEIGHBOR_DIRECTIONS_EVEN if voxel.grid_position_xz.x % 2 == 0 else VoxelData.NEIGHBOR_DIRECTIONS_ODD


	for direction in neighbor_positions:
		var nxz := Vector2i(
			voxel.grid_position_xz.x + int(direction.x),
			voxel.grid_position_xz.y + int(direction.y)
		)

		if surface_layer.has(nxz):
			neighbors.append(surface_layer[nxz])

	return neighbors
