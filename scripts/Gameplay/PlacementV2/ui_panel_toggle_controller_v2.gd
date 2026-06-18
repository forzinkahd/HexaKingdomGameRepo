class_name UIPanelToggleControllerV2
extends Node

@export_group("Panels")
@export var build_menu_panel: Control
@export var town_info_panel: Control
@export var selected_building_panel: Control
@export var production_panel: Control
@export var registry_panel: Control

@export_group("World Overlays")
@export var town_influence_overlay: Node3D
@export var resource_nodes_root: Node3D

@export_group("Initial Visibility")
@export var build_menu_visible_on_ready: bool = true
@export var town_info_visible_on_ready: bool = true
@export var selected_building_visible_on_ready: bool = true
@export var production_visible_on_ready: bool = true
@export var registry_visible_on_ready: bool = false
@export var town_influence_visible_on_ready: bool = true
@export var resource_nodes_visible_on_ready: bool = true

@export_group("Input Actions")
@export var toggle_build_menu_action: StringName = &"ToggleBuildMenu"
@export var toggle_town_info_action: StringName = &"ToggleTownInfoPanel"
@export var toggle_selected_building_action: StringName = &"ToggleSelectedBuildingPanel"
@export var toggle_production_action: StringName = &"ToggleProductionPanel"
@export var toggle_registry_action: StringName = &"ToggleRegistryPanel"
@export var toggle_town_influence_action: StringName = &"ToggleTownInfluenceOverlay"
@export var toggle_resource_nodes_action: StringName = &"ToggleResourceNodes"
@export var toggle_all_debug_action: StringName = &"ToggleAllDebugPanels"

@export_group("Behavior")
@export var print_debug: bool = false

var _debug_panels_visible: bool = true


func _ready() -> void:
	_apply_initial_visibility()


func _input(event: InputEvent) -> void:
	if _action_pressed(event, toggle_build_menu_action):
		_toggle_control(build_menu_panel, "Build menu")
		return

	if _action_pressed(event, toggle_town_info_action):
		_toggle_control(town_info_panel, "Town info panel")
		return

	if _action_pressed(event, toggle_selected_building_action):
		_toggle_control(selected_building_panel, "Selected building panel")
		return

	if _action_pressed(event, toggle_production_action):
		_toggle_control(production_panel, "Production panel")
		return

	if _action_pressed(event, toggle_registry_action):
		_toggle_control(registry_panel, "Registry panel")
		return

	if _action_pressed(event, toggle_town_influence_action):
		_toggle_node3d(town_influence_overlay, "Town influence overlay")
		return

	if _action_pressed(event, toggle_resource_nodes_action):
		_toggle_node3d(resource_nodes_root, "Resource nodes")
		return

	if _action_pressed(event, toggle_all_debug_action):
		_toggle_all_debug_panels()
		return


func show_all_panels() -> void:
	_set_control_visible(build_menu_panel, true)
	_set_control_visible(town_info_panel, true)
	_set_control_visible(selected_building_panel, true)
	_set_control_visible(production_panel, true)
	_set_control_visible(registry_panel, true)
	_set_node3d_visible(town_influence_overlay, true)
	_set_node3d_visible(resource_nodes_root, true)
	_debug_panels_visible = true


func hide_all_debug_panels() -> void:
	# Keep build menu visible by default; it is gameplay UI, not pure debug UI.
	_set_control_visible(town_info_panel, false)
	_set_control_visible(selected_building_panel, false)
	_set_control_visible(production_panel, false)
	_set_control_visible(registry_panel, false)
	_set_node3d_visible(town_influence_overlay, false)
	_debug_panels_visible = false


func toggle_build_menu() -> void:
	_toggle_control(build_menu_panel, "Build menu")


func toggle_town_info_panel() -> void:
	_toggle_control(town_info_panel, "Town info panel")


func toggle_selected_building_panel() -> void:
	_toggle_control(selected_building_panel, "Selected building panel")


func toggle_production_panel() -> void:
	_toggle_control(production_panel, "Production panel")


func toggle_registry_panel() -> void:
	_toggle_control(registry_panel, "Registry panel")


func toggle_town_influence_overlay() -> void:
	_toggle_node3d(town_influence_overlay, "Town influence overlay")


func toggle_resource_nodes() -> void:
	_toggle_node3d(resource_nodes_root, "Resource nodes")


func _apply_initial_visibility() -> void:
	_set_control_visible(build_menu_panel, build_menu_visible_on_ready)
	_set_control_visible(town_info_panel, town_info_visible_on_ready)
	_set_control_visible(selected_building_panel, selected_building_visible_on_ready)
	_set_control_visible(production_panel, production_visible_on_ready)
	_set_control_visible(registry_panel, registry_visible_on_ready)
	_set_node3d_visible(town_influence_overlay, town_influence_visible_on_ready)
	_set_node3d_visible(resource_nodes_root, resource_nodes_visible_on_ready)


func _toggle_all_debug_panels() -> void:
	_debug_panels_visible = not _debug_panels_visible

	_set_control_visible(town_info_panel, _debug_panels_visible)
	_set_control_visible(selected_building_panel, _debug_panels_visible)
	_set_control_visible(production_panel, _debug_panels_visible)
	_set_control_visible(registry_panel, _debug_panels_visible)
	_set_node3d_visible(town_influence_overlay, _debug_panels_visible)

	if print_debug:
		print("Debug panels visible: ", _debug_panels_visible)


func _toggle_control(panel: Control, label: String) -> void:
	if panel == null:
		if print_debug:
			print("UIPanelToggleControllerV2: missing ", label)
		return

	panel.visible = not panel.visible

	if print_debug:
		print(label, " visible: ", panel.visible)


func _toggle_node3d(node: Node3D, label: String) -> void:
	if node == null:
		if print_debug:
			print("UIPanelToggleControllerV2: missing ", label)
		return

	node.visible = not node.visible

	if print_debug:
		print(label, " visible: ", node.visible)


func _set_control_visible(panel: Control, value: bool) -> void:
	if panel == null:
		return

	panel.visible = value


func _set_node3d_visible(node: Node3D, value: bool) -> void:
	if node == null:
		return

	node.visible = value


func _action_pressed(event: InputEvent, action_name: StringName) -> bool:
	if action_name == &"":
		return false

	if not InputMap.has_action(action_name):
		return false

	return event.is_action_pressed(action_name)
