# scripts/WorldGen/pipeline/generation_result.gd
class_name GenerationResult
extends RefCounted

var surface_tiles: Array[WorldTile] = []
var tiles_by_xz: Dictionary[Vector2i, WorldTile] = {}
var tiles_by_xyz: Dictionary[Vector3i, Voxel] = {}

static func from_tiles(tiles: Array[WorldTile]) -> GenerationResult:
	var result := GenerationResult.new()
	result.surface_tiles = tiles
	for tile in tiles:
		result.tiles_by_xz[tile.xz] = tile
	return result
