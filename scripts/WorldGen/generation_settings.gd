extends Resource
class_name GenerationSettings

enum shape {HEXAGONAL, RECTANGULAR, DIAMOND, CIRCLE}

@export_category("Map")
@export var map_shape: shape = shape.HEXAGONAL
@export var map_seed: int
@export_range(0, 64, 1) var radius: int = 24
@export_range(1, 128, 1) var max_height: int = 16
@export var remove_overhang: bool = true
@export_range(0.0, 1.0, 0.01) var ground_to_air_ratio: float = 0.6
@export var flat_buffer: bool = false
@export var noise: FastNoiseLite
@export_range(0.0, 1.0) var variance: float = 0.0

@export_category("Biomes")
## Fraction of noise values that become plains (flat buildable land)
@export_range(0.0, 1.0, 0.01) var plains_threshold: float = 0.55
## Fraction of noise values that become hills (below this, above plains)
@export_range(0.0, 1.0, 0.01) var hills_threshold: float = 0.82
## Maximum height in half-steps for plains tiles
@export_range(1, 20, 1) var plains_max_height_units: int = 3
## Maximum height in half-steps for hills tiles
@export_range(1, 40, 1) var hills_max_height_units: int = 10

@export_category("Height")
@export_range(1, 256, 1) var max_height_units: int = 20
@export_range(1, 32, 1) var terrace_quantum_units: int = 1
## Controls sharpness of mountain peaks (higher = sharper)
@export_range(0.5, 6.0, 0.05) var height_curve: float = 2.0
@export_range(0.0, 1.0, 0.01) var cliff_threshold: float = 0.87
@export_range(0, 64, 1) var cliff_boost_units: int = 8

@export_category("Voxel")
@export_range(0.5, 10) var voxel_size: float = 1
@export_range(0.5, 10) var voxel_height: float = 1
@export_range(-1, 0, 1.0) var shading: int = -1
@export var material: Material
@export var draw_bottom: bool = false
@export var solid_first_layer: bool = true

@export_category("Ocean")
@export var sea_level_units: int = 0

@export_category("Port Face")
## Force one face of the hexagonal map to remain at sea level (future port gameplay)
@export var port_face_enabled: bool = true
## Which face of the hex map: 0=NE, 1=SE, 2=SW, 3=W, 4=NW, 5=E
@export_range(0, 5, 1) var port_face_direction: int = 1
## How many tile rows from the face to force low (creates a natural harbor bay)
@export_range(0, 10, 1) var port_face_depth: int = 3

@export_category("Lakes")
@export var lakes_enabled: bool = true
@export_range(0, 20, 1) var lake_count: int = 5
## Minimum tiles per lake (must be >= 7 for coast tiles to look good)
@export_range(4, 50, 1) var lake_min_size: int = 7
@export_range(7, 150, 1) var lake_max_size: int = 35

@export_category("Rivers")
@export var rivers_enabled: bool = true
## Minimum river length in tiles to place
@export_range(1, 20, 1) var river_min_length: int = 3

@export_category("Villages")
@export var map_edge_buffer: int = 1
@export_range(1, 99) var spacing: int = 4

@export_category("Legacy")
## Kept for backward compatibility
@export var terrace_steps: int = 0
@export_range(0.0, 1.0, 0.1) var noise_height_bias: float = 0.4
@export var use_half_steps: bool = true
