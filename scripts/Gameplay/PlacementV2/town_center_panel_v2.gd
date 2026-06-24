class_name TownCenterPanelV2
extends MarginContainer

@export var picker: WorldTilePicker
@export var occupancy: WorldOccupancyV2
@export var town_center_manager: TownCenterManagerV2
@export var politics: TownPoliticsManagerV2
@export var status_label: Label
@export var active_policy_label: Label
@export var influence_label: Label
@export var consequence_label: Label
@export var policy_menu: PolicyMenuV2
@export var town_center_id: StringName = &"town_center"
@export var show_only_when_town_center_selected: bool = true
@export var hide_on_ready: bool = true

var selected_building: PlacedBuildingV2

func _ready() -> void:
	if hide_on_ready and show_only_when_town_center_selected: visible = false
	if picker != null and not picker.tile_selected.is_connected(_on_tile_selected): picker.tile_selected.connect(_on_tile_selected)
	if politics != null:
		if not politics.active_policy_changed.is_connected(_refresh): politics.active_policy_changed.connect(_refresh)
		if not politics.politics_changed.is_connected(_refresh): politics.politics_changed.connect(_refresh)
	if town_center_manager != null:
		if not town_center_manager.town_center_changed.is_connected(_refresh): town_center_manager.town_center_changed.connect(_refresh)
		if not town_center_manager.town_parameters_changed.is_connected(_refresh): town_center_manager.town_parameters_changed.connect(_refresh)
	if policy_menu != null and politics != null: policy_menu.politics = politics
	_refresh()

func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	selected_building = _building_from_tile(tile)
	if show_only_when_town_center_selected: visible = _is_selected_town_center()
	_refresh()

func open_panel() -> void:
	visible = true; _refresh()
func close_panel() -> void:
	visible = false
func toggle_panel() -> void:
	visible = not visible; _refresh()

func _refresh(_arg = null) -> void:
	if status_label != null: status_label.text = politics.get_status_summary() if politics != null else "Politics missing"
	if active_policy_label != null:
		active_policy_label.text = "Active policy: none" if politics == null or politics.active_policy == null else "Active policy: %s\n%s" % [politics.active_policy.display_name, politics.active_policy.full_summary()]
	if influence_label != null: influence_label.text = town_center_manager.get_town_summary() if town_center_manager != null else "Town manager missing"
	if consequence_label != null: consequence_label.text = politics.get_consequence_summary() if politics != null else ""

func _is_selected_town_center() -> bool:
	return selected_building != null and selected_building.definition != null and selected_building.definition.id == town_center_id

func _building_from_tile(tile: WorldTile) -> PlacedBuildingV2:
	if tile == null or occupancy == null: return null
	var occupant := occupancy.get_occupant(tile)
	if occupant == null: return null
	if occupant is PlacedBuildingV2: return occupant as PlacedBuildingV2
	var node := occupant as Node
	while node != null:
		if node is PlacedBuildingV2: return node as PlacedBuildingV2
		node = node.get_parent()
	return null
