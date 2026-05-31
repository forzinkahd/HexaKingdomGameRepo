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
	
	LakeSystem.apply_lakes(voxels, settings)
	
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
	var normalized_noise := _normalized_tile_noise(v.noise)
	var ocean_distance := _distance_from_forced_ocean_edge(v.grid_position_xz)

	if ocean_distance < settings.forced_ocean_edge_width:
		_set_ocean(v)
		return

	var h := _height_from_bands(v.grid_position_xz, normalized_noise, ocean_distance)

	var q: int = max(1, settings.terrace_quantum_units)
	h = int(round(float(h) / float(q))) * q
	h = clampi(h, settings.sea_level_units, settings.max_height_units)

	v.height_units = h

	if v.height_units <= settings.sea_level_units:
		_set_ocean(v)
	else:
		v.water = false
		v.is_sea = false
		v.water_kind = Voxel.WaterKind.NONE


func _normalized_tile_noise(raw_noise: float) -> float:
	var min_n: float = float(noise_range.x)
	var max_n: float = float(noise_range.y)
	var denom: float = max(0.000001, max_n - min_n)
	return clampf((raw_noise - min_n) / denom, 0.0, 1.0)


func _set_ocean(v: Voxel) -> void:
	v.height_units = settings.sea_level_units
	v.water = true
	v.is_sea = true
	v.water_kind = Voxel.WaterKind.OCEAN
	v.walkable = false
	v.move_cost = INF


func _height_from_bands(xz: Vector2i, n: float, ocean_distance: int) -> int:
	var edge_t := clampf(float(ocean_distance - settings.forced_ocean_edge_width) / float(max(1, settings.coastal_plain_width)), 0.0, 1.0)

	# Low coastal shelf: many buildable plains near ocean.
	if edge_t < 1.0:
		var plain_noise := pow(n, 1.8)
		return settings.sea_level_units + 1 + int(round(plain_noise * float(settings.plains_max_height_units - 1)))

	# Inland plains are still common.
	if n < 0.48:
		return settings.sea_level_units + randi_range(1, settings.plains_max_height_units)

	# Rolling hills.
	if n < settings.mountain_noise_threshold:
		var hill_t := inverse_lerp(0.48, settings.mountain_noise_threshold, n)
		return settings.plains_max_height_units + 1 + int(round(hill_t * float(settings.hills_max_height_units - settings.plains_max_height_units)))

	# Mountain peaks.
	var peak_t := inverse_lerp(settings.mountain_noise_threshold, 1.0, n)
	return settings.mountain_min_height_units_gen + int(round(peak_t * float(settings.cliff_boost_units)))


func _distance_from_forced_ocean_edge(xz: Vector2i) -> int:
	var q := xz.x
	var r := xz.y
	var s := -q - r
	var radius := settings.radius

	match settings.forced_ocean_edge:
		"WEST":
			return q + radius
		"EAST":
			return radius - q
		"NORTH_WEST":
			return r + radius
		"SOUTH_EAST":
			return radius - r
		"NORTH_EAST":
			return s + radius
		"SOUTH_WEST":
			return radius - s
		_:
			return q + radius



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
