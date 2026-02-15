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
	body.collision_layer = 1  # layer 1
	body.collision_mask = 1
	col.shape = shape
	add_child(body)
	body.add_child(col)


var voxels_by_xz: Dictionary = {} # Vector2i -> Voxel

func fill_pos_dict():
	voxel_layers.clear()
	voxels_by_xz.clear()
	for v: Voxel in voxels:
		voxels_by_xz[v.grid_position_xz] = v
		# you can keep voxel_layers if other systems still use it


func voxel_at_point(hd: HitData) -> Voxel:
	var p: Vector3 = _ray_hit_plane_at_hit_y(hd)
	p.x += 0.0001
	p.z += 0.0001
	
	var key: Vector2i = _pick_offset_hex_xz(p) if WorldMap.is_map_staggered else _pick_axial_hex_xz(p)
	
	# 1) collect candidates: guessed tile + 6 neighbors
	var candidates: Array[Voxel] = []
	var v0: Voxel = voxels_by_xz.get(key)
	if v0 != null:
		candidates.append(v0)
	
	# choose correct neighbor dirs based on parity (matches your WorldMap logic)
	var dirs := VoxelData.HEXAGONAL_NEIGHBOR_DIRECTIONS
	if WorldMap.is_map_staggered:
		dirs = VoxelData.NEIGHBOR_DIRECTIONS_EVEN if (key.x % 2 == 0) else VoxelData.NEIGHBOR_DIRECTIONS_ODD
	
	for d in dirs:
		var nk := Vector2i(key.x + int(d.x), key.y + int(d.y))
		var nv: Voxel = voxels_by_xz.get(nk)
		if nv != null:
			candidates.append(nv)
	
	# 2) pick the candidate whose center is closest to p.xz
	if not candidates.is_empty():
		var best: Voxel = candidates[0]
		var best_d := INF
		for c in candidates:
			var d2 := Vector2(c.world_position.x, c.world_position.z).distance_squared_to(Vector2(p.x, p.z))
			if d2 < best_d:
				best_d = d2
				best = c
		return best
	
	# fallback
	return _fallback_nearest_by_xz(p)


func _ray_hit_plane_at_hit_y(hd: HitData) -> Vector3:
	# Use the height of what we actually hit (top of voxel, cliff face, etc.)
	var plane_y := hd.point.y

	var dir_y := hd.ray_dir.y
	if abs(dir_y) < 0.00001:
		return hd.point

	var t := (plane_y - hd.ray_origin.y) / dir_y
	if t < 0.0:
		return hd.point

	return hd.ray_origin + hd.ray_dir * t


func _pick_axial_hex_xz(p: Vector3) -> Vector2i:
	var size: float = WorldMap.world_settings.voxel_size
	var sqrt3: float = sqrt(3.0)

	# Normalize to "hex space"
	var px: float = p.x / size
	var pz: float = p.z / size

	# Axial fractional coords (q,r)
	var qf: float = (2.0 / 3.0) * px
	var rf: float = (-1.0 / 3.0) * px + (1.0 / sqrt3) * pz

	# Convert to cube (x=q, z=r, y=-x-z) then cube-round
	var xf: float = qf
	var zf: float = rf
	var yf: float = -xf - zf

	var rx: int = int(round(xf))
	var ry: int = int(round(yf))
	var rz: int = int(round(zf))

	var x_diff: float = abs(rx - xf)
	var y_diff: float = abs(ry - yf)
	var z_diff: float = abs(rz - zf)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	# Axial (q=rx, r=rz) matches your (col,row) => Vector2i(x,z)
	return Vector2i(rx, rz)


func _pick_offset_hex_xz(p: Vector3) -> Vector2i:
	# This matches your stagger=true mapping:
	# x = 1.5 * col * size
	# z = sqrt3 * row * size + parity(col) * (sqrt3/2) * size
	var size: float = WorldMap.world_settings.voxel_size
	var sqrt3: float = sqrt(3.0)

	var col_f: float = (2.0 / 3.0) * (p.x / size)
	var col: int = int(round(col_f))

	var parity: int = ((col % 2) + 2) % 2
	var row_f: float = (p.z / (sqrt3 * size)) - float(parity) * 0.5
	var row: int = int(round(row_f))

	return Vector2i(col, row)


func _fallback_nearest_by_xz(p: Vector3) -> Voxel:
	var best: Voxel = null
	var best_d := INF
	for v: Voxel in voxels:
		var d := Vector2(v.world_position.x, v.world_position.z).distance_squared_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = v
	return best
