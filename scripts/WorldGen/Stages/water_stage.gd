# scripts/WorldGen/stages/water_stage.gd
class_name WaterStage
extends RefCounted

func run(ctx: GenerationContext, tiles: Array[WorldTile]) -> void:
	for tile in tiles:
		_apply_forced_edge_ocean(ctx, tile)

	if ctx.settings.use_corner_ocean:
		_apply_corner_ocean(ctx, tiles)

	for tile in tiles:
		_finalize_water_flags(ctx, tile)

func _set_ocean(ctx: GenerationContext, tile: WorldTile) -> void:
	tile.height_units = ctx.settings.sea_level_units
	tile.water_kind = WorldTile.WaterKind.OCEAN
	tile.walkable = false
	tile.placeable = false
	tile.move_cost = INF


func _apply_corner_ocean(voxels: Array[Voxel]) -> void:
	if not settings.use_corner_ocean:
		return

	var corner: Vector2i  = _corner_anchor(settings.ocean_corner)
	var core_r: int       = settings.ocean_corner_radius
	var fade_r: int       = settings.ocean_transition_radius
	var max_h:  int       = settings.ocean_transition_max_height_units

	for v in voxels:
		var dist: int = _hex_distance(v.grid_position_xz, corner)

		# ── Core ocean ──────────────────────────────────────────────────────
		# Integer hex distance gives a perfect hexagonal region.
		# Because the anchor is AT the map corner, only 3 of the 6 hex sides
		# are inside the map, so the coastline has exactly 3 straight edges.
		if dist <= core_r:
			_set_ocean(v)
			continue

		# ── Outside influence zone ──────────────────────────────────────────
		if dist >= core_r + fade_r:
			continue

		# ── Transition band ─────────────────────────────────────────────────
		# Smoothly raise the allowed height from sea level to max_h as we
		# move away from the core, giving a gentle coastal plain.
		var t := smoothstep(0.0, 1.0,
			inverse_lerp(float(core_r), float(core_r + fade_r), float(dist))
		)

		var allowed_h := settings.sea_level_units + int(round(lerp(0.0, float(max_h), t)))
		v.height_units = mini(v.height_units, allowed_h)

		if v.height_units <= settings.sea_level_units:
			_set_ocean(v)
		else:
			v.water      = false
			v.is_sea     = false
			v.water_kind = Voxel.WaterKind.NONE


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
