extends Node3D
class_name ConstructionSite

signal finished(site: ConstructionSite)

@export var build_time: float = 6.0
@export var log_cost: int = 0

@onready var building_stage_a: Node3D = $Visual/building_stage_A2
@onready var building_stage_b: Node3D = $Visual/building_stage_B2
@onready var building_stage_c: Node3D = $Visual/building_stage_C2

var progress: float = 0.0
var voxel: Voxel
var building_id: StringName = &""
var rotation_y: float = 0.0

var _is_building: bool = false
var _stage: int = 1
var build_stages: int

func start(req_stages: int) -> void:
	_is_building = true
	build_stages = req_stages
	building_stage_a.visible = true
	building_stage_b.visible = false
	building_stage_c.visible = false


func stop() -> void:
	_is_building = false


func is_complete() -> bool:
	return progress >= 1.0


func add_progress(seconds: float) -> void:
	if not _is_building:
		return
	if build_time <= 0.0:
		progress = 1.0
	else:
		progress = clamp(progress + (seconds / build_time), 0.0, 1.0)
	
	#_apply_visual_feedback()
	
	match _stage:
		1:
			building_stage_a.visible = true
			building_stage_b.visible = false
			building_stage_c.visible = false
		2:
			building_stage_a.visible = false
			building_stage_b.visible = true
			building_stage_c.visible = false
		3:
			building_stage_a.visible = false
			building_stage_b.visible = false
			building_stage_c.visible = true
		_:
			print("building stage into failsafe")
			building_stage_a.visible = false
			building_stage_b.visible = false
			building_stage_c.visible = true
	
	if progress >= 1.0:
		_is_building = false
		# maybe implement hide all right here
		finished.emit(self)
	
	if progress > float(_stage) / float(build_stages) and _is_building:
		_stage += 1
