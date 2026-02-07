extends MeshInstance3D
class_name Chunk

var voxels : Array[Voxel]
var voxel_layers: Dictionary[int, Array] = {}


func init_chunk():
	generate_collider()
	layers = 0				# hide chunk visuals but keep colliders
	add_to_group("voxels")
	fill_pos_dict()


func generate_collider():
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = mesh.create_trimesh_shape()
	col.shape = shape
	add_child(body)
	body.add_child(col)


func fill_pos_dict():
	for v: Voxel in voxels:
		var y = v.grid_position_xyz.y
		if not voxel_layers.has(y):
			voxel_layers[y] = []
			#print("Voxel layer: ", y)
		voxel_layers[y].append(v)


func voxel_at_point(hd: HitData) -> Voxel:
	# convert hit point to approx grid xz using nearest neighbor search
	# simplest: pick random surface voxel and greedy across planar neighbors (same as you do, but ignore y)
	var corrected_pos: Vector3 = hd.point

	# pick any voxel as start
	if voxels.is_empty():
		return null

	var current: Voxel = voxels.pick_random()
	var current_dist: float = Vector2(current.world_position.x, current.world_position.z).distance_to(
		Vector2(corrected_pos.x, corrected_pos.z)
	)

	var visited: Array[Voxel] = []

	while true:
		var found_better := false
		var neighbors: Array[Voxel] = WorldMap.get_tile_neighbors_surface(current) # NEW function
		for n in neighbors:
			if visited.has(n):
				continue
			var dist := Vector2(n.world_position.x, n.world_position.z).distance_to(
				Vector2(corrected_pos.x, corrected_pos.z)
			)
			if dist < current_dist:
				current = n
				current_dist = dist
				found_better = true

		visited.append(current)
		if not found_better:
			break

	return current
