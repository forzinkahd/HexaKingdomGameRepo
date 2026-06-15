class_name WorldResourceMapV2
extends Node3D

signal resources_generated
signal resources_cleared

@export var world_gen_controller: WorldGenController
@export var resource_root: Node3D
@export var resource_definitions: Array[ResourceNodeDefinitionV2] = []

@export_group("Generation")
@export var generate_on_ready: bool = false
@export var auto_regenerate_when_world_changes: bool = true
@export var seed_offset: int = 7919
@export var max_nodes_per_tile: int = 1

@export_group("Visuals")
@export var resource_y_offset: float = 0.65
@export var fallback_visual_scale: float = 0.45

var _nodes_by_coord: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _observed_map: WorldMapData


func _ready() -> void:
	if world_gen_controller == null:
		world_gen_controller = get_node_or_null("../WorldGenController") as WorldGenController

	if resource_root == null:
		resource_root = self

	if generate_on_ready:
		call_deferred("generate_resources")


func _process(_delta: float) -> void:
	if not auto_regenerate_when_world_changes:
		return

	var current_map := _current_map()

	if current_map != null and current_map != _observed_map:
		generate_resources()


func generate_resources() -> void:
	clear_resources()

	var world_map := _current_map()
	_observed_map = world_map

	if world_map == null:
		push_warning("WorldResourceMapV2: no WorldMapData available.")
		return

	var settings := _current_settings()
	var seed_value := seed_offset

	if settings != null:
		seed_value += settings.map_seed

	_rng.seed = seed_value

	for tile in world_map.tiles:
		if tile == null:
			continue

		if tile.water_kind != WorldTile.WaterKind.NONE:
			continue

		var placed_count := 0

		for definition in resource_definitions:
			if definition == null:
				continue

			if placed_count >= max_nodes_per_tile:
				break

			if not definition.allows_tile(tile):
				continue

			if _rng.randf() > definition.spawn_chance:
				continue

			_add_resource_node(tile, definition)
			placed_count += 1

	resources_generated.emit()


func clear_resources() -> void:
	_nodes_by_coord.clear()

	if resource_root != null:
		for child in resource_root.get_children():
			if child.name.begins_with("ResourceNode_"):
				child.queue_free()

	resources_cleared.emit()


func get_nodes_on_tile(tile: WorldTile) -> Array[ResourceNodeDefinitionV2]:
	if tile == null:
		return []

	return get_nodes_at_coord(tile.coord)


func get_nodes_at_coord(coord: Vector2i) -> Array[ResourceNodeDefinitionV2]:
	var result: Array[ResourceNodeDefinitionV2] = []
	var raw = _nodes_by_coord.get(coord, [])

	for item in raw:
		if item is ResourceNodeDefinitionV2:
			result.append(item)

	return result


func has_resource_at_coord(coord: Vector2i, id: StringName) -> bool:
	for node_def in get_nodes_at_coord(coord):
		if node_def.id == id:
			return true

	return false


func get_best_multiplier_for_building(building: PlacedBuildingV2) -> float:
	if building == null or not is_instance_valid(building):
		return 1.0

	if building.definition == null:
		return 1.0

	if not building.is_production_building():
		return 1.0

	var resource := building.definition.produces_resource
	var best := 1.0

	for coord in building.occupied_coords:
		best = maxf(best, _best_multiplier_at_coord_for_resource(coord, resource, true))

	# Some old buildings may not have occupied_coords populated.
	if building.occupied_coords.is_empty() and building.tile != null:
		best = maxf(best, _best_multiplier_at_coord_for_resource(building.tile.coord, resource, true))

	return best


func get_resource_summary_for_building(building: PlacedBuildingV2) -> String:
	if building == null or not is_instance_valid(building):
		return "No building"

	if building.definition == null:
		return "No definition"

	if not building.is_production_building():
		return "No production"

	var resource := building.definition.produces_resource
	var multiplier := get_best_multiplier_for_building(building)

	if multiplier <= 1.001:
		return "No resource bonus"

	return "%s terrain bonus x%.2f" % [
		BuildingDefinition.resource_name(resource),
		multiplier
	]


func get_resource_summary_for_tile(tile: WorldTile) -> String:
	if tile == null:
		return "No tile"

	var nodes := get_nodes_on_tile(tile)

	if nodes.is_empty():
		return "No resource node"

	var parts: Array[String] = []

	for node_def in nodes:
		parts.append("%s (%s)" % [node_def.display_name, node_def.bonus_summary()])

	return "; ".join(parts)


func _best_multiplier_at_coord_for_resource(
	coord: Vector2i,
	resource: BuildingDefinition.ProducedResource,
	include_nearby: bool
) -> float:
	var best := 1.0

	for node_def in get_nodes_at_coord(coord):
		if node_def.affected_resource == resource:
			best = maxf(best, node_def.on_tile_multiplier)

	if include_nearby:
		for node_coord in _nodes_by_coord.keys():
			var distance := HexFootprintV2.distance(coord, node_coord)

			for node_def in get_nodes_at_coord(node_coord):
				if node_def.affected_resource != resource:
					continue

				if distance > 0 and distance <= node_def.nearby_radius:
					best = maxf(best, node_def.nearby_multiplier)

	return best


func _add_resource_node(tile: WorldTile, definition: ResourceNodeDefinitionV2) -> void:
	var current: Array = _nodes_by_coord.get(tile.coord, [])
	current.append(definition)
	_nodes_by_coord[tile.coord] = current

	var visual := _make_resource_visual(definition)
	visual.name = "ResourceNode_%s_%s_%s" % [definition.id, tile.coord.x, tile.coord.y]
	visual.position = tile.world_position + Vector3.UP * resource_y_offset
	visual.set_meta("resource_node_definition", definition)
	visual.set_meta("world_tile", tile)
	visual.set_meta("coord", tile.coord)

	resource_root.add_child(visual)


func _make_resource_visual(definition: ResourceNodeDefinitionV2) -> Node3D:
	var visual: Node3D = null

	if definition.scene != null:
		visual = definition.scene.instantiate() as Node3D

	if visual == null:
		visual = _fallback_visual(definition)

	return visual


func _fallback_visual(definition: ResourceNodeDefinitionV2) -> Node3D:
	var root := Node3D.new()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FallbackResourceVisual"

	var mesh := SphereMesh.new()
	mesh.radius = fallback_visual_scale
	mesh.height = fallback_visual_scale * 1.4
	mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = _fallback_color(definition)
	mesh_instance.material_override = mat

	root.add_child(mesh_instance)
	return root


func _fallback_color(definition: ResourceNodeDefinitionV2) -> Color:
	match definition.kind:
		ResourceNodeDefinitionV2.ResourceNodeKind.FOREST:
			return Color(0.1, 0.45, 0.12)
		ResourceNodeDefinitionV2.ResourceNodeKind.STONE_DEPOSIT:
			return Color(0.45, 0.45, 0.45)
		ResourceNodeDefinitionV2.ResourceNodeKind.FERTILE_SOIL:
			return Color(0.4, 0.25, 0.08)
		ResourceNodeDefinitionV2.ResourceNodeKind.GOLD_VEIN:
			return Color(1.0, 0.78, 0.15)
		_:
			return Color(0.8, 0.8, 0.8)


func _current_map() -> WorldMapData:
	if world_gen_controller == null:
		return null

	return world_gen_controller.current_map


func _current_settings() -> GenerationSettingsV2:
	if world_gen_controller == null:
		return null

	return world_gen_controller.current_settings
