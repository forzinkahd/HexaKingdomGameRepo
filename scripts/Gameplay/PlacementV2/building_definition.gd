class_name BuildingDefinition
extends Resource

@export var id: StringName = &"test_building"
@export var display_name: String = "Test Building"
@export var scene: PackedScene

@export var footprint_radius: int = 0
@export var allow_water: bool = false
@export var allow_coast: bool = true
@export var allow_forest: bool = true
@export var allow_hills: bool = true
@export var allow_mountain: bool = false

@export var y_offset: float = 0.12
@export var preview_y_offset: float = 0.18
