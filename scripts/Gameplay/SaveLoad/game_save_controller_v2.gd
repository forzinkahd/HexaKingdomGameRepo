class_name GameSaveControllerV2
extends Node

@export var world_generator: Node
@export var economy: WorldEconomyV2
@export var registry: BuildingRegistryV2
@export var placement: BuildingPlacementV2
@export var catalog: BuildingCatalogV2
@export var politics: TownPoliticsManagerV2
@export var goals_manager: SettlementGoalsManagerV2

@export_group("Actions")
@export var save_action: StringName = &"Save"
@export var load_action: StringName = &"Load"
@export var enable_hotkeys: bool = true

@export_group("Behavior")
@export var save_path: String = "user://save_slot_1.json"
@export var load_after_world_ready: bool = true
@export var print_debug: bool = true

var _pending_load_data: Dictionary = {}
var _world_ready: bool = false


func _ready() -> void:
	add_to_group("game_save_controller")
	_find_missing_references()
	_connect_world_ready()
	if SaveGameManagerV2.load_requested:
		_pending_load_data = SaveGameManagerV2.consume_pending_loaded_data()
		if print_debug:
			print("GameSaveControllerV2: load requested from main menu.")
	if not _pending_load_data.is_empty() and not load_after_world_ready:
		apply_save_data(_pending_load_data)


func _input(event: InputEvent) -> void:
	if not enable_hotkeys:
		return
	if event.is_action_pressed(save_action):
		save_game()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(load_action):
		load_game()
		get_viewport().set_input_as_handled()
		return


func notify_world_ready() -> void:
	_world_ready = true
	if not _pending_load_data.is_empty():
		apply_save_data(_pending_load_data)
		_pending_load_data.clear()


func save_game() -> bool:
	return SaveGameManagerV2.save_to_disk(collect_save_data(), save_path)


func load_game() -> bool:
	var data := SaveGameManagerV2.load_from_disk(save_path)
	if data.is_empty():
		return false
	if load_after_world_ready and not _world_ready:
		_pending_load_data = data
		return true
	apply_save_data(data)
	return true


func collect_save_data() -> Dictionary:
	return {
		"version": SaveGameManagerV2.SAVE_VERSION,
		"map": _collect_map_save_data(),
		"resources": _collect_resource_save_data(),
		"placed_buildings": _collect_building_save_data(),
		"politics": _collect_politics_save_data(),
		"goals": _collect_goals_save_data()
	}


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	if print_debug:
		print("GameSaveControllerV2: applying save data.")
	_apply_resource_save_data(data.get("resources", {}))
	_apply_building_save_data(data.get("placed_buildings", []))
	_apply_politics_save_data(data.get("politics", {}))
	_apply_goals_save_data(data.get("goals", {}))
	if print_debug:
		print("GameSaveControllerV2: save data applied.")


func _find_missing_references() -> void:
	if economy == null: economy = get_tree().get_first_node_in_group("world_economy") as WorldEconomyV2
	if registry == null: registry = get_tree().get_first_node_in_group("building_registry") as BuildingRegistryV2
	if placement == null: placement = get_tree().get_first_node_in_group("building_placement") as BuildingPlacementV2
	if catalog == null: catalog = get_tree().get_first_node_in_group("building_catalog") as BuildingCatalogV2
	if politics == null: politics = get_tree().get_first_node_in_group("town_politics_manager") as TownPoliticsManagerV2
	if goals_manager == null: goals_manager = get_tree().get_first_node_in_group("settlement_goals_manager") as SettlementGoalsManagerV2


func _connect_world_ready() -> void:
	if world_generator == null:
		call_deferred("notify_world_ready")
		return
	if world_generator.has_signal("world_generated"):
		if not world_generator.world_generated.is_connected(_on_world_generated):
			world_generator.world_generated.connect(_on_world_generated)
	else:
		call_deferred("notify_world_ready")


func _on_world_generated(_arg = null) -> void:
	notify_world_ready()


func _collect_map_save_data() -> Dictionary:
	var seed_value := 0
	if world_generator != null:
		if "current_seed" in world_generator: seed_value = int(world_generator.current_seed)
		elif "seed" in world_generator: seed_value = int(world_generator.seed)
		elif "last_seed" in world_generator: seed_value = int(world_generator.last_seed)
	return {"seed": seed_value}


func _collect_resource_save_data() -> Dictionary:
	if economy == null: return {}
	if economy.has_method("get_save_data"): return economy.get_save_data()
	return {
		"wood": _get_economy_amount(BuildingDefinition.ProducedResource.WOOD),
		"stone": _get_economy_amount(BuildingDefinition.ProducedResource.STONE),
		"food": _get_economy_amount(BuildingDefinition.ProducedResource.FOOD),
		"gold": _get_economy_amount(BuildingDefinition.ProducedResource.GOLD)
	}


func _apply_resource_save_data(data: Dictionary) -> void:
	if economy == null: return
	if economy.has_method("load_save_data"):
		economy.load_save_data(data)
		return
	_set_economy_amount(BuildingDefinition.ProducedResource.WOOD, int(data.get("wood", 0)))
	_set_economy_amount(BuildingDefinition.ProducedResource.STONE, int(data.get("stone", 0)))
	_set_economy_amount(BuildingDefinition.ProducedResource.FOOD, int(data.get("food", 0)))
	_set_economy_amount(BuildingDefinition.ProducedResource.GOLD, int(data.get("gold", 0)))


func _collect_building_save_data() -> Array:
	if registry == null: return []
	if registry.has_method("get_save_data"): return registry.get_save_data()
	return []


func _apply_building_save_data(buildings_data: Array) -> void:
	if placement == null:
		push_warning("GameSaveControllerV2: placement missing, cannot restore buildings.")
		return
	if placement.has_method("clear_placed_buildings"):
		placement.clear_placed_buildings()
	for entry in buildings_data:
		if typeof(entry) != TYPE_DICTIONARY: continue
		var building_id := StringName(str(entry.get("building_id", "")))
		var coord := Vector2i(int(entry.get("coord_x", 0)), int(entry.get("coord_y", 0)))
		if placement.has_method("place_building_from_save"):
			placement.place_building_from_save(building_id, coord)
		else:
			push_warning("GameSaveControllerV2: placement has no place_building_from_save().")
			return


func _collect_politics_save_data() -> Dictionary:
	if politics == null: return {}
	if politics.has_method("get_save_data"): return politics.get_save_data()
	var active_policy_id := ""
	if politics.has_method("get_active_policy"):
		var policy = politics.get_active_policy()
		if policy != null: active_policy_id = str(policy.id)
	return {"active_policy_id": active_policy_id}


func _apply_politics_save_data(data: Dictionary) -> void:
	if politics == null: return
	if politics.has_method("load_save_data"):
		politics.load_save_data(data)
		return


func _collect_goals_save_data() -> Dictionary:
	if goals_manager == null: return {}
	if goals_manager.has_method("get_save_data"): return goals_manager.get_save_data()
	return {}


func _apply_goals_save_data(data: Dictionary) -> void:
	if goals_manager != null and goals_manager.has_method("load_save_data"):
		goals_manager.load_save_data(data)


func _get_economy_amount(resource: BuildingDefinition.ProducedResource) -> int:
	if economy == null: return 0
	if economy.has_method("get_resource_amount"): return int(economy.get_resource_amount(resource))
	if economy.has_method("get_amount"): return int(economy.get_amount(resource))
	return int(economy.get(_resource_property_name(resource)))


func _set_economy_amount(resource: BuildingDefinition.ProducedResource, amount: int) -> void:
	if economy == null: return
	if economy.has_method("set_resource"):
		economy.set_resource(resource, amount)
		return
	var property_name := _resource_property_name(resource)
	if property_name != &"": economy.set(property_name, amount)
	if economy.has_signal("resources_changed"): economy.emit_signal("resources_changed")


func _resource_property_name(resource: BuildingDefinition.ProducedResource) -> StringName:
	match resource:
		BuildingDefinition.ProducedResource.WOOD: return &"wood"
		BuildingDefinition.ProducedResource.STONE: return &"stone"
		BuildingDefinition.ProducedResource.FOOD: return &"food"
		BuildingDefinition.ProducedResource.GOLD: return &"gold"
		_: return &""
