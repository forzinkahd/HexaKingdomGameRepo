class_name TownInfluenceOverlayV2
extends Node3D

@export var world_gen_controller: WorldGenController
@export var town_center_manager: TownCenterManagerV2

@export_group("Display")
@export var overlay_visible: bool = true:
	set(value):
		overlay_visible = value
		visible = value
@export var rebuild_every_seconds: float = 0.5
@export var overlay_y_offset: float = 0.08
@export var overlay_thickness: float = 0.03
@export var overlay_hex_radius_factor: float = 0.42
@export var overlay_yaw_offset_degrees: float = 30.0

@export_group("Coverage")
@export var include_unbuildable_tiles: bool = false
@export var show_full_zone: bool = true
@export var show_falloff_zone: bool = true
@export var show_outside_penalty_zone: bool = false
@export var show_town_center_tile: bool = true

@export_group("Colors")
@export var town_center_color: Color = Color(0.25, 0.75, 1.0, 0.65)
@export var full_zone_color: Color = Color(0.25, 1.0, 0.35, 0.45)
@export var falloff_zone_color: Color = Color(1.0, 0.85, 0.2, 0.38)
@export var outside_zone_color: Color = Color(1.0, 0.35, 0.25, 0.25)

var _overlay_root: Node3D
var _observed_map: WorldMapData
var _elapsed: float = 0.0


func _ready() -> void:
	visible = overlay_visible

	if world_gen_controller == null:
		world_gen_controller = get_node_or_null("../WorldGenController") as WorldGenController

	if town_center_manager == null:
		town_center_manager = get_node_or_null("../TownCenterManagerV2") as TownCenterManagerV2

	if town_center_manager != null:
		if not town_center_manager.town_center_changed.is_connected(_on_overlay_relevant_changed):
			town_center_manager.town_center_changed.connect(_on_overlay_relevant_changed)

		if not town_center_manager.town_parameters_changed.is_connected(_on_overlay_relevant_changed):
			town_center_manager.town_parameters_changed.connect(_on_overlay_relevant_changed)

	_overlay_root = Node3D.new()
	_overlay_root.name = "TownInfluenceMarkers"
	add_child(_overlay_root)

	_rebuild_overlay()


func _process(delta: float) -> void:
	if not overlay_visible:
		return

	_elapsed += delta

	if _elapsed < rebuild_every_seconds:
		return

	_elapsed = 0.0

	var current_map := _current_map()
	if current_map != _observed_map:
		_rebuild_overlay()


func refresh_overlay() -> void:
	_rebuild_overlay()


func _on_overlay_relevant_changed(_arg = null) -> void:
	_rebuild_overlay()


func _rebuild_overlay() -> void:
	_clear_overlay()

	if not overlay_visible:
		return

	var current_map := _current_map()
	_observed_map = current_map

	if current_map == null:
		return

	if town_center_manager == null:
		return

	if not town_center_manager.has_town_center():
		return

	var settings := _current_settings()
	var tile_radius := 1.0
	var height_step := 1.0

	if settings != null:
		tile_radius = settings.tile_size
		height_step = settings.height_step

	for tile in current_map.tiles:
		if tile == null:
			continue

		if not include_unbuildable_tiles and not tile.buildable:
			continue

		var marker_color := _marker_color_for_tile(tile)
		if marker_color.a <= 0.001:
			continue

		var marker := _make_overlay_marker(tile_radius, marker_color)
		marker.position = Vector3(
			tile.world_position.x,
			float(tile.height_units) * height_step + overlay_y_offset,
			tile.world_position.z
		)
		marker.rotation.y = deg_to_rad(overlay_yaw_offset_degrees)
		_overlay_root.add_child(marker)


func _marker_color_for_tile(tile: WorldTile) -> Color:
	if tile == null or town_center_manager == null or not town_center_manager.has_town_center():
		return Color(0, 0, 0, 0)

	var town_tile := town_center_manager.get_town_center_tile()

	if show_town_center_tile and town_tile != null and tile.coord == town_tile.coord:
		return town_center_color

	var distance := town_center_manager.get_distance_to_town_center(tile)

	if distance < 0:
		return Color(0, 0, 0, 0)

	if show_full_zone and distance <= town_center_manager.full_efficiency_radius:
		return full_zone_color

	if show_falloff_zone and distance <= town_center_manager.minimum_efficiency_radius:
		return falloff_zone_color

	if show_outside_penalty_zone:
		return outside_zone_color

	return Color(0, 0, 0, 0)


func _make_overlay_marker(tile_radius: float, color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "InfluenceMarker"

	var mesh := CylinderMesh.new()
	mesh.top_radius = tile_radius * overlay_hex_radius_factor
	mesh.bottom_radius = tile_radius * overlay_hex_radius_factor
	mesh.height = overlay_thickness
	mesh.radial_segments = 6
	mesh.rings = 1

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.disable_receive_shadows = true

	marker.mesh = mesh
	marker.material_override = material
	return marker


func _clear_overlay() -> void:
	if _overlay_root == null:
		return

	for child in _overlay_root.get_children():
		child.queue_free()


func _current_map() -> WorldMapData:
	if world_gen_controller == null:
		return null

	return world_gen_controller.current_map


func _current_settings() -> GenerationSettingsV2:
	if world_gen_controller == null:
		return null

	return world_gen_controller.current_settings
