extends Resource
class_name GenerationSettings

enum shape {HEXAGONAL, RECTANGULAR, DIAMOND, CIRCLE}

@export_category("Map")
@export var map_shape : shape = shape.HEXAGONAL
@export var map_seed : int
@export_range(0, 64, 1) var radius: int = 24
@export_range(1, 128, 1) var max_height: int = 16
@export_range(0, 8) var terrace_steps = 0
@export var remove_overhang = true
@export_range(0.0, 1.0, 0.1) var noise_height_bias : float = 0.4
@export_range(0.0, 1.0, 0.1) var ground_to_air_ratio : float = 0.6
@export var flat_buffer = false
#@export var debug : bool = false
@export var noise : FastNoiseLite
@export_range(0.0, 1.0) var variance = 0.0

@export_category("Height")
@export_range(1, 256, 1) var max_height_units: int = 15
@export_range(1, 32, 1) var terrace_quantum_units: int = 1	# 1=half step, 2=full step ...
@export_range(0.2, 6.0, 0.05) var height_curve: float = 3.0	# more extremes to form mountains
@export_range(0.0, 1.0, 0.01) var cliff_threshold: float = 0.82
@export_range(0, 64, 1) var cliff_boost_units: int = 10


@export_category("Voxel")
@export_range(0.5, 10) var voxel_size : float = 1 # Size scalar
@export_range(0.5, 10) var voxel_height : float = 1 #height of voxels
## -1 For flat-shading. 0 for smooth
@export_range(-1, 0, 1.0) var shading : int = -1
@export var material : Material
@export var draw_bottom = false
@export var solid_first_layer = true

@export_category("Villages")
@export var map_edge_buffer = 1
@export_range(1, 99) var spacing = 4

# Overworking half steps
@export_category("Half steps")
@export var use_half_steps: bool = true

# Ocean
@export_category("Ocean")
@export var sea_level_units: int = 0
