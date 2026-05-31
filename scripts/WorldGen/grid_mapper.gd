extends Object
class_name GridMapper

var settings : GenerationSettings
var noise_range := Vector2(99999, -99999) 

## Main entry point, Get all positions to spawn tiles on
func calculate_map_positions() -> Array[Voxel]:
	var voxels : Array[Voxel]
	settings = WorldMap.world_settings

	## Diamond and Circle also use the rectangular bounds. They carve our their shape from that rectangle
	## using their individual shape filters 
	var stagger : bool
	match settings.map_shape:
		0:
			stagger = false
			voxels = generate_map(hexagonal_bounds(), stagger, hexagonal_buffer_filter)
		1:
			stagger = true
			voxels = generate_map(rectangle_bounds(), stagger, rectangular_buffer_filter)
		2:
			stagger = true
			voxels = generate_map(rectangle_bounds(), stagger, diamond_buffer_filter, diamond_shape_filter)
		3:
			stagger = true
			voxels = generate_map(rectangle_bounds(), stagger, circular_buffer_filter, circle_shape_filter)
	
	for v in voxels:
		assign_height_units(v)
	
	print("Created ", voxels.size(), " positions")
	print("Noise Range: ", noise_range)
	WorldMap.noise_range = noise_range
	WorldMap.is_map_staggered = stagger
	return voxels


func generate_map(bounds: Callable, stagger: bool, buffer_filter: Callable, shape_filter: Callable = Callable()) -> Array[Voxel]:
	var voxel_array: Array[Voxel] = []
	for c in bounds.call():
		for r in bounds.call(c):
			if shape_filter and not shape_filter.call(c, r):
				continue

			var v := Voxel.new()
			v.grid_position_xyz = Vector3i(c, 0, r)
			v.grid_position_xz = Vector2i(c, r)

			# World position is BASE position (y=0)
			v.world_position = tile_to_world(Vector3(c, 0, r), stagger)

			# Noise computed from xz at base
			v.noise = noise_at_tile(v.world_position, settings.noise)

			if buffer_filter.call(c, r, settings.radius - settings.map_edge_buffer):
				v.buffer = true

			voxel_array.append(v)

	return voxel_array


func generate_voxel(pos, stagger) -> Voxel:
	var new = Voxel.new()
	new.world_position = tile_to_world(pos, stagger)
	new.grid_position_xyz = Vector3i(pos.x, pos.y, pos.z)
	new.grid_position_xz = Vector2i(pos.x, pos.z)
	return new


## Apply ocean noise, hills noise and find buffer tiles
func modify_voxel(voxel : Voxel, buffer_filter):
	var c = voxel.grid_position_xz.x
	var r = voxel.grid_position_xz.y
	voxel.noise = noise_at_tile(voxel.world_position, settings.noise)
	
	if buffer_filter.call(c, r, settings.radius - settings.map_edge_buffer):
		voxel.buffer = true


func tile_to_world(pos, stagger: bool) -> Vector3:
	var SQRT3 = sqrt(3)
	var x: float = 3.0 / 2.0 * pos.x  # Horizontal spacing
	var z: float
	if stagger:
		z = pos.z * SQRT3 + ((int(pos.x) % 2 + 2) % 2) * (SQRT3 / 2)
	else:
		z = (pos.z * SQRT3 + (int(pos.x) * SQRT3 / 2))
	return Vector3(x * settings.voxel_size, pos.y * settings.voxel_height, z * settings.voxel_size)


# Get noise at position of tile
func noise_at_tile(pos : Vector3, texture : FastNoiseLite) -> float:
	var value : float = texture.get_noise_3dv(pos) + randf_range(-settings.variance, settings.variance) 
	#var normalized_value = (value + 1.0) * 0.5
	
	if value < noise_range.x:
		noise_range.x = value
	elif value > noise_range.y:
		noise_range.y = value
		
	return value


func assign_height_units(v: Voxel) -> void:
	# normalize noise [-1..1-ish] to [0..1]
	var n: float = float(v.noise)
	var min_n: float = float(noise_range.x)
	var max_n: float = float(noise_range.y)
	
	var denom: float = max(0.000001, max_n - min_n)
	
	var t: float = clampf((n - min_n) / denom, 0.0, 1.0)
	t = pow(t, settings.height_curve)						# >1 -> more lowlands, sharper peaks; <1 -> more highlands
	if t > settings.cliff_threshold:
		v.height_units = min(settings.max_height_units, v.height_units + settings.cliff_boost_units)

	# map to integer half-steps
	v.height_units = int(round(t * float(settings.max_height_units)))

	# quantize into bigger steps (cliffs/terraces)
	var q: int = max(1, settings.terrace_quantum_units)
	v.height_units = int(round(float(v.height_units) / float(q))) * q

	# optional: keep buffer flatter / lower
	if v.buffer:
		v.height_units = min(v.height_units, 2)



### Bounds
### # Specific bounds functions for each shape

func hexagonal_bounds() -> Callable:
	return func(col = null):
		if col == null:
			return range(-settings.radius, settings.radius + 1)
		else:
			return range(max(-settings.radius, -col - settings.radius), min(settings.radius, -col + settings.radius) + 1)


func rectangle_bounds() -> Callable:
	return func(_col = null):
		return range(-settings.radius, settings.radius + 1)


### Filters
### # Filters positions to keep only tiles inside a shape

func circle_shape_filter(col: int, row: int) -> bool:
	var dist = sqrt(col * col + row * row)
	return dist < settings.radius


func diamond_shape_filter(col: int, row: int) -> bool:
	var adjusted_row = row
	if col % 2 != 0:
		adjusted_row += 0.5 
	return abs(adjusted_row) + abs(col) < settings.radius


### Buffer-filters!
### Filter out buffer tiles

func hexagonal_buffer_filter(col: int, row: int, limit: int) -> bool:
	return abs(col + row) > limit or abs(col) > limit or abs(row) > limit


func rectangular_buffer_filter(col: int, row: int, limit: int) -> bool:
	return abs(col) > limit or abs(row) > limit


func diamond_buffer_filter(col: int, row: int, limit: int) -> bool:
	return abs(row) + abs(col) >= limit


func circular_buffer_filter(col: int, row: int, limit: int) -> bool:
	return col * col + row * row > limit * limit


"""static func height_units_for_tile(xz: Vector2i, settings: GenerationSettings) -> int:
	if _is_forced_ocean_edge_xz(xz, settings):
		return settings.sea_level_units

	var n := settings.noise.get_noise_2d(float(xz.x), float(xz.y))
	n = (n + 1.0) * 0.5

	var q := xz.x
	var r := xz.y
	var s := -q - r
	var dist_from_center := float(max(abs(q), abs(r), abs(s))) / float(settings.radius)

	var continental := clampf((1.0 - dist_from_center) * 0.65 + n * 0.35, 0.0, 1.0)

	if continental < 0.20:
		return 0

	# Plains: first and second half-step above ocean.
	if continental < 0.55:
		return 1 if n < 0.65 else 2

	# Rolling hills.
	if continental < 0.86:
		return 3 + int(floor(n * 5.0))

	# Mountain peaks.
	if n > settings.cliff_threshold:
		return settings.mountain_min_height_units_gen + int(floor(n * float(settings.cliff_boost_units)))

	return settings.hills_max_height_units"""


func _height_units_for_tile(xz: Vector2i) -> int:
	if _is_forced_ocean_edge_xz(xz):
		return settings.sea_level_units

	var n := settings.noise.get_noise_2d(float(xz.x), float(xz.y))
	n = (n + 1.0) * 0.5

	var q := xz.x
	var r := xz.y
	var s := -q - r
	var dist_from_center := float(max(abs(q), abs(r), abs(s))) / float(settings.radius)

	var continental := clampf((1.0 - dist_from_center) * 0.65 + n * 0.35, 0.0, 1.0)

	if continental < 0.20:
		return settings.sea_level_units

	if continental < 0.55:
		return settings.sea_level_units + (1 if n < 0.65 else 2)

	if continental < 0.86:
		return settings.sea_level_units + 3 + int(floor(n * 5.0))

	if n > settings.cliff_threshold:
		return settings.sea_level_units + settings.mountain_min_height_units_gen + int(floor(n * float(settings.cliff_boost_units)))

	return settings.sea_level_units + settings.hills_max_height_units


func _is_forced_ocean_edge_xz(xz: Vector2i) -> bool:
	var radius := settings.radius
	var width := settings.forced_ocean_edge_width

	var q := xz.x
	var r := xz.y
	var s := -q - r

	match settings.forced_ocean_edge:
		"east":
			return q >= radius - width
		"west":
			return q <= -radius + width
		"south_east":
			return r >= radius - width
		"north_west":
			return r <= -radius + width
		"north_east":
			return s >= radius - width
		"south_west":
			return s <= -radius + width
		_:
			return s <= -radius + width


"""static func _is_forced_ocean_edge_xz(xz: Vector2i, settings: GenerationSettings) -> bool:
	var radius := settings.radius
	var width := settings.forced_ocean_edge_width

	var q := xz.x
	var r := xz.y
	var s := -q - r

	match settings.forced_ocean_edge:
		"east":
			return q >= radius - width
		"west":
			return q <= -radius + width
		"south_east":
			return r >= radius - width
		"north_west":
			return r <= -radius + width
		"north_east":
			return s >= radius - width
		"south_west":
			return s <= -radius + width
		_:
			return s <= -radius + width"""
			
