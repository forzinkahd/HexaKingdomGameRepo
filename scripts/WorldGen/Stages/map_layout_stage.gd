# scripts/WorldGen/stages/map_layout_stage.gd
class_name MapLayoutStage
extends RefCounted

func run(ctx: GenerationContext) -> Array[WorldTile]:
	var tiles: Array[WorldTile] = []

	for xz in MapShapeRules.positions_for(ctx.settings):
		var tile := WorldTile.new()
		tile.xz = xz
		tile.world_position = MapShapeRules.tile_to_world(xz, ctx.settings)
		tile.buffer = MapShapeRules.is_buffer(xz, ctx.settings)
		tiles.append(tile)

	return tiles
