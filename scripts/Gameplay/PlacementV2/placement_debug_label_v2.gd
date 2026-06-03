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
	if not target.placement_state_changed.is_connected(_on_placement_state_changed):
		target.placement_state_changed.connect(_on_placement_state_changed)

func _on_placement_state_changed(tile: WorldTile, allowed: bool, reason: String) -> void:
	if tile == null:
		text = "Placement: no tile selected"
		return

	text = "Placement: %s\nReason: %s\nRight click to place" % ["VALID" if allowed else "INVALID", reason]
