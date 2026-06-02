# scripts/World/world_tile.gd
class_name WorldTile
extends RefCounted

enum TerrainKind { GRASS, DIRT, STONE, SAND }
enum WaterKind { NONE, OCEAN, LAKE, RIVER }
enum BiomeKind { NONE, PLAINS, HILLS, MOUNTAIN, COAST, FOREST }

var xz: Vector2i
var world_position: Vector3
var noise: float = 0.0
var height_units: int = 0
var buffer: bool = false

var terrain_kind: TerrainKind = TerrainKind.GRASS
var water_kind: WaterKind = WaterKind.NONE
var biome_kind: BiomeKind = BiomeKind.NONE

var walkable: bool = true
var placeable: bool = true
var move_cost: float = 1.0

var coast_mask: int = 0
var coast_variant_index: int = -1
var coast_yaw: float = 0.0

var road_mask: int = 0
var river_mask: int = 0
