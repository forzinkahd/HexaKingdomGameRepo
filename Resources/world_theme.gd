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
