# scripts/WorldGen/config/biome_definition.gd
class_name BiomeDefinition
extends Resource

@export var id: StringName
@export var display_name: String

@export_range(0.0, 1.0) var min_moisture := 0.0
@export_range(0.0, 1.0) var max_moisture := 1.0
@export_range(0.0, 1.0) var min_temperature := 0.0
@export_range(0.0, 1.0) var max_temperature := 1.0
@export_range(0, 64) var min_height_units := 0
@export_range(0, 64) var max_height_units := 64

@export var terrain_kind: WorldTile.TerrainKind
@export var top_scene: PackedScene
@export var forest_density: float = 0.0
@export var resource_table: Resource


func run(ctx: GenerationContext, tiles: Array[WorldTile]) -> void:
	for tile in tiles:
		if tile.water_kind == WorldTile.WaterKind.OCEAN:
			tile.biome_kind = WorldTile.BiomeKind.COAST
			continue

		if tile.height_units >= ctx.settings.mountain_min_height_units_gen:
			tile.biome_kind = WorldTile.BiomeKind.MOUNTAIN
		elif _near_ocean(tile):
			tile.biome_kind = WorldTile.BiomeKind.COAST
		elif tile.height_units <= ctx.settings.plains_max_height_units:
			tile.biome_kind = WorldTile.BiomeKind.PLAINS
		else:
			tile.biome_kind = WorldTile.BiomeKind.HILLS
