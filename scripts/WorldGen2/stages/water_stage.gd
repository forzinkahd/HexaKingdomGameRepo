class_name WaterStage
extends RefCounted

func run(settings: GenerationSettingsV2, map: WorldMapData) -> void:
	for tile in map.tiles:
		_reset_water(tile)
		_apply_forced_edge(settings, tile)
		_apply_corner_ocean(settings, tile)

func _reset_water(tile: WorldTile) -> void:
	tile.water_kind = WorldTile.WaterKind.NONE
	tile.walkable = true
	tile.buildable = true
	tile.move_cost = 1.0

func _make_ocean(settings: GenerationSettingsV2, tile: WorldTile) -> void:
	tile.water_kind = WorldTile.WaterKind.OCEAN
	tile.height_units = settings.sea_level_units
	tile.walkable = false
	tile.buildable = false
	tile.move_cost = INF

func _apply_forced_edge(settings: GenerationSettingsV2, tile: WorldTile) -> void:
	if settings.forced_ocean_edge == GenerationSettingsV2.OceanEdge.NONE:
		return
	var dist := HexGrid.distance_to_edge(tile.coord, settings.radius, settings.forced_ocean_edge)
	if settings.forced_ocean_edge_width > 0 and dist < settings.forced_ocean_edge_width:
		_make_ocean(settings, tile)
		return
	if settings.coastal_plain_width > 0 and dist < settings.forced_ocean_edge_width + settings.coastal_plain_width:
		tile.height_units = min(tile.height_units, settings.coastal_plain_max_height_units)

func _apply_corner_ocean(settings: GenerationSettingsV2, tile: WorldTile) -> void:
	if not settings.use_corner_ocean:
		return
	var corner := HexGrid.corner_coord(settings.ocean_corner, settings.radius)
	var dist := HexGrid.axial_distance(tile.coord, corner)
	if settings.ocean_corner_radius > 0 and dist <= settings.ocean_corner_radius:
		_make_ocean(settings, tile)
		return
	var transition_end := settings.ocean_corner_radius + settings.ocean_transition_radius
	if settings.ocean_transition_radius > 0 and dist <= transition_end:
		var t := float(dist - settings.ocean_corner_radius) / float(max(settings.ocean_transition_radius, 1))
		var max_h := int(round(lerpf(float(settings.sea_level_units), float(settings.coastal_plain_max_height_units), t)))
		tile.height_units = min(tile.height_units, max_h)
