class_name BuildMenuV2
extends Control

@export var catalog: BuildingCatalogV2
@export var placement: BuildingPlacementV2
@export var economy: WorldEconomyV2
@export var registry: BuildingRegistryV2
@export var button_container: Container

@export_group("Tabs")
@export var use_category_tabs: bool = true
@export var tab_container: TabContainer
@export var create_missing_category_tabs: bool = true
@export var show_empty_category_tabs: bool = false
@export var auto_switch_to_selected_tab: bool = true

@export_group("Buttons")
@export var button_scene: PackedScene
@export var fallback_button_min_size: Vector2 = Vector2(220.0, 96.0)

@export_group("Behavior")
@export var rebuild_on_ready: bool = true
@export var auto_connect_catalog_to_placement: bool = true
@export var auto_use_placement_economy: bool = true
@export var auto_select_first_available: bool = true

var _buttons_by_definition: Dictionary = {}
var _tab_content_by_category: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	if economy == null and auto_use_placement_economy and placement != null:
		economy = placement.economy

	if registry == null:
		registry = get_node_or_null("../BuildingRegistryV2") as BuildingRegistryV2

	_setup_containers()
	_connect_catalog()
	_connect_economy()
	_connect_registry()

	if rebuild_on_ready:
		_rebuild_buttons()

	if auto_select_first_available and catalog != null:
		_select_first_available_catalog_entry_if_needed()

	if catalog != null:
		_on_active_building_changed(catalog.get_active_building())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _setup_containers() -> void:
	if use_category_tabs:
		if tab_container == null:
			tab_container = _find_or_create_tab_container()

		if tab_container != null:
			tab_container.mouse_filter = Control.MOUSE_FILTER_STOP
			return

	if button_container == null:
		push_warning("BuildMenuV2: no button_container assigned. Assign VBoxContainer or enable tabs.")


func _find_or_create_tab_container() -> TabContainer:
	for child in get_children():
		if child is TabContainer:
			return child as TabContainer

	if not create_missing_category_tabs:
		return null

	var tabs := TabContainer.new()
	tabs.name = "BuildCategoryTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	return tabs


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


func _connect_registry() -> void:
	if registry == null:
		return

	if not registry.registry_changed.is_connected(_on_registry_changed):
		registry.registry_changed.connect(_on_registry_changed)


func _on_registry_changed() -> void:
	_refresh_buttons()

	if auto_select_first_available:
		_select_first_available_catalog_entry_if_needed()


func _rebuild_buttons() -> void:
	_clear_menu()

	if catalog == null:
		push_warning("BuildMenuV2: no BuildingCatalogV2 assigned.")
		return

	if use_category_tabs and tab_container != null:
		_rebuild_tabbed_buttons()
	else:
		_rebuild_flat_buttons()

	_update_selected_buttons()
	_refresh_buttons()


func _clear_menu() -> void:
	_buttons_by_definition.clear()
	_tab_content_by_category.clear()

	if use_category_tabs and tab_container != null:
		for child in tab_container.get_children():
			child.queue_free()
		return

	if button_container != null:
		for child in button_container.get_children():
			child.queue_free()


func _rebuild_tabbed_buttons() -> void:
	_create_category_tabs_from_catalog()

	for definition in catalog.get_buildings():
		if definition == null:
			continue

		var button := _create_button(definition)
		var category := definition.category
		var category_name := BuildingDefinition.category_name(category)
		var container := _get_or_create_category_container(category, category_name)

		container.add_child(button)
		_buttons_by_definition[definition] = button

	_remove_empty_category_tabs()


func _rebuild_flat_buttons() -> void:
	if button_container == null:
		push_warning("BuildMenuV2: no button_container assigned.")
		return

	button_container.mouse_filter = Control.MOUSE_FILTER_PASS

	for definition in catalog.get_buildings():
		var button := _create_button(definition)
		button_container.add_child(button)
		_buttons_by_definition[definition] = button


func _create_category_tabs_from_catalog() -> void:
	for definition in catalog.get_buildings():
		if definition == null:
			continue

		_get_or_create_category_container(
			definition.category,
			BuildingDefinition.category_name(definition.category)
		)


func _get_or_create_category_container(category: int, category_name: String) -> VBoxContainer:
	if _tab_content_by_category.has(category):
		return _tab_content_by_category[category] as VBoxContainer

	var scroll := ScrollContainer.new()
	scroll.name = category_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var container := VBoxContainer.new()
	container.name = "%sButtons" % [category_name]
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_theme_constant_override("separation", 6)

	scroll.add_child(container)
	tab_container.add_child(scroll)

	_tab_content_by_category[category] = container
	return container


func _remove_empty_category_tabs() -> void:
	if show_empty_category_tabs:
		return

	for scroll in tab_container.get_children():
		if not (scroll is ScrollContainer):
			continue

		if scroll.get_child_count() == 0:
			scroll.queue_free()
			continue

		var container := scroll.get_child(0)

		if container is VBoxContainer and container.get_child_count() == 0:
			scroll.queue_free()


func _create_button(definition: BuildingDefinition) -> BuildMenuButtonV2:
	var button: BuildMenuButtonV2 = null

	if button_scene != null:
		button = button_scene.instantiate() as BuildMenuButtonV2

	if button == null:
		button = BuildMenuButtonV2.new()
		button.custom_minimum_size = fallback_button_min_size
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.setup(definition, economy, registry)

	if not button.building_pressed.is_connected(_on_button_building_pressed):
		button.building_pressed.connect(_on_button_building_pressed)

	return button


func _on_button_building_pressed(definition: BuildingDefinition) -> void:
	if definition == null:
		return

	if not _is_definition_selectable(definition):
		return

	if catalog != null:
		catalog.set_active_building(definition)
	else:
		_on_active_building_changed(definition)


func _on_active_building_changed(definition: BuildingDefinition) -> void:
	if definition != null and not _is_definition_selectable(definition):
		if auto_select_first_available:
			_select_first_available_catalog_entry_if_needed()
			return

	if auto_connect_catalog_to_placement and placement != null:
		placement.set_active_definition(definition)

	_update_selected_buttons()

	if auto_switch_to_selected_tab and definition != null:
		_switch_to_category_tab(definition.category)


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
			button.set_registry(registry)
			button.refresh_availability()


func _select_first_available_catalog_entry_if_needed() -> void:
	if catalog == null:
		return

	var active := catalog.get_active_building()

	if active != null and _is_definition_selectable(active):
		return

	for definition in catalog.get_buildings():
		if _is_definition_selectable(definition):
			catalog.set_active_building(definition)
			return

	if auto_connect_catalog_to_placement and placement != null:
		placement.set_active_definition(null)


func _is_definition_selectable(definition: BuildingDefinition) -> bool:
	if definition == null:
		return false

	if registry != null:
		if not registry.is_unlocked(definition):
			return false

		if registry.is_unique_limit_reached(definition):
			return false

	if economy != null and not economy.can_afford(definition):
		return false

	return true


func _switch_to_category_tab(category: int) -> void:
	if not use_category_tabs or tab_container == null:
		return

	var container :Variant = _tab_content_by_category.get(category, null)

	if container == null:
		return

	var scroll :Variant = container.get_parent()

	if scroll == null:
		return

	var tab_index :Variant = scroll.get_index()

	if tab_index >= 0 and tab_index < tab_container.get_tab_count():
		tab_container.current_tab = tab_index
