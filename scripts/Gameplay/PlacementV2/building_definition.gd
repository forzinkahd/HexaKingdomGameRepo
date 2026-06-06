class_name BuildingDefinition
extends Resource

enum BuildingCategory {
	HOUSING,
	PRODUCTION,
	STORAGE,
	MILITARY,
	UTILITY,
	DECORATION
}

enum ProducedResource {
	NONE,
	WOOD,
	STONE,
	FOOD,
	GOLD
}

@export var id: StringName = &"building"
@export var display_name: String = "Building"
@export var category: BuildingCategory = BuildingCategory.UTILITY
@export var scene: PackedScene

@export_group("Cost")
@export_range(0, 9999) var cost_wood: int = 0
@export_range(0, 9999) var cost_stone: int = 0
@export_range(0, 9999) var cost_food: int = 0
@export_range(0, 9999) var cost_gold: int = 0

@export_group("Production")
@export var produces_resource: ProducedResource = ProducedResource.NONE
@export_range(0, 9999) var production_amount: int = 0

# Kept for compatibility with older .tres files and UI text.
# WorldProductionV2 now owns the actual global tick interval per resource.
@export_range(0.1, 9999.0) var production_interval_seconds: float = 5.0

@export_group("Placement")
@export_range(0, 8) var footprint_radius: int = 0
@export var allow_water: bool = false
@export var allow_coast: bool = true

# Leave empty to allow all land biomes.
# Use WorldTile.BiomeKind values:
# PLAINS = 1, COAST = 2, FOREST = 3, HILLS = 4, MOUNTAIN = 5
@export var allowed_biomes: Array[int] = []

# Compatibility toggles for old resources made during the first placement pass.
# If allowed_biomes is empty, these are used as a readable fallback.
@export var allow_forest: bool = true
@export var allow_hills: bool = true
@export var allow_mountain: bool = false


func has_explicit_biome_rules() -> bool:
	return not allowed_biomes.is_empty()


func allows_biome(biome_kind: int) -> bool:
	if has_explicit_biome_rules():
		return allowed_biomes.has(biome_kind)

	match biome_kind:
		WorldTile.BiomeKind.FOREST:
			return allow_forest
		WorldTile.BiomeKind.HILLS:
			return allow_hills
		WorldTile.BiomeKind.MOUNTAIN:
			return allow_mountain
		_:
			return true


func cost_summary() -> String:
	var parts: Array[String] = []

	if cost_wood > 0:
		parts.append("Wood %d" % cost_wood)
	if cost_stone > 0:
		parts.append("Stone %d" % cost_stone)
	if cost_food > 0:
		parts.append("Food %d" % cost_food)
	if cost_gold > 0:
		parts.append("Gold %d" % cost_gold)

	if parts.is_empty():
		return "Free"

	return ", ".join(parts)


func production_summary() -> String:
	if produces_resource == ProducedResource.NONE or production_amount <= 0:
		return "None"

	return "%s +%d / global tick" % [
		resource_name(produces_resource),
		production_amount
	]


static func category_name(value: int) -> String:
	match value:
		BuildingCategory.HOUSING:
			return "Housing"
		BuildingCategory.PRODUCTION:
			return "Production"
		BuildingCategory.STORAGE:
			return "Storage"
		BuildingCategory.MILITARY:
			return "Military"
		BuildingCategory.UTILITY:
			return "Utility"
		BuildingCategory.DECORATION:
			return "Decoration"
		_:
			return "Unknown"


static func resource_name(value: int) -> String:
	match value:
		ProducedResource.NONE:
			return "None"
		ProducedResource.WOOD:
			return "Wood"
		ProducedResource.STONE:
			return "Stone"
		ProducedResource.FOOD:
			return "Food"
		ProducedResource.GOLD:
			return "Gold"
		_:
			return "Unknown"
