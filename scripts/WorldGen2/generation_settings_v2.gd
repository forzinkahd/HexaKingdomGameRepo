class_name GenerationSettingsV2
extends Resource

enum MapShape { HEXAGONAL }
enum OceanEdge { NONE, WEST, EAST, NORTH_WEST, NORTH_EAST, SOUTH_WEST, SOUTH_EAST }
enum OceanCorner { EAST, NORTH_EAST, NORTH_WEST, WEST, SOUTH_WEST, SOUTH_EAST }

@export_category("Map")
@export var map_shape: MapShape = MapShape.HEXAGONAL
@export_range(1, 96, 1) var radius: int = 18
@export var map_seed: int = 0
@export_range(0.25, 4.0, 0.05) var tile_size: float = 1.0
@export_range(0.1, 2.0, 0.05) var height_step: float = 0.5

@export_category("Noise")
@export var noise: FastNoiseLite = FastNoiseLite.new()
@export_range(0.005, 0.25, 0.005) var noise_scale: float = 0.045
@export_range(1, 64, 1) var max_height_units: int = 14
@export_range(0.25, 6.0, 0.05) var height_curve: float = 2.5

@export_category("Water")
@export_range(0, 16, 1) var sea_level_units: int = 1
@export var forced_ocean_edge: OceanEdge = OceanEdge.WEST
@export_range(0, 12, 1) var forced_ocean_edge_width: int = 3
@export_range(0, 24, 1) var coastal_plain_width: int = 4
@export_range(0, 8, 1) var coastal_plain_max_height_units: int = 2
@export var use_corner_ocean: bool = true
@export var ocean_corner: OceanCorner = OceanCorner.SOUTH_WEST
@export_range(0, 64, 1) var ocean_corner_radius: int = 6
@export_range(0, 32, 1) var ocean_transition_radius: int = 5

@export_category("Biomes")
@export_range(0, 64, 1) var plains_max_height_units: int = 3
@export_range(1, 64, 1) var hills_max_height_units: int = 8
@export_range(1, 64, 1) var mountain_min_height_units: int = 8
@export_range(0.0, 1.0, 0.01) var forest_noise_threshold: float = 0.72

@export_category("Rendering")
@export var render_padding: bool = true
@export_range(0, 64, 1) var max_padding_steps_to_render: int = 32
@export var spawn_debug_fallback_meshes: bool = true
