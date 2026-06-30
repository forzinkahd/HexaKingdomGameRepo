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
@export var resource_height_unit_correction: int = -2
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


func has_resource_near_coord(coord: Vector2i, id: StringName, radius: int) -> bool:
	return get_nearest_resource_distance(coord, id, radius) >= 0


func get_nearest_resource_distance(coord: Vector2i, id: StringName, max_radius: int) -> int:
	var best := 999999

	for node_coord in _nodes_by_coord.keys():
		var distance := _hex_distance(coord, node_coord)

		if distance > max_radius:
			continue

		for node_def in get_nodes_at_coord(node_coord):
			if node_def.id == id:
				best = min(best, distance)

	if best == 999999:
		return -1

	return best


func get_best_multiplier_for_building(building: PlacedBuildingV2) -> float:
	if building == null or not is_instance_valid(building):
		return 1.0

	if building.definition == null:
		return 1.0

	if not building.is_production_building():
		return 1.0

	var definition := building.definition
	var custom_multiplier := _get_custom_resource_affinity_multiplier(building)

	if custom_multiplier > 1.001:
		return custom_multiplier

	if _definition_uses_generic_bonuses(definition):
		return _get_generic_resource_multiplier(building)

	return 1.0


func requirements_met_for_building_on_tile(definition: BuildingDefinition, tile: WorldTile) -> bool:
	return missing_required_resources_for_tile(definition, tile).is_empty()


func missing_required_resources_for_tile(definition: BuildingDefinition, tile: WorldTile) -> Array[StringName]:
	var missing: Array[StringName] = []

	if definition == null or tile == null:
		return missing

	for affinity in _definition_resource_affinities(definition):
		if affinity == null:
			continue

		if not affinity.required:
			continue

		if not has_resource_near_coord(tile.coord, affinity.resource_node_id, affinity.search_radius):
			missing.append(affinity.resource_node_id)

	return missing


func requirement_reason_for_tile(definition: BuildingDefinition, tile: WorldTile) -> String:
	var missing := missing_required_resources_for_tile(definition, tile)

	if missing.is_empty():
		return "Resource requirements met"

	var parts: Array[String] = []

	for id in missing:
		parts.append(str(id))

	return "Requires resource nearby: " + ", ".join(parts)


func get_resource_summary_for_building(building: PlacedBuildingV2) -> String:
	if building == null or not is_instance_valid(building):
		return "No building"

	if building.definition == null:
		return "No definition"

	if not building.is_production_building():
		return "No production"

	var multiplier := get_best_multiplier_for_building(building)

	if multiplier <= 1.001:
		return "No resource bonus"

	var source := get_best_bonus_source_for_building(building)

	if source == "":
		return "Resource bonus x%.2f" % [multiplier]

	return "%s x%.2f" % [source, multiplier]


func get_best_bonus_source_for_building(building: PlacedBuildingV2) -> String:
	if building == null or not is_instance_valid(building):
		return ""

	if building.definition == null:
		return ""

	var definition := building.definition
	var best_multiplier := 1.0
	var best_label := ""

	for affinity in _definition_resource_affinities(definition):
		if affinity == null:
			continue

		var match_info := _best_affinity_match_for_building(building, affinity)

		if float(match_info.get("multiplier", 1.0)) > best_multiplier:
			best_multiplier = float(match_info["multiplier"])
			best_label = str(match_info["label"])

	if best_label != "":
		return best_label

	if _definition_uses_generic_bonuses(definition):
		return _get_generic_bonus_source(building)

	return ""


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


func get_building_resource_rule_summary(definition: BuildingDefinition) -> String:
	if definition == null:
		return "No building"

	var affinities := _definition_resource_affinities(definition)

	if affinities.is_empty():
		if _definition_uses_generic_bonuses(definition):
			return "Uses generic resource bonuses"
		return "No resource-node rules"

	var parts: Array[String] = []

	for affinity in affinities:
		if affinity == null:
			continue

		parts.append(affinity.summary())

	return "; ".join(parts)


func _get_custom_resource_affinity_multiplier(building: PlacedBuildingV2) -> float:
	var best := 1.0

	for affinity in _definition_resource_affinities(building.definition):
		if affinity == null:
			continue

		var match_info := _best_affinity_match_for_building(building, affinity)
		best = maxf(best, float(match_info.get("multiplier", 1.0)))

	return best


func _best_affinity_match_for_building(
	building: PlacedBuildingV2,
	affinity: BuildingResourceAffinityV2
) -> Dictionary:
	var result := {
		"multiplier": 1.0,
		"label": ""
	}

	if building == null or not is_instance_valid(building):
		return result

	var coords := building.occupied_coords.duplicate()

	if coords.is_empty() and building.tile != null:
		coords.append(building.tile.coord)

	for coord in coords:
		for node_def in get_nodes_at_coord(coord):
			if node_def.id == affinity.resource_node_id:
				if affinity.on_tile_multiplier > float(result["multiplier"]):
					result["multiplier"] = affinity.on_tile_multiplier
					result["label"] = "%s on tile" % [affinity.effective_display_name()]

		for node_coord in _nodes_by_coord.keys():
			var distance := _hex_distance(coord, node_coord)

			if distance <= 0 or distance > affinity.search_radius:
				continue

			for node_def in get_nodes_at_coord(node_coord):
				if node_def.id != affinity.resource_node_id:
					continue

				if affinity.nearby_multiplier > float(result["multiplier"]):
					result["multiplier"] = affinity.nearby_multiplier
					result["label"] = "%s nearby d%d" % [affinity.effective_display_name(), distance]

	return result


func _get_generic_resource_multiplier(building: PlacedBuildingV2) -> float:
	if building == null or not is_instance_valid(building):
		return 1.0

	if building.definition == null:
		return 1.0

	var resource := building.definition.produces_resource
	var best := 1.0

	for coord in building.occupied_coords:
		best = maxf(best, _best_generic_multiplier_at_coord_for_resource(coord, resource, true))

	if building.occupied_coords.is_empty() and building.tile != null:
		best = maxf(best, _best_generic_multiplier_at_coord_for_resource(building.tile.coord, resource, true))

	return best


func _get_generic_bonus_source(building: PlacedBuildingV2) -> String:
	if building == null or not is_instance_valid(building):
		return ""

	var resource := building.definition.produces_resource
	var best := 1.0
	var label := ""

	var coords := building.occupied_coords.duplicate()
	if coords.is_empty() and building.tile != null:
		coords.append(building.tile.coord)

	for coord in coords:
		for node_def in get_nodes_at_coord(coord):
			if node_def.affected_resource == resource and node_def.on_tile_multiplier > best:
				best = node_def.on_tile_multiplier
				label = "%s on tile" % [node_def.display_name]

		for node_coord in _nodes_by_coord.keys():
			var distance := _hex_distance(coord, node_coord)

			for node_def in get_nodes_at_coord(node_coord):
				if node_def.affected_resource != resource:
					continue

				if distance > 0 and distance <= node_def.nearby_radius and node_def.nearby_multiplier > best:
					best = node_def.nearby_multiplier
					label = "%s nearby d%d" % [node_def.display_name, distance]

	return label


func _best_generic_multiplier_at_coord_for_resource(
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
			var distance := _hex_distance(coord, node_coord)

			for node_def in get_nodes_at_coord(node_coord):
				if node_def.affected_resource != resource:
					continue

				if distance > 0 and distance <= node_def.nearby_radius:
					best = maxf(best, node_def.nearby_multiplier)

	return best


func _definition_resource_affinities(definition: BuildingDefinition) -> Array[BuildingResourceAffinityV2]:
	var result: Array[BuildingResourceAffinityV2] = []

	if definition == null:
		return result

	var raw = definition.get("resource_affinities")

	if raw == null:
		return result

	for item in raw:
		if item is BuildingResourceAffinityV2:
			result.append(item)

	return result


func _definition_uses_generic_bonuses(definition: BuildingDefinition) -> bool:
	if definition == null:
		return true

	var value = definition.get("use_generic_resource_node_bonuses")

	if value == null:
		return true

	return bool(value)


func _add_resource_node(tile: WorldTile, definition: ResourceNodeDefinitionV2) -> void:
	var current: Array = _nodes_by_coord.get(tile.coord, [])
	current.append(definition)
	_nodes_by_coord[tile.coord] = current

	var visual := _make_resource_visual(definition)
	visual.name = "ResourceNode_%s_%s_%s" % [definition.id, tile.coord.x, tile.coord.y]

	var visual_y := resource_y_offset
	var settings := _current_settings()

	if settings != null:
		visual_y += float(tile.height_units + resource_height_unit_correction) * settings.height_step

	visual.position = Vector3(tile.world_position.x, visual_y, tile.world_position.z)
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


func get_projected_multiplier_for_definition_on_tile(
	definition: BuildingDefinition,
	tile: WorldTile
) -> float:
	if definition == null or tile == null:
		return 1.0

	var custom_multiplier := _get_custom_resource_affinity_multiplier_for_definition_on_tile(
		definition,
		tile
	)

	if custom_multiplier > 1.001:
		return custom_multiplier

	if _definition_uses_generic_bonuses(definition):
		return _get_generic_resource_multiplier_for_definition_on_tile(definition, tile)

	return 1.0


func get_projected_bonus_source_for_definition_on_tile(
	definition: BuildingDefinition,
	tile: WorldTile
) -> String:
	if definition == null or tile == null:
		return ""

	var custom_source := _get_custom_bonus_source_for_definition_on_tile(definition, tile)

	if custom_source != "":
		return custom_source

	if _definition_uses_generic_bonuses(definition):
		return _get_generic_bonus_source_for_definition_on_tile(definition, tile)

	return ""


func _get_custom_resource_affinity_multiplier_for_definition_on_tile(
	definition: BuildingDefinition,
	tile: WorldTile
) -> float:
	var best := 1.0

	for affinity in _definition_resource_affinities(definition):
		if affinity == null:
			continue

		var match_info := _best_affinity_match_for_tile(tile, affinity)
		best = maxf(best, float(match_info.get("multiplier", 1.0)))

	return best


func _get_custom_bonus_source_for_definition_on_tile(
	definition: BuildingDefinition,
	tile: WorldTile
) -> String:
	var best_multiplier := 1.0
	var best_label := ""

	for affinity in _definition_resource_affinities(definition):
		if affinity == null:
			continue

		var match_info := _best_affinity_match_for_tile(tile, affinity)
		var multiplier := float(match_info.get("multiplier", 1.0))

		if multiplier > best_multiplier:
			best_multiplier = multiplier
			best_label = str(match_info.get("label", ""))

	return best_label


func _best_affinity_match_for_tile(
	tile: WorldTile,
	affinity: BuildingResourceAffinityV2
) -> Dictionary:
	var result := {
		"multiplier": 1.0,
		"label": ""
	}

	if tile == null or affinity == null:
		return result

	for node_def in get_nodes_at_coord(tile.coord):
		if node_def.id == affinity.resource_node_id:
			result["multiplier"] = affinity.on_tile_multiplier
			result["label"] = "%s on tile" % [affinity.effective_display_name()]
			return result

	for node_coord in _nodes_by_coord.keys():
		var distance := _hex_distance(tile.coord, node_coord)

		if distance <= 0 or distance > affinity.search_radius:
			continue

		for node_def in get_nodes_at_coord(node_coord):
			if node_def.id != affinity.resource_node_id:
				continue

			if affinity.nearby_multiplier > float(result["multiplier"]):
				result["multiplier"] = affinity.nearby_multiplier
				result["label"] = "%s nearby d%d" % [affinity.effective_display_name(), distance]

	return result


func _get_generic_resource_multiplier_for_definition_on_tile(
	definition: BuildingDefinition,
	tile: WorldTile
) -> float:
	if definition == null or tile == null:
		return 1.0

	return _best_generic_multiplier_at_coord_for_resource(
		tile.coord,
		definition.produces_resource,
		true
	)


func _get_generic_bonus_source_for_definition_on_tile(
	definition: BuildingDefinition,
	tile: WorldTile
) -> String:
	if definition == null or tile == null:
		return ""
	
	var resource := definition.produces_resource
	var best := 1.0
	var label := ""
	
	for node_def in get_nodes_at_coord(tile.coord):
		if node_def.affected_resource == resource and node_def.on_tile_multiplier > best:
			best = node_def.on_tile_multiplier
			label = "%s on tile" % [node_def.display_name]
	
	for node_coord in _nodes_by_coord.keys():
		var distance := _hex_distance(tile.coord, node_coord)
	
		for node_def in get_nodes_at_coord(node_coord):
			if node_def.affected_resource != resource:
				continue
	
			if distance > 0 and distance <= node_def.nearby_radius and node_def.nearby_multiplier > best:
				best = node_def.nearby_multiplier
				label = "%s nearby d%d" % [node_def.display_name, distance]
	
	return label


func get_best_bonus_for_building(definition: BuildingDefinition, tile: WorldTile) -> Dictionary:
	var result := {
		"multiplier": 1.0,
		"description": ""
	}
	
	if definition == null or tile == null:
		return result
	
	var multiplier := get_projected_multiplier_for_definition_on_tile(definition, tile)
	var source := get_projected_bonus_source_for_definition_on_tile(definition, tile)
	
	result["multiplier"] = multiplier
	
	if source != "" and multiplier > 1.001:
		result["description"] = "%s x%.2f" % [source, multiplier]
	
	return result


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
			return Color(0.25, 0.35, 0.55)
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


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -dq - dr

	return int((abs(dq) + abs(dr) + abs(ds)) / 2)
