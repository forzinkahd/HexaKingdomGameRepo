extends Resource
class_name WorldTheme

# This script holds the various tiles for the terrain
# update packed scenes in .tres!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

@export_category("Top tiles")
@export var grass_top_scene: PackedScene
@export var stone_top_scene: PackedScene
@export var dirt_top_scene: PackedScene

@export_category("Bottom tiles")
@export var grass_bottom_scene: PackedScene
@export var stone_bottom_scene: PackedScene
@export var dirt_bottom_scene: PackedScene

@export_category("Padding tiles")
@export var grass_padding_scene: PackedScene
@export var padding_height_fraction: float = 0.5		# half step

@export_category("Mountains")
@export var mountain_scenes: Array[PackedScene] = []
@export var mountain_foundation_scene: PackedScene
@export var mountain_foundation_bottom_scene: PackedScene
@export var mountain_min_height_units: int = 10
@export_range(0.0, 1.0) var mountain_chance: float = 1.0

@export_category("Forests")
@export var tree_cluster_scenes: Array[PackedScene] = []
@export var forest_chance: float = 0.25
@export var forest_min_height_units: int = 1
@export var forest_max_height_units: int = 20
@export var forest_avoid_mountains: bool = true

@export_category("Overlays")
@export var road_variants: Array[PackedScene] = []
@export var river_variants: Array[PackedScene] = []


func road_scene(letter: String) -> PackedScene:
	var idx: int = VoxelData.ROAD_LETTER_TO_INDEX.get(letter, -1)
	if idx < 0 or idx >= road_variants.size():
		return null
	return road_variants[idx]


func river_scene(letter: String) -> PackedScene:
	var idx: int = VoxelData.RIVER_LETTER_TO_INDEX.get(letter, -1)
	if idx < 0 or idx >= river_variants.size():
		return null
	return river_variants[idx]
