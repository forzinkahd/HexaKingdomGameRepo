extends Node

var debug_cubes : Array = []


func draw_cube(pos: Vector3):
	# Create a small cube at the neighbor's world position for debugging
	var cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	cube.mesh.size = Vector3(0.2, 2, 0.2)  # small cube
	cube.position = pos
	cube.position.y += 1
	cube.material_override = StandardMaterial3D.new()
	cube.material_override.albedo_color = Color(1, 0, 0)

	get_tree().current_scene.add_child(cube)
	debug_cubes.append(cube)


func draw_neighbors(voxel: Voxel):
	var neighbors: Array[Voxel] = WorldMap.get_tile_neighbors_planar(voxel)
	
	clear()
	#print("Found ", neighbors.size(), " neighbors for voxel ", voxel.grid_position_xyz)
	for n in neighbors:
		draw_cube(n.world_position)
		#print("Neighbor at: ", n.grid_position_xyz, " world: ", n.world_position)


func draw_positions(positions: Array[Vector3]):
	clear()
	for p in positions:
		draw_cube(p)


func draw_voxels(voxels: Array[Voxel]):
	clear()
	for v in voxels:
		draw_cube(v.world_position)


func draw_voxel_dictionary(voxels: Dictionary):
	clear()
	for k in voxels.values():
		draw_cube(k.world_position)


func clear():
	for c in debug_cubes:
		c.queue_free()
	debug_cubes.clear()
