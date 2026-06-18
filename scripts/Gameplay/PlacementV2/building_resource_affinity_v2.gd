class_name BuildingResourceAffinityV2
extends Resource

@export var resource_node_id: StringName = &""
@export var display_name: String = ""

@export_group("Requirement")
@export var required: bool = false
@export_range(0, 8) var search_radius: int = 1

@export_group("Bonus")
@export_range(0.0, 10.0) var on_tile_multiplier: float = 1.5
@export_range(0.0, 10.0) var nearby_multiplier: float = 1.2


func effective_display_name() -> String:
	if display_name != "":
		return display_name

	return str(resource_node_id)


func summary() -> String:
	var prefix := "Prefers"

	if required:
		prefix = "Requires"

	return "%s %s within %d | x%.2f on tile, x%.2f nearby" % [
		prefix,
		effective_display_name(),
		search_radius,
		on_tile_multiplier,
		nearby_multiplier
	]
