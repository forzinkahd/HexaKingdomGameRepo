class_name PlacementRulesV2
extends RefCounted

class PlacementResult:
	var valid: bool = false
	var reason: String = "No result"
	var footprint_coords: Array[Vector2i] = []

	static func ok(coords: Array[Vector2i] = []) -> PlacementResult:
		var result := PlacementResult.new()
		result.valid = true
		result.reason = "OK"
		result.footprint_coords = coords
		return result

	static func fail(message: String, coords: Array[Vector2i] = []) -> PlacementResult:
		var result := PlacementResult.new()
		result.valid = false
		result.reason = message
		result.footprint_coords = coords
		return result


static func validate(
	tile: WorldTile,
	definition: BuildingDefinition,
	occupancy: WorldOccupancyV2 = null,
	economy: WorldEconomyV2 = null,
	world_map: WorldMapData = null,
	registry: BuildingRegistryV2 = null,
	resource_map: WorldResourceMapV2 = null
) -> PlacementResult:
	if tile == null:
		return PlacementResult.fail("No tile selected")

	if definition == null:
		return PlacementResult.fail("No building selected")

	var footprint := HexFootprintV2.coords_in_radius(tile.coord, definition.footprint_radius)

	if registry != null:
		if not registry.is_unlocked(definition):
			return PlacementResult.fail(registry.unlock_reason(definition), footprint)

		if registry.is_unique_limit_reached(definition):
			return PlacementResult.fail(registry.unique_reason(definition), footprint)

	if resource_map != null:
		if not resource_map.requirements_met_for_building_on_tile(definition, tile):
			return PlacementResult.fail(resource_map.requirement_reason_for_tile(definition, tile), footprint)

	if economy != null and not economy.can_afford(definition):
		return PlacementResult.fail(economy.missing_cost_reason(definition), footprint)

	if occupancy != null:
		for coord in footprint:
			if occupancy.is_coord_occupied(coord):
				return PlacementResult.fail("Footprint overlaps occupied tile %s" % [str(coord)], footprint)

	if world_map != null:
		for coord in footprint:
			if not world_map.has_tile(coord):
				return PlacementResult.fail("Footprint outside map", footprint)

			var footprint_tile := world_map.get_tile(coord)
			var tile_result := _validate_single_tile(footprint_tile, definition)

			if not tile_result.valid:
				return PlacementResult.fail(
					"%s at %s" % [tile_result.reason, str(coord)],
					footprint
				)
	else:
		var single_tile_result := _validate_single_tile(tile, definition)
		if not single_tile_result.valid:
			return PlacementResult.fail(single_tile_result.reason, footprint)

	return PlacementResult.ok(footprint)


static func _validate_single_tile(tile: WorldTile, definition: BuildingDefinition) -> PlacementResult:
	if tile == null:
		return PlacementResult.fail("Missing tile")

	if not tile.buildable:
		return PlacementResult.fail("Tile is not buildable")

	if tile.water_kind != WorldTile.WaterKind.NONE and not definition.allow_water:
		return PlacementResult.fail("Cannot build on water")

	if tile.coast_mask != 0 and not definition.allow_coast:
		return PlacementResult.fail("Cannot build on coast")

	if not definition.allows_biome(tile.biome_kind):
		return PlacementResult.fail("Biome not allowed")

	return PlacementResult.ok()
