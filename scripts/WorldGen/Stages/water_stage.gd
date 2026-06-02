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
