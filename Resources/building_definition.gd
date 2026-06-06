extends Resource
class_name BuildingDefinitionOld

# DEPRECATED

@export var id: StringName
@export var scene: PackedScene
@export var unique: bool = false


@export var requires_construction: bool = true
@export var build_time: float = 6.0
@export var progress_stages: int = 1
@export var cost_logs: int = 0
