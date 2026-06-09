class_name TownCenterManagerV2
extends Node

signal town_center_changed(town_center: PlacedBuildingV2)
signal town_parameters_changed

@export var registry: BuildingRegistryV2
@export var town_center_id: StringName = &"town_center"

@export_group("Influence / Production")
@export_range(0, 64) var full_efficiency_radius: int = 4:
	set(value):
		full_efficiency_radius = value
		town_parameters_changed.emit()

@export_range(1, 128) var minimum_efficiency_radius: int = 14:
	set(value):
		minimum_efficiency_radius = max(value, full_efficiency_radius + 1)
		town_parameters_changed.emit()

@export_range(0.0, 1.0) var minimum_efficiency: float = 0.35:
	set(value):
		minimum_efficiency = clamp(value, 0.0, 1.0)
		town_parameters_changed.emit()

@export_group("Politics Placeholder")
@export_range(0, 100) var authority: int = 50:
	set(value):
		authority = clampi(value, 0, 100)
		town_parameters_changed.emit()

@export_range(0, 100) var stability: int = 50:
	set(value):
		stability = clampi(value, 0, 100)
		town_parameters_changed.emit()

@export_range(0, 100) var approval: int = 50:
	set(value):
		approval = clampi(value, 0, 100)
		town_parameters_changed.emit()

var town_center: PlacedBuildingV2


func _ready() -> void:
	if registry == null:
		registry = get_node_or_null("../BuildingRegistryV2") as BuildingRegistryV2

	if registry != null:
		if not registry.registry_changed.is_connected(_refresh_town_center):
			registry.registry_changed.connect(_refresh_town_center)

	_refresh_town_center()


func has_town_center() -> bool:
	return town_center != null and is_instance_valid(town_center)


func get_town_center_tile() -> WorldTile:
	if not has_town_center():
		return null

	return town_center.tile


func get_town_center_coord() -> Vector2i:
	var tile := get_town_center_tile()

	if tile == null:
		return Vector2i.ZERO

	return tile.coord


func get_distance_to_town_center(tile: WorldTile) -> int:
	if tile == null:
		return -1

	if not has_town_center():
		return -1

	return _hex_distance(tile.coord, get_town_center_coord())


func get_distance_to_town_center_coord(coord: Vector2i) -> int:
	if not has_town_center():
		return -1

	return _hex_distance(coord, get_town_center_coord())


func get_efficiency_for_tile(tile: WorldTile) -> float:
	if tile == null:
		return 1.0

	return get_efficiency_for_coord(tile.coord)


func get_efficiency_for_building(building: PlacedBuildingV2) -> float:
	if building == null or not is_instance_valid(building):
		return 1.0

	return get_efficiency_for_tile(building.tile)


func get_efficiency_for_coord(coord: Vector2i) -> float:
	if not has_town_center():
		return 1.0

	var distance := get_distance_to_town_center_coord(coord)

	if distance <= full_efficiency_radius:
		return 1.0

	if distance >= minimum_efficiency_radius:
		return minimum_efficiency

	var t := inverse_lerp(
		float(full_efficiency_radius),
		float(minimum_efficiency_radius),
		float(distance)
	)

	return lerpf(1.0, minimum_efficiency, clamp(t, 0.0, 1.0))


func get_efficiency_text_for_tile(tile: WorldTile) -> String:
	if tile == null:
		return "No tile"

	if not has_town_center():
		return "No town center placed"

	var distance := get_distance_to_town_center(tile)
	var efficiency := get_efficiency_for_tile(tile)

	if distance <= full_efficiency_radius:
		return "Town efficiency: 100%"

	return "Town efficiency: %d%% at distance %d" % [
		int(round(efficiency * 100.0)),
		distance
	]


func get_town_summary() -> String:
	if not has_town_center():
		return "No Town Center placed"

	var tile := get_town_center_tile()

	return "Town Center at %s | Full radius %d | Minimum %d%% at radius %d" % [
		str(tile.coord),
		full_efficiency_radius,
		int(round(minimum_efficiency * 100.0)),
		minimum_efficiency_radius
	]


func _refresh_town_center() -> void:
	var previous := town_center
	town_center = null

	if registry != null:
		town_center = registry.get_first_building_by_id(town_center_id)

	if previous != town_center:
		town_center_changed.emit(town_center)


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var aq := a.x
	var ar := a.y
	var bq := b.x
	var br := b.y

	var acube_x := aq
	var acube_z := ar
	var acube_y := -acube_x - acube_z

	var bcube_x := bq
	var bcube_z := br
	var bcube_y := -bcube_x - bcube_z

	return int(maxi(
		absi(acube_x - bcube_x),
		maxi(absi(acube_y - bcube_y), absi(acube_z - bcube_z))
	))
