extends Node

# Dependencies
@export var settings : GenerationSettings
@export_category("Dependencies")
@export var object_placer : ObjectPlacer
@onready var interaction_tracker: Node3D = $"../Interaction_tracker"
@onready var chunks: Node3D = $"../../Chunks"

#UI
@onready var label: RichTextLabel = $"../../Control/VBoxContainer/RichTextLabel"


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

	var vg = VoxelGenerator.new()
	var new_chunk = vg.generate_chunk(voxels, interval)
	chunks.add_child(new_chunk)
	new_chunk.init_chunk()
	interval["Create Voxel Mesh -- "] = Time.get_ticks_msec()

	## Spawn villages and units
	if settings.spawn_villages_and_units:
		var placeable = get_placeable_voxels()
		object_placer.place_villages(placeable, settings.spacing)
		object_placer.create_starting_units(floori(settings.radius*0.5))
		interval["Spawn Villages -- "] = Time.get_ticks_msec()
	
	print_generation_results(starttime, interval)
	interaction_tracker.init()
	#Debugger.draw_voxel_dictionary(WorldMap.surface_layer)


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
		var voxel = WorldMap.surface_layer[key]
		if voxel.buffer or not voxel.placeable:
			continue
		placeable_tiles.append(voxel)
	print(str(placeable_tiles.size()) + " placeable tiles")
	return placeable_tiles
