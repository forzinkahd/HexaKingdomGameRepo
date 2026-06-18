class_name SelectedResourceNodeInfoPanelV2
extends Label

@export var picker: WorldTilePicker
@export var resource_map: WorldResourceMapV2
@export var placement: BuildingPlacementV2

@export_group("Display")
@export var refresh_seconds: float = 0.25
@export var show_when_empty: bool = true
@export var show_active_building_interaction: bool = true
@export var show_all_nodes_on_tile: bool = true

var selected_tile: WorldTile
var selected_visual_node: Node3D
var _elapsed: float = 0.0


func _ready() -> void:
	if picker != null and not picker.tile_selected.is_connected(_on_tile_selected):
		picker.tile_selected.connect(_on_tile_selected)

	if resource_map != null:
		if not resource_map.resources_generated.is_connected(_refresh):
			resource_map.resources_generated.connect(_refresh)

		if not resource_map.resources_cleared.is_connected(_refresh):
			resource_map.resources_cleared.connect(_refresh)

	if placement != null and not placement.placement_changed.is_connected(_on_placement_changed):
		placement.placement_changed.connect(_on_placement_changed)

	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta

	if _elapsed < refresh_seconds:
		return

	_elapsed = 0.0
	_refresh()


func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	selected_tile = tile
	selected_visual_node = visual_node
	_refresh()


func _on_placement_changed(tile: WorldTile, result: PlacementRulesV2.PlacementResult) -> void:
	selected_tile = tile
	_refresh()


func _refresh(_arg = null) -> void:
	if selected_tile == null:
		if show_when_empty:
			text = "RESOURCE\n--------\nNo tile selected"
		else:
			text = ""
		return

	if resource_map == null:
		text = "RESOURCE\n--------\nResource map missing"
		return

	var nodes := resource_map.get_nodes_on_tile(selected_tile)

	if nodes.is_empty():
		_show_no_resource()
		return

	text = _format_resources(nodes)


func _show_no_resource() -> void:
	if not show_when_empty:
		text = ""
		return

	var lines: Array[String] = []
	lines.append("RESOURCE")
	lines.append("--------")
	lines.append("No resource node on selected tile")
	lines.append("")
	lines.append("Tile: %s" % [str(selected_tile.coord)])
	lines.append("Biome: %s" % [_biome_name(selected_tile.biome_kind)])

	if show_active_building_interaction and placement != null and placement.active_definition != null:
		lines.append("")
		lines.append("Active Build")
		lines.append("------------")
		lines.append(placement.active_definition.display_name)

		if resource_map != null:
			lines.append(resource_map.get_building_resource_rule_summary(placement.active_definition))

			var missing := resource_map.missing_required_resources_for_tile(
				placement.active_definition,
				selected_tile
			)

			if missing.is_empty():
				lines.append("Resource requirement: OK")
			else:
				lines.append("Resource requirement: %s" % [_format_missing(missing)])

	text = "\n".join(lines)


func _format_resources(nodes: Array[ResourceNodeDefinitionV2]) -> String:
	var lines: Array[String] = []
	lines.append("RESOURCE")
	lines.append("--------")
	lines.append("Tile: %s" % [str(selected_tile.coord)])

	if show_all_nodes_on_tile:
		lines.append("Nodes on tile: %d" % [nodes.size()])

	var index := 1

	for node_def in nodes:
		if node_def == null:
			continue

		if show_all_nodes_on_tile and nodes.size() > 1:
			lines.append("")
			lines.append("#%d" % [index])

		lines.append(node_def.display_name)
		lines.append("ID: %s" % [str(node_def.id)])
		lines.append("Kind: %s" % [ResourceNodeDefinitionV2.kind_name(node_def.kind)])
		lines.append("Bonus: %s" % [node_def.bonus_summary()])
		lines.append("Spawn chance: %d%%" % [int(round(node_def.spawn_chance * 100.0))])

		if not node_def.allowed_biomes.is_empty():
			lines.append("Allowed biomes: %s" % [_format_biomes(node_def.allowed_biomes)])
		else:
			lines.append("Allowed biomes: all land")

		index += 1

	if show_active_building_interaction and placement != null and placement.active_definition != null:
		lines.append("")
		lines.append("Active Build Interaction")
		lines.append("------------------------")
		lines.append(_format_active_building_interaction(placement.active_definition))

	return "\n".join(lines)


func _format_active_building_interaction(definition: BuildingDefinition) -> String:
	if definition == null:
		return "No active building"

	var lines: Array[String] = []
	lines.append(definition.display_name)
	lines.append(resource_map.get_building_resource_rule_summary(definition))

	var missing := resource_map.missing_required_resources_for_tile(definition, selected_tile)

	if missing.is_empty():
		lines.append("Resource requirement: OK")
	else:
		lines.append("Resource requirement: %s" % [_format_missing(missing)])

	var projected := resource_map.get_projected_multiplier_for_definition_on_tile(
		definition,
		selected_tile
	)

	lines.append("Projected resource multiplier: x%.2f" % [projected])

	if projected > 1.001:
		lines.append(resource_map.get_projected_bonus_source_for_definition_on_tile(
			definition,
			selected_tile
		))

	return "\n".join(lines)


func _format_missing(missing: Array[StringName]) -> String:
	var parts: Array[String] = []

	for id in missing:
		parts.append(str(id))

	return "missing " + ", ".join(parts)


func _format_biomes(values: Array[int]) -> String:
	var parts: Array[String] = []

	for value in values:
		parts.append(_biome_name(value))

	return ", ".join(parts)


func _biome_name(value: int) -> String:
	match value:
		WorldTile.BiomeKind.PLAINS:
			return "Plains"
		WorldTile.BiomeKind.COAST:
			return "Coast"
		WorldTile.BiomeKind.FOREST:
			return "Forest"
		WorldTile.BiomeKind.HILLS:
			return "Hills"
		WorldTile.BiomeKind.MOUNTAIN:
			return "Mountain"
		_:
			return "Unknown"
