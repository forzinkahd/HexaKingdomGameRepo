class_name PlacementRulesV2
extends RefCounted

class PlacementResult:
	var allowed: bool = false
	var reason: String = ""

	static func ok() -> PlacementResult:
		var result := PlacementResult.new()
		result.allowed = true
		result.reason = "OK"
		return result

	static func fail(message: String) -> PlacementResult:
		var result := PlacementResult.new()
		result.allowed = false
		result.reason = message
		return result


static func can_place(tile: WorldTile, definition: BuildingDefinition, occupied_coords: Dictionary) -> PlacementResult:
	if tile == null:
		return PlacementResult.fail("No tile selected")

	if definition == null:
		return PlacementResult.fail("No building selected")

	if occupied_coords.has(tile.coord):
		return PlacementResult.fail("Tile already occupied")

	if not tile.buildable:
		return PlacementResult.fail("Tile is not buildable")

	if tile.water_kind != WorldTile.WaterKind.NONE and not definition.allow_water:
		return PlacementResult.fail("Cannot build on water")

	if tile.coast_mask != 0 and not definition.allow_coast:
		return PlacementResult.fail("Cannot build on coast")

	match tile.biome_kind:
		WorldTile.BiomeKind.FOREST:
			if not definition.allow_forest:
				return PlacementResult.fail("Cannot build in forest")
		WorldTile.BiomeKind.HILLS:
			if not definition.allow_hills:
				return PlacementResult.fail("Cannot build on hills")
		WorldTile.BiomeKind.MOUNTAIN:
			if not definition.allow_mountain:
				return PlacementResult.fail("Cannot build on mountain")

	return PlacementResult.ok()
