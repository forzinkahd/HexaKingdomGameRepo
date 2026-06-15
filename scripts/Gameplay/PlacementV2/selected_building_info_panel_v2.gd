class_name SelectedBuildingInfoPanelV2
extends Label

@export var picker: WorldTilePicker
@export var occupancy: WorldOccupancyV2
@export var registry: BuildingRegistryV2
@export var town_center_manager: TownCenterManagerV2
@export var production: WorldProductionV2
@export var resource_map: WorldResourceMapV2

@export_group("Display")
@export var refresh_seconds: float = 0.25
@export var show_when_empty: bool = true
@export var show_tile_info_when_empty: bool = true
@export var show_footprint_coords: bool = true
@export var max_footprint_coords_shown: int = 12

var selected_tile: WorldTile
var selected_visual_node: Node3D
var selected_building: PlacedBuildingV2

var _elapsed: float = 0.0


func _ready() -> void:
	if picker != null and not picker.tile_selected.is_connected(_on_tile_selected):
		picker.tile_selected.connect(_on_tile_selected)

	if registry != null and not registry.registry_changed.is_connected(_refresh):
		registry.registry_changed.connect(_refresh)

	if town_center_manager != null:
		if not town_center_manager.town_center_changed.is_connected(_refresh):
			town_center_manager.town_center_changed.connect(_refresh)

		if not town_center_manager.town_parameters_changed.is_connected(_refresh):
			town_center_manager.town_parameters_changed.connect(_refresh)

	if production != null:
		if not production.production_building_registered.is_connected(_refresh):
			production.production_building_registered.connect(_refresh)

		if not production.production_building_unregistered.is_connected(_refresh):
			production.production_building_unregistered.connect(_refresh)

	if resource_map != null:
		if not resource_map.resources_generated.is_connected(_refresh):
			resource_map.resources_generated.connect(_refresh)

		if not resource_map.resources_cleared.is_connected(_refresh):
			resource_map.resources_cleared.connect(_refresh)

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
	selected_building = _building_from_tile(tile)
	_refresh()


func _refresh(_arg = null) -> void:
	selected_building = _building_from_tile(selected_tile)

	if selected_building == null:
		_show_empty_or_tile_info()
		return

	text = _format_building(selected_building)


func _building_from_tile(tile: WorldTile) -> PlacedBuildingV2:
	if tile == null:
		return null

	if occupancy == null:
		return null

	var occupant := occupancy.get_occupant(tile)

	if occupant == null:
		return null

	if occupant is PlacedBuildingV2:
		return occupant as PlacedBuildingV2

	var node := occupant as Node

	while node != null:
		if node is PlacedBuildingV2:
			return node as PlacedBuildingV2

		node = node.get_parent()

	return null


func _show_empty_or_tile_info() -> void:
	if not show_when_empty:
		text = ""
		return

	var lines: Array[String] = []
	lines.append("BUILDING")
	lines.append("--------")

	if selected_tile == null:
		lines.append("No tile selected")
		text = "\n".join(lines)
		return

	lines.append("No building on selected tile")

	if show_tile_info_when_empty:
		lines.append("")
		lines.append("Tile: %s" % [str(selected_tile.coord)])
		lines.append("Biome: %s" % [_biome_name(selected_tile.biome_kind)])
		lines.append("Water: %s" % [_water_name(selected_tile.water_kind)])
		lines.append("Buildable: %s" % [str(selected_tile.buildable)])

		if town_center_manager != null:
			lines.append(town_center_manager.get_efficiency_text_for_tile(selected_tile))

		if resource_map != null:
			lines.append("Resource: %s" % [resource_map.get_resource_summary_for_tile(selected_tile)])

	text = "\n".join(lines)


func _format_building(building: PlacedBuildingV2) -> String:
	var lines: Array[String] = []
	lines.append("BUILDING")
	lines.append("--------")

	if building.definition == null:
		lines.append("Unknown building")
		lines.append("Coord: %s" % [str(building.tile.coord)])
		return "\n".join(lines)

	var definition := building.definition

	lines.append(definition.display_name)
	lines.append("ID: %s" % [str(definition.id)])
	lines.append("Category: %s" % [BuildingDefinition.category_name(definition.category)])

	if building.tile != null:
		lines.append("Coord: %s" % [str(building.tile.coord)])

	if building.occupied_coords.size() > 0:
		lines.append("Footprint tiles: %d" % [building.occupied_coords.size()])

		if show_footprint_coords:
			lines.append("Footprint: %s" % [_format_footprint(building.occupied_coords)])

	lines.append("")
	lines.append("Production")
	lines.append("----------")

	if not building.is_production_building():
		lines.append("None")
	else:
		var resource_name := BuildingDefinition.resource_name(definition.produces_resource)
		var base_amount := definition.production_amount
		var town_efficiency := _town_efficiency_for_building(building)
		var resource_multiplier := _resource_multiplier_for_building(building)
		var effective_amount := float(base_amount) * town_efficiency * resource_multiplier
		var global_multiplier := _global_multiplier_for_resource(definition.produces_resource)
		var final_estimate := effective_amount * global_multiplier

		lines.append("Resource: %s" % [resource_name])
		lines.append("Base: +%d / global tick" % [base_amount])
		lines.append("Town efficiency: %d%%" % [int(round(town_efficiency * 100.0))])
		lines.append("Resource bonus: x%.2f" % [resource_multiplier])
		if resource_map != null:
			lines.append(resource_map.get_resource_summary_for_building(building))
		lines.append("Effective base: %.2f / tick" % [effective_amount])
		lines.append("Global multiplier: x%.2f" % [global_multiplier])
		lines.append("Estimated contribution: %.2f / tick" % [final_estimate])

		if town_center_manager != null and building.tile != null:
			var distance := town_center_manager.get_distance_to_town_center(building.tile)
			if distance >= 0:
				lines.append("Town distance: %d" % [distance])

	lines.append("")
	lines.append("Economy / Rules")
	lines.append("---------------")
	lines.append("Original cost: %s" % [definition.cost_summary()])

	if definition.is_unique:
		lines.append("Unique: yes")
		lines.append("Limit: %d per %s" % [definition.unique_limit, definition.unique_scope_label])
	else:
		lines.append("Unique: no")

	if definition.required_building_ids.size() > 0:
		lines.append("Requires: %s" % [_format_string_names(definition.required_building_ids)])
	else:
		lines.append("Requires: none")

	return "\n".join(lines)


func _town_efficiency_for_building(building: PlacedBuildingV2) -> float:
	if town_center_manager == null:
		return 1.0

	return town_center_manager.get_efficiency_for_building(building)


func _resource_multiplier_for_building(building: PlacedBuildingV2) -> float:
	if resource_map == null:
		return 1.0

	return resource_map.get_best_multiplier_for_building(building)


func _global_multiplier_for_resource(resource: BuildingDefinition.ProducedResource) -> float:
	if production == null:
		return 1.0

	return production.get_productivity_multiplier(resource)


func _format_footprint(coords: Array[Vector2i]) -> String:
	var parts: Array[String] = []
	var shown: int = min(coords.size(), max_footprint_coords_shown)

	for i in range(shown):
		parts.append(str(coords[i]))

	if coords.size() > shown:
		parts.append("+%d more" % [coords.size() - shown])

	return ", ".join(parts)


func _format_string_names(values: Array[StringName]) -> String:
	var parts: Array[String] = []

	for value in values:
		parts.append(str(value))

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


func _water_name(value: int) -> String:
	match value:
		WorldTile.WaterKind.NONE:
			return "None"
		WorldTile.WaterKind.OCEAN:
			return "Ocean"
		WorldTile.WaterKind.LAKE:
			return "Lake"
		_:
			return "Unknown"
