class_name PlacementDebugLabelV2
extends Label

@export var placement: BuildingPlacementV2


func _ready() -> void:
	text = "Placement: no tile selected"

	if placement != null:
		bind_placement(placement)


func bind_placement(target: BuildingPlacementV2) -> void:
	if target == null:
		return

	if not target.placement_changed.is_connected(_on_placement_changed):
		target.placement_changed.connect(_on_placement_changed)

	if not target.building_placed.is_connected(_on_building_placed):
		target.building_placed.connect(_on_building_placed)

	if not target.placement_failed.is_connected(_on_placement_failed):
		target.placement_failed.connect(_on_placement_failed)


func _on_placement_changed(tile: WorldTile, result: PlacementRulesV2.PlacementResult) -> void:
	if tile == null:
		text = "Placement: no tile selected"
		return

	var status := "INVALID"
	var reason := "No result"

	if result != null:
		status = "VALID" if result.valid else "INVALID"
		reason = result.reason

	text = (
		"Placement: %s\n" % [status]
		+ "Reason: %s\n" % [reason]
		+ "Right click to place"
	)


func _on_building_placed(building: PlacedBuildingV2, tile: WorldTile) -> void:
	text = (
		"Placed: %s\n" % [building.get_display_name()]
		+ "Coord: %s\n" % [str(tile.coord)]
		+ "Tile is now occupied"
	)


func _on_placement_failed(tile: WorldTile, reason: String) -> void:
	text = (
		"Placement failed\n"
		+ "Reason: %s" % [reason]
	)
