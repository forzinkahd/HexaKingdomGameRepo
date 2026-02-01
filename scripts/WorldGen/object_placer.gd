extends Node
class_name ObjectPlacer

@export var village : PackedScene
@export var proto_unit : PackedScene

## placeholder functionality for placing units onto the map
func create_starting_units(count : int):
	var safety_count = 0 #Add safety counter in case no valid tiles
	## Test pathfinder
	while count > 0 and safety_count < 50:
		var voxel: Voxel = null
		if WorldMap.surface_layer.size() > 0:
			var random_key = WorldMap.surface_layer.keys().pick_random()
			voxel = WorldMap.surface_layer[random_key]

		if voxel.occupier != null: #voxel.type == VoxelData.voxel_type.WATER or 
			safety_count += 1
			continue
			
		var unit : Unit = proto_unit.instantiate()
		add_child(unit)
		unit.place_unit(voxel)
		count -= 1


func place_villages(tiles : Array[Voxel], spacing : int):
	var tiles_copy = tiles.duplicate(true) #copy tiles and leave original unaffected
	var placed_positions = []
	var current_index = 0
	tiles_copy.shuffle()
	
	while current_index < tiles_copy.size():
		# Select random tile from array
		var candidate : Voxel = tiles_copy[current_index]
		current_index += 1
		
		if not candidate.placeable:
			continue
		var valid = true
		
		# check against previous villages
		for previous : Vector2 in placed_positions:
			var c_diff = abs(previous.x - candidate.grid_position_xyz.x)
			var r_diff = abs(previous.y - candidate.grid_position_xyz.y)
			var delta = abs((previous.x + previous.y) - (candidate.grid_position_xyz.x + candidate.grid_position_xyz.y))
			var ring_distance = max(c_diff, r_diff, delta)
			if ring_distance <= spacing:
				valid = false
				break
				
		if valid:
			placed_positions.append(Vector2(candidate.grid_position_xyz.x, candidate.grid_position_xyz.y))
			spawn_on_tile(candidate, village)
			for n in candidate.neighbors:
				n.placeable = false
	print("placed " + str(placed_positions.size()) + " in " + str(current_index) + " attempts")


# Spawn an object on a tile
func spawn_on_tile(voxel : Voxel, scene : PackedScene):
	if not voxel or not scene:
		push_warning("tile not found!")
		return

	var instance = scene.instantiate()
	add_child(instance)
	call_deferred("position_object", instance, voxel.world_position, 1)


func position_object(object : Node3D, target_location : Vector3, add_height : float = 0):
	object.position = target_location
	object.position.y += add_height

func clear_objects():
	var children = get_children()
	for c in children:
		c.free()
