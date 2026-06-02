extends Node
class_name WorldGenController

@export var settings: GenerationSettings
@export var world_theme: WorldTheme
@export var world_renderer: WorldRenderer
@export var placement_system: PlacementSystem
@export var road_tool: RoadTool
@export var object_placer: ObjectPlacer

@onready var interaction_tracker: Node3D = $"../Interaction_tracker"

var generation_result: GenerationResult

func _ready() -> void:
	_clear_runtime()
	call_deferred("_generate_world")

func _clear_runtime() -> void:
	WorldMap.clear_map()
	object_placer.clear_objects()

func _generate_world() -> void:
	var pipeline := WorldGenerationPipeline.new()
	generation_result = pipeline.generate(settings, world_theme)

	WorldMap.load_generation_result(generation_result)

	var render_result := world_renderer.render(generation_result, settings, world_theme)

	placement_system.configure_runtime(render_result.voxel_generator, render_result.chunk)
	interaction_tracker.init()

	if road_tool != null:
		road_tool.world_theme = world_theme
		road_tool.configure_runtime(render_result.voxel_generator, render_result.chunk)




"""extends Node

# Dependencies
@export var settings : GenerationSettings
@export_category("Dependencies")
@export var object_placer : ObjectPlacer
@onready var interaction_tracker: Node3D = $"../Interaction_tracker"
@onready var chunks: Node3D = $"../../Chunks"
@export var world_theme: WorldTheme
@export var overlay_visuals: OverlayVisuals		# mainly debug
@export var road_tool: RoadTool
@export var placement_system: PlacementSystem
#UI
@onready var label: RichTextLabel = $"../../Control/VBoxContainer/RichTextLabel"


var _vg: VoxelGenerator
var _chunk: Chunk


# --------------------------------------------------------------------------------------------
# WORLD GENERATION
# --------------------------------------------------------------------------------------------

## Starting point: Generate a random seed, create the tiles, place POI's
func _ready() -> void:
	WorldMap.clear_map()
	WorldMap.world_settings = settings
	init_seed()
	var children = chunks.get_children() + get_children()
	for c in children:
		c.free()
	object_placer.clear_objects()
	call_deferred("generate_world")


# Randomize if no seed has been set
func init_seed():
	if settings.map_seed == 0 or settings.map_seed == null:
		settings.noise.seed = randi()
	else:
		settings.noise.seed = settings.map_seed


## Start of world_generation, time each step
func generate_world():
	var starttime = Time.get_ticks_msec()
	var interval = {"Start of Generation!" : starttime}
	
	## Get all positions through the gridmapper
	var mapper = GridMapper.new()
	var voxels = mapper.calculate_map_positions()
	interval["Calculate Map Positions -- "] = Time.get_ticks_msec()

	_vg = VoxelGenerator.new()
	_vg.theme = world_theme
	_chunk = _vg.generate_chunk(voxels, interval)
	chunks.add_child(_chunk)
	_chunk.init_chunk()
	interval["Create Voxel Mesh -- "] = Time.get_ticks_msec()
	#print("World theme is: ", world_theme)
	
	print_generation_results(starttime, interval)
	placement_system.configure_runtime(_vg, _chunk)
	interaction_tracker.init()
	
	
	# Configure road tool runtime references
	if road_tool != null:
		road_tool.world_theme = world_theme
		road_tool.configure_runtime(_vg, _chunk)
	else:
		push_warning("world_gen: road_tool not assigned")


# ---------------------------------------------------------------------------------------------
# OG PROTOTYPE CODE
# ---------------------------------------------------------------------------------------------

## This mess of a function loops through the timing results of generate_world and prints them
func print_generation_results(start : float, dict : Dictionary):
	print("\n")
	label.text = ""
	var last_val = start
	var total = 0
	var unit = "ms"
	
	for key in dict:
		var val = dict[key]
		if val == start:
			continue
		var passed = val - last_val
		label.text += "[b]" + str(key) + "[/b]" + "[i]" + str(passed) + "ms\n" + "[/i]"
		last_val = val
		total += passed

	if total > 999: 
		unit = "s"
		total *= 0.001

	print("Total completion time: ", total, unit)
	label.text += "[b]Total completion time: [/b][i]" + str(total) + unit + "[/i]"


## Ignore buffer and ocean to return for object placer
func get_placeable_voxels() -> Array[Voxel]:
	var placeable_tiles : Array[Voxel] = []
	for key in WorldMap.surface_layer:
		var voxel: Voxel = WorldMap.surface_layer[key]
		if voxel.buffer or not voxel.placeable:
			continue
		placeable_tiles.append(voxel)
	print(str(placeable_tiles.size()) + " placeable tiles")
	return placeable_tiles"""
