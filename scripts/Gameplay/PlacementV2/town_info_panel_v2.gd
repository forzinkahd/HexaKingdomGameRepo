class_name TownInfoPanelV2
extends Label

@export var picker: WorldTilePicker
@export var placement: BuildingPlacementV2
@export var registry: BuildingRegistryV2
@export var town_center_manager: TownCenterManagerV2
@export var production: WorldProductionV2

@export_group("Display")
@export var refresh_seconds: float = 0.25
@export var show_politics_placeholder: bool = true

@export var politics: TownPoliticsManagerV2

var selected_tile: WorldTile
var selected_visual_node: Node3D
var _elapsed: float = 0.0


func _ready() -> void:
	if picker != null and not picker.tile_selected.is_connected(_on_tile_selected):
		picker.tile_selected.connect(_on_tile_selected)

	if registry != null and not registry.registry_changed.is_connected(_refresh):
		registry.registry_changed.connect(_refresh)

	if town_center_manager != null:
		if not town_center_manager.town_center_changed.is_connected(_on_town_center_changed):
			town_center_manager.town_center_changed.connect(_on_town_center_changed)

		if not town_center_manager.town_parameters_changed.is_connected(_refresh):
			town_center_manager.town_parameters_changed.connect(_refresh)

	if placement != null and not placement.placement_changed.is_connected(_on_placement_changed):
		placement.placement_changed.connect(_on_placement_changed)

	if politics != null:
		if not politics.active_policy_changed.is_connected(_refresh):
			politics.active_policy_changed.connect(_refresh)
		if not politics.politics_changed.is_connected(_refresh):
			politics.politics_changed.connect(_refresh)

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


func _on_town_center_changed(_town_center: PlacedBuildingV2) -> void:
	_refresh()


func _on_placement_changed(tile: WorldTile, result: PlacementRulesV2.PlacementResult) -> void:
	selected_tile = tile
	_refresh()


func _refresh(_arg = null) -> void:
	var lines: Array[String] = []

	lines.append("TOWN")
	lines.append("----")

	if town_center_manager == null:
		lines.append("Town manager: missing")
		text = "\n".join(lines)
		return

	lines.append(town_center_manager.get_town_summary())

	if politics != null:
		lines.append(politics.get_status_summary())
		lines.append(politics.get_policy_summary())
	else:
		lines.append("Authority: %d/100" % [town_center_manager.authority])
		lines.append("Stability: %d/100" % [town_center_manager.stability])
		lines.append("Approval: %d/100" % [town_center_manager.approval])

	lines.append("")
	lines.append("Selected")
	lines.append("--------")

	if selected_tile == null:
		lines.append("No tile selected")
	else:
		lines.append("Tile: %s" % [str(selected_tile.coord)])
		lines.append("Biome: %s" % [_biome_name(selected_tile.biome_kind)])
		lines.append(town_center_manager.get_efficiency_text_for_tile(selected_tile))

	if placement != null and placement.active_definition != null:
		var definition := placement.active_definition

		lines.append("")
		lines.append("Active Build")
		lines.append("------------")
		lines.append(definition.display_name)
		lines.append("Cost: %s" % [definition.cost_summary()])

		if definition.produces_resource != BuildingDefinition.ProducedResource.NONE and definition.production_amount > 0:
			var projected_efficiency := 1.0

			if selected_tile != null:
				projected_efficiency = town_center_manager.get_efficiency_for_tile(selected_tile)

			var projected := float(definition.production_amount) * projected_efficiency
			lines.append("Base production: %s +%d" % [
				BuildingDefinition.resource_name(definition.produces_resource),
				definition.production_amount
			])
			lines.append("Projected effective: %.2f / tick" % [projected])

	if registry != null:
		lines.append("")
		lines.append("Buildings: %d" % [registry.get_total_count()])

	text = "\n".join(lines)


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
