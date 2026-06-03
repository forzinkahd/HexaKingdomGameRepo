class_name BuildingPlacementV2
extends Node

signal building_placed(tile: WorldTile, definition: BuildingDefinition, instance: Node3D)
signal placement_state_changed(tile: WorldTile, allowed: bool, reason: String)

@export var picker: WorldTilePicker
@export var preview: BuildingPreviewV2
@export var building_root: Node3D
@export var active_definition: BuildingDefinition
@export var enabled: bool = true
@export var place_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var print_debug: bool = true

var selected_tile: WorldTile
var selected_visual_node: Node3D
var occupied_coords: Dictionary = {}
var last_result: PlacementRulesV2.PlacementResult


func _ready() -> void:
	if building_root == null:
		building_root = Node3D.new()
		building_root.name = "PlacedBuildings"
		add_child(building_root)

	if preview != null:
		preview.set_definition(active_definition)

	if picker != null:
		bind_picker(picker)


func bind_picker(target_picker: WorldTilePicker) -> void:
	if target_picker == null:
		return

	if not target_picker.tile_selected.is_connected(_on_tile_selected):
		target_picker.tile_selected.connect(_on_tile_selected)


func set_building_definition(definition: BuildingDefinition) -> void:
	active_definition = definition
	if preview != null:
		preview.set_definition(active_definition)
	_update_preview()


func _input(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == place_button and mb.pressed:
			attempt_place_selected_tile()
			get_viewport().set_input_as_handled()


func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	selected_tile = tile
	selected_visual_node = visual_node
	_update_preview()


func _update_preview() -> void:
	last_result = PlacementRulesV2.can_place(selected_tile, active_definition, occupied_coords)

	if preview != null:
		preview.show_for_tile(selected_tile, selected_visual_node, last_result.allowed)

	placement_state_changed.emit(selected_tile, last_result.allowed, last_result.reason)


func attempt_place_selected_tile() -> bool:
	last_result = PlacementRulesV2.can_place(selected_tile, active_definition, occupied_coords)

	if not last_result.allowed:
		if print_debug:
			print("Placement rejected: ", last_result.reason)
		placement_state_changed.emit(selected_tile, false, last_result.reason)
		_update_preview()
		return false

	var instance := _create_building_instance()
	if instance == null:
		if print_debug:
			print("Placement rejected: building scene could not be instantiated")
		return false

	var offset := active_definition.y_offset if active_definition != null else 0.12
	var base_position := selected_tile.world_position
	if selected_visual_node != null:
		base_position = selected_visual_node.global_position

	instance.global_position = base_position + Vector3.UP * offset
	building_root.add_child(instance)

	occupied_coords[selected_tile.coord] = instance
	selected_tile.buildable = false

	if print_debug:
		print("Placed building '", active_definition.display_name if active_definition != null else "Unknown", "' at ", selected_tile.coord)

	building_placed.emit(selected_tile, active_definition, instance)
	_update_preview()
	return true


func _create_building_instance() -> Node3D:
	if active_definition != null and active_definition.scene != null:
		var node := active_definition.scene.instantiate()
		if node is Node3D:
			return node as Node3D
		node.queue_free()

	return _create_fallback_building()


func _create_fallback_building() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackBuilding"

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.65, 0.65, 0.65)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3.UP * 0.325

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.45, 0.25)
	mesh_instance.material_override = mat

	root.add_child(mesh_instance)
	return root
