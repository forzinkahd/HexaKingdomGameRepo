class_name BuildingPlacementV2
extends Node

signal placement_changed(tile: WorldTile, result: PlacementRulesV2.PlacementResult)
signal building_placed(building: PlacedBuildingV2, tile: WorldTile)
signal placement_failed(tile: WorldTile, reason: String)

@export var picker: WorldTilePicker
@export var preview: BuildingPreviewV2
@export var occupancy: WorldOccupancyV2
@export var building_root: Node3D
@export var active_definition: BuildingDefinition

@export var place_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var place_y_offset: float = 0.0
@export var print_debug: bool = false

var current_tile: WorldTile
var current_visual_node: Node3D
var current_result: PlacementRulesV2.PlacementResult


func _ready() -> void:
	if picker != null:
		picker.tile_selected.connect(_on_tile_selected)

	if occupancy == null:
		occupancy = get_node_or_null("../WorldOccupancyV2") as WorldOccupancyV2

	if building_root == null:
		building_root = Node3D.new()
		building_root.name = "PlacedBuildings"
		add_child(building_root)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == place_button and mb.pressed:
			if try_place_current():
				get_viewport().set_input_as_handled()


func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	current_tile = tile
	current_visual_node = visual_node
	_update_current_result()


func _update_current_result() -> void:
	current_result = PlacementRulesV2.validate(current_tile, active_definition, occupancy)

	if preview != null:
		preview.show_preview(current_tile, current_visual_node, active_definition, current_result.valid)

	placement_changed.emit(current_tile, current_result)


func try_place_current() -> bool:
	_update_current_result()

	if current_result == null or not current_result.valid:
		var reason := "Invalid placement"
		if current_result != null:
			reason = current_result.reason

		placement_failed.emit(current_tile, reason)

		if print_debug:
			print("Placement failed: ", reason)

		return false

	var building := _spawn_building(current_tile, active_definition)

	if building == null:
		placement_failed.emit(current_tile, "Could not spawn building")
		return false

	if occupancy != null:
		if not occupancy.occupy(current_tile, building):
			building.queue_free()
			placement_failed.emit(current_tile, "Tile already occupied")
			_update_current_result()
			return false

	building_placed.emit(building, current_tile)

	if print_debug:
		print("Placed building: ", building.get_display_name(), " at ", current_tile.coord)

	_update_current_result()
	return true


func _spawn_building(tile: WorldTile, definition: BuildingDefinition) -> PlacedBuildingV2:
	var root := PlacedBuildingV2.new()
	root.setup(definition, tile)

	var visual: Node3D = null

	if definition != null and definition.scene != null:
		visual = definition.scene.instantiate() as Node3D

	if visual == null:
		visual = _fallback_building_visual()

	root.add_child(visual)

	var base_position := tile.world_position

	if current_visual_node != null:
		base_position = current_visual_node.global_position

	root.global_position = base_position + Vector3.UP * place_y_offset

	if building_root != null:
		building_root.add_child(root)
	else:
		add_child(root)

	return root


func _fallback_building_visual() -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FallbackBuildingVisual"

	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 0.7)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3.UP * 0.35

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.5, 0.25)
	mesh_instance.material_override = mat

	return mesh_instance
