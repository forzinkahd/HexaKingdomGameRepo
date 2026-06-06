extends Node
class_name WorldGenController

@export_category("WorldGen2")
@export var settings: Resource
@export var world_theme: WorldTheme
@export var render_on_ready: bool = true
@export var clear_existing_world: bool = true
@export var output_parent_path: NodePath = ^"../../Chunks"
@export var building_placement_v2: BuildingPlacementV2

var current_settings: GenerationSettingsV2
var current_map: WorldMapData
var current_world_root: Node3D

func _ready() -> void:
	if render_on_ready:
		call_deferred("generate_world")

func generate_world() -> void:
	current_settings = _settings_as_v2(settings)
	_clear_previous_world()

	current_map = WorldGeneratorV2.new().generate(current_settings)
	current_world_root = WorldRendererV2.new().render(current_map, current_settings, world_theme)
	
	if building_placement_v2 != null:
		building_placement_v2.configure_world_map(current_map)
	
	_get_output_parent().add_child(current_world_root)

	_print_generation_summary()

func regenerate() -> void:
	generate_world()

func get_placeable_tiles() -> Array[WorldTile]:
	if current_map == null:
		return []
	return current_map.placeable_tiles()

# Compatibility shim for old callers. The clean world model no longer returns Voxel objects.
func get_placeable_voxels() -> Array:
	push_warning("WorldGen2 uses WorldTile, not Voxel. Call get_placeable_tiles() instead.")
	return []

func _get_output_parent() -> Node:
	if output_parent_path != NodePath() and has_node(output_parent_path):
		return get_node(output_parent_path)
	return self

func _clear_previous_world() -> void:
	if not clear_existing_world:
		return
	if current_world_root != null and is_instance_valid(current_world_root):
		current_world_root.queue_free()
		current_world_root = null
	var parent := _get_output_parent()
	for child in parent.get_children():
		if child.name == "WorldGen2Root":
			child.queue_free()

func _settings_as_v2(source: Resource) -> GenerationSettingsV2:
	if source is GenerationSettingsV2:
		return source as GenerationSettingsV2

	var result := GenerationSettingsV2.new()
	if source == null:
		return result

	_copy_int_if_present(source, result, "map_seed")
	_copy_int_if_present(source, result, "radius")
	_copy_int_if_present(source, result, "max_height_units")
	_copy_int_if_present(source, result, "sea_level_units")
	_copy_int_if_present(source, result, "forced_ocean_edge_width")
	_copy_int_if_present(source, result, "coastal_plain_width")
	_copy_int_if_present(source, result, "ocean_corner_radius")
	_copy_int_if_present(source, result, "ocean_transition_radius")
	_copy_int_if_present(source, result, "plains_max_height_units")
	_copy_int_if_present(source, result, "hills_max_height_units")
	_copy_int_if_present(source, result, "mountain_min_height_units_gen", "mountain_min_height_units")
	_copy_float_if_present(source, result, "voxel_size", "tile_size")
	_copy_float_if_present(source, result, "voxel_height", "height_step")
	_copy_float_if_present(source, result, "height_curve")
	_copy_bool_if_present(source, result, "use_corner_ocean")

	var old_noise = source.get("noise")
	if old_noise is FastNoiseLite:
		result.noise = old_noise

	var forced_edge = source.get("forced_ocean_edge")
	if forced_edge is String:
		result.forced_ocean_edge = _edge_string_to_v2(forced_edge)

	var corner = source.get("ocean_corner")
	if corner is int:
		result.ocean_corner = clampi(corner, 0, 5)

	return result

func _copy_int_if_present(source: Object, target: Object, source_name: String, target_name: String = "") -> void:
	var value = source.get(source_name)
	if value == null:
		return
	target.set(target_name if target_name != "" else source_name, int(value))

func _copy_float_if_present(source: Object, target: Object, source_name: String, target_name: String = "") -> void:
	var value = source.get(source_name)
	if value == null:
		return
	target.set(target_name if target_name != "" else source_name, float(value))

func _copy_bool_if_present(source: Object, target: Object, source_name: String, target_name: String = "") -> void:
	var value = source.get(source_name)
	if value == null:
		return
	target.set(target_name if target_name != "" else source_name, bool(value))

func _edge_string_to_v2(edge: String) -> int:
	match edge:
		"WEST": return GenerationSettingsV2.OceanEdge.WEST
		"EAST": return GenerationSettingsV2.OceanEdge.EAST
		"NORTH_WEST": return GenerationSettingsV2.OceanEdge.NORTH_WEST
		"NORTH_EAST": return GenerationSettingsV2.OceanEdge.NORTH_EAST
		"SOUTH_WEST": return GenerationSettingsV2.OceanEdge.SOUTH_WEST
		"SOUTH_EAST": return GenerationSettingsV2.OceanEdge.SOUTH_EAST
		_: return GenerationSettingsV2.OceanEdge.NONE

func _print_generation_summary() -> void:
	if current_map == null:
		return
	var land := 0
	var ocean := 0
	var coast := 0
	for tile in current_map.tiles:
		if tile.is_water():
			ocean += 1
		else:
			land += 1
		if tile.coast_variant_index >= 0:
			coast += 1
	print("WorldGen2: tiles=%s land=%s water=%s coast=%s seed=%s" % [current_map.tiles.size(), land, ocean, coast, current_map.seed])
