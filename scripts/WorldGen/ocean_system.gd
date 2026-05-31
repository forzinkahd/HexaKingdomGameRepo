extends Node
class_name OceanSystem


static func apply(surface_tiles: Array[Voxel], settings: GenerationSettings) -> void:
	for v in surface_tiles:
		v.surface_kind = Voxel.SurfaceKind.LAND
		v.is_water = false
		v.water = false
		v.is_sea = false
		v.sea_is_coast_ring = false
		v.water_body_id = -1

		v.has_coast_cap = false
		v.coast_mask = 0
		v.coast_variant = ""
		v.coast_yaw = 0.0

	for v in surface_tiles:
		if v.height_units <= settings.sea_level_units or _is_forced_ocean_edge(v, settings):
			_set_ocean(v)


static func _set_ocean(v: Voxel) -> void:
	v.surface_kind = Voxel.SurfaceKind.OCEAN
	v.is_water = true
	v.water = true
	v.is_sea = true
	v.water_body_id = 0


static func _is_forced_ocean_edge(v: Voxel, settings: GenerationSettings) -> bool:
	var radius := settings.radius
	var width := settings.forced_ocean_edge_width

	var q := v.grid_position_xz.x
	var r := v.grid_position_xz.y
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
