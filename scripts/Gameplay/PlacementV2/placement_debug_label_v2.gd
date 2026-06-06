class_name PlacementDebugLabelV2
extends Label

@export var placement: BuildingPlacementV2
@export var economy: WorldEconomyV2


func _ready() -> void:
	text = "Placement: no tile selected"

	if placement != null:
		bind_placement(placement)

	if economy != null and not economy.resources_changed.is_connected(_refresh_from_current):
		economy.resources_changed.connect(_refresh_from_current)


func bind_placement(target: BuildingPlacementV2) -> void:
	if target == null:
		return

	if not target.placement_changed.is_connected(_on_placement_changed):
		target.placement_changed.connect(_on_placement_changed)

	if not target.building_placed.is_connected(_on_building_placed):
		target.building_placed.connect(_on_building_placed)

	if not target.placement_failed.is_connected(_on_placement_failed):
		target.placement_failed.connect(_on_placement_failed)


func _refresh_from_current() -> void:
	if placement != null:
		_on_placement_changed(placement.current_tile, placement.current_result)


func _on_placement_changed(tile: WorldTile, result: PlacementRulesV2.PlacementResult) -> void:
	if tile == null:
		text = "Placement: no tile selected"
		return

	var status := "INVALID"
	var reason := "No result"

	if result != null:
		status = "VALID" if result.valid else "INVALID"
		reason = result.reason

	var definition_text := "No building"
	if placement != null and placement.active_definition != null:
		var def := placement.active_definition
		definition_text = (
			"%s\n" % [def.display_name]
			+ "Category: %s\n" % [BuildingDefinition.category_name(def.category)]
			+ "Cost: %s\n" % [def.cost_summary()]
			+ "Produces: %s\n" % [def.production_summary()]
			+ "Footprint radius: %d" % [def.footprint_radius]
		)

	var economy_text := ""
	if economy != null:
		economy_text = "\n\n" + economy.summary()

	text = (
		"Building: %s\n\n" % [definition_text]
		+ "Placement: %s\n" % [status]
		+ "Reason: %s\n" % [reason]
		+ "Right click to place"
		+ economy_text
	)


func _on_building_placed(building: PlacedBuildingV2, tile: WorldTile) -> void:
	var economy_text := ""
	if economy != null:
		economy_text = "\n\n" + economy.summary()

	text = (
		"Placed: %s\n" % [building.get_display_name()]
		+ "Coord: %s\n" % [str(tile.coord)]
		+ "Occupied tiles: %d" % [building.occupied_coords.size()]
		+ economy_text
	)


func _on_placement_failed(tile: WorldTile, reason: String) -> void:
	text = (
		"Placement failed\n"
		+ "Reason: %s" % [reason]
	)
