class_name ResourceNodeDefinitionV2
extends Resource

enum ResourceNodeKind {
	FOREST,
	STONE_DEPOSIT,
	FERTILE_SOIL,
	GOLD_VEIN,
	GENERIC
}

@export var id: StringName = &"resource_node"
@export var display_name: String = "Resource Node"
@export var kind: ResourceNodeKind = ResourceNodeKind.GENERIC
@export var scene: PackedScene

@export_group("Generation")
@export_range(0.0, 1.0) var spawn_chance: float = 0.1

# Leave empty to allow all land biomes.
# WorldTile.BiomeKind:
# PLAINS = 1, COAST = 2, FOREST = 3, HILLS = 4, MOUNTAIN = 5
@export var allowed_biomes: Array[int] = []

@export var allow_water: bool = false
@export var allow_coast: bool = true
@export_range(0, 64) var min_height_units: int = 0
@export_range(0, 64) var max_height_units: int = 64

@export_group("Production Bonus")
@export var affected_resource: BuildingDefinition.ProducedResource = BuildingDefinition.ProducedResource.NONE
@export_range(0.0, 10.0) var on_tile_multiplier: float = 1.5
@export_range(0.0, 10.0) var nearby_multiplier: float = 1.2
@export_range(0, 8) var nearby_radius: int = 1


func allows_tile(tile: WorldTile) -> bool:
	if tile == null:
		return false

	if tile.water_kind != WorldTile.WaterKind.NONE and not allow_water:
		return false

	if tile.coast_mask != 0 and not allow_coast:
		return false

	if tile.height_units < min_height_units or tile.height_units > max_height_units:
		return false

	if not allowed_biomes.is_empty() and not allowed_biomes.has(tile.biome_kind):
		return false

	return true


func bonus_summary() -> String:
	if affected_resource == BuildingDefinition.ProducedResource.NONE:
		return "No production bonus"

	return "%s x%.2f on tile, x%.2f within %d" % [
		BuildingDefinition.resource_name(affected_resource),
		on_tile_multiplier,
		nearby_multiplier,
		nearby_radius
	]


static func kind_name(value: int) -> String:
	match value:
		ResourceNodeKind.FOREST:
			return "Forest"
		ResourceNodeKind.STONE_DEPOSIT:
			return "Stone Deposit"
		ResourceNodeKind.FERTILE_SOIL:
			return "Fertile Soil"
		ResourceNodeKind.GOLD_VEIN:
			return "Gold Vein"
		ResourceNodeKind.GENERIC:
			return "Generic"
		_:
			return "Unknown"
