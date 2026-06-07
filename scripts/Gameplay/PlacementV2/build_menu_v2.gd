class_name BuildMenuV2
extends Control

@export var catalog: BuildingCatalogV2
@export var placement: BuildingPlacementV2
@export var economy: WorldEconomyV2
@export var button_container: Container

@export var button_scene: PackedScene
@export var rebuild_on_ready: bool = true
@export var auto_connect_catalog_to_placement: bool = true
@export var auto_use_placement_economy: bool = true

@export_group("Fallback Button")
@export var fallback_button_min_size: Vector2 = Vector2(220.0, 88.0)

var _buttons_by_definition: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	if button_container == null:
		push_warning("BuildMenuV2: button_container is not assigned. Assign a VBoxContainer in the inspector.")
	else:
		button_container.mouse_filter = Control.MOUSE_FILTER_PASS

	if economy == null and auto_use_placement_economy and placement != null:
		economy = placement.economy

	_connect_catalog()
	_connect_economy()

	if rebuild_on_ready:
		_rebuild_buttons()

	if catalog != null:
		_on_active_building_changed(catalog.get_active_building())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _connect_catalog() -> void:
	if catalog == null:
		return

	if not catalog.catalog_changed.is_connected(_rebuild_buttons):
		catalog.catalog_changed.connect(_rebuild_buttons)

	if not catalog.active_building_changed.is_connected(_on_active_building_changed):
		catalog.active_building_changed.connect(_on_active_building_changed)


func _connect_economy() -> void:
	if economy == null:
		return

	if not economy.resources_changed.is_connected(_refresh_buttons):
		economy.resources_changed.connect(_refresh_buttons)


func _rebuild_buttons() -> void:
	if button_container == null:
		push_warning("BuildMenuV2: no button_container assigned.")
		return

	for child in button_container.get_children():
		child.queue_free()

	_buttons_by_definition.clear()

	if catalog == null:
		push_warning("BuildMenuV2: no BuildingCatalogV2 assigned.")
		return

	for definition in catalog.get_buildings():
		var button := _create_button(definition)
		button_container.add_child(button)
		_buttons_by_definition[definition] = button

	_update_selected_buttons()
	_refresh_buttons()


func _create_button(definition: BuildingDefinition) -> BuildMenuButtonV2:
	var button: BuildMenuButtonV2 = null

	if button_scene != null:
		button = button_scene.instantiate() as BuildMenuButtonV2

	if button == null:
		button = BuildMenuButtonV2.new()
		button.custom_minimum_size = fallback_button_min_size
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.setup(definition, economy)

	if not button.building_pressed.is_connected(_on_button_building_pressed):
		button.building_pressed.connect(_on_button_building_pressed)

	return button


func _on_button_building_pressed(definition: BuildingDefinition) -> void:
	if definition == null:
		return

	if economy != null and not economy.can_afford(definition):
		return

	if catalog != null:
		catalog.set_active_building(definition)
	else:
		_on_active_building_changed(definition)


func _on_active_building_changed(definition: BuildingDefinition) -> void:
	if auto_connect_catalog_to_placement and placement != null:
		placement.set_active_definition(definition)

	_update_selected_buttons()


func _update_selected_buttons() -> void:
	var active: BuildingDefinition = null

	if catalog != null:
		active = catalog.get_active_building()

	for definition in _buttons_by_definition.keys():
		var button := _buttons_by_definition[definition] as BuildMenuButtonV2

		if button != null:
			button.set_selected(definition == active)


func _refresh_buttons() -> void:
	for definition in _buttons_by_definition.keys():
		var button := _buttons_by_definition[definition] as BuildMenuButtonV2

		if button != null:
			button.set_economy(economy)
			button.refresh_affordability()
