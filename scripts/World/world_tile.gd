class_name WorldTile
extends RefCounted

enum TerrainKind { GRASS, DIRT, STONE, SAND }
enum WaterKind { NONE, OCEAN, LAKE, RIVER }
enum BiomeKind { NONE, PLAINS, COAST, FOREST, HILLS, MOUNTAIN, OCEAN }

var coord: Vector2i = Vector2i.ZERO
var world_position: Vector3 = Vector3.ZERO
var noise_height: float = 0.0
var height_units: int = 0
var buffer: bool = false

var terrain_kind: TerrainKind = TerrainKind.GRASS
var water_kind: WaterKind = WaterKind.NONE
var biome_kind: BiomeKind = BiomeKind.NONE

var coast_mask: int = 0
var coast_variant_index: int = -1
var coast_yaw: float = 0.0


var walkable: bool = true
var buildable: bool = true
var move_cost: float = 1.0

var building_id: StringName = &""
var resource_id: StringName = &""
var unit_id: StringName = &""

func is_water() -> bool:
	return water_kind != WaterKind.NONE

func is_ocean() -> bool:
	return water_kind == WaterKind.OCEAN

func is_land() -> bool:
	return water_kind == WaterKind.NONE

func can_place_building() -> bool:
	return buildable and not is_water() and building_id == &"" and resource_id == &"" and unit_id == &""
