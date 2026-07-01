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
@export var print_debug: bool = true

@export_group("Roads")
@export var road_network: RoadNetworkV2

var _pending_load_data: Dictionary = {}
var _world_ready: bool = false
var _waiting_for_load_world_regeneration: bool = false


signal load_started
signal load_finished


func _ready() -> void:
	add_to_group("game_save_controller")
	_find_missing_references()
	_connect_world_ready_signal()

	if SaveGameManagerV2.load_requested:
		_pending_load_data = SaveGameManagerV2.consume_pending_loaded_data()
		if print_debug:
			print("GameSaveControllerV2: pending load received from menu.")
		call_deferred("_start_pending_load_from_menu")


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


func save_game() -> bool:
	var data := collect_save_data()
	return SaveGameManagerV2.save_to_disk(data, save_path)


func load_game() -> bool:
	var data := SaveGameManagerV2.load_from_disk(save_path)
	if data.is_empty():
		return false

	apply_save_data(data)
	return true


func collect_save_data() -> Dictionary:
	var data: Dictionary = {
		"version": SaveGameManagerV2.SAVE_VERSION,
		"map": _collect_map_save_data(),
		"resources": _collect_resource_save_data(),
		"placed_buildings": _collect_building_save_data(),
		"politics": _collect_politics_save_data(),
		"goals": _collect_goals_save_data(),
		"roads": _collect_road_save_data()
	}

	if print_debug:
		print("GameSaveControllerV2: collected save data. seed=", data["map"].get("seed", 0), " buildings=", data["placed_buildings"].size())

	return data


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	load_started.emit()
	
	var saved_seed := _saved_seed_from_data(data)

	if saved_seed != 0 and world_generator != null:
		var current_seed := _current_world_seed()

		if current_seed != saved_seed:
			if _regenerate_world_for_load(saved_seed, data):
				return

			push_warning("GameSaveControllerV2: could not regenerate world from seed. Loading onto current map.")

	_apply_save_data_after_world_ready(data)


func notify_world_ready() -> void:
	_world_ready = true

	if print_debug:
		print("GameSaveControllerV2: world ready.")

	if _waiting_for_load_world_regeneration and not _pending_load_data.is_empty():
		call_deferred("_apply_pending_load_after_world_ready")


func _apply_pending_load_after_world_ready() -> void:
	# Wait one extra frame so old queued-free nodes are gone and
	# new Node3D global transforms are stable.
	await get_tree().process_frame
	await get_tree().process_frame

	if _pending_load_data.is_empty():
		return

	var data := _pending_load_data
	_pending_load_data = {}
	_waiting_for_load_world_regeneration = false

	if print_debug:
		print("GameSaveControllerV2: applying pending load after deferred world regeneration.")

	_apply_save_data_after_world_ready(data)


func _start_pending_load_from_menu() -> void:
	if _pending_load_data.is_empty():
		return

	var data := _pending_load_data
	_pending_load_data = {}
	apply_save_data(data)


func _regenerate_world_for_load(saved_seed: int, data: Dictionary) -> bool:
	if world_generator == null:
		return false

	if not world_generator.has_method("generate_world_with_seed"):
		push_warning("GameSaveControllerV2: world_generator needs generate_world_with_seed(seed_value).")
		return false

	if placement != null and placement.has_method("prepare_for_load"):
		placement.prepare_for_load()

	_pending_load_data = data.duplicate(true)
	_world_ready = false
	_waiting_for_load_world_regeneration = true

	if print_debug:
		print("GameSaveControllerV2: regenerating world from saved seed=", saved_seed)

	world_generator.call("generate_world_with_seed", saved_seed)
	return true


func _apply_save_data_after_world_ready(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	if print_debug:
		print("GameSaveControllerV2: applying save data.")
	
	load_started.emit()
	
	if goals_manager != null and goals_manager.has_method("prepare_for_load"):
		goals_manager.prepare_for_load()
	
	if placement != null and placement.has_method("prepare_for_load"):
		placement.prepare_for_load()
	
	# Load saved goal flags first so restored buildings cannot re-complete old goals.
	_apply_goals_save_data(data.get("goals", {}))
	
	# Restore saved resources before and after reconstruction.
	_apply_resource_save_data(data.get("resources", {}))
	
	_apply_road_save_data(data.get("roads", []))
	
	# Restore world entities.
	_apply_building_save_data(data.get("placed_buildings", []))
	
	# Restore policy after buildings/registry exist.
	_apply_politics_save_data(data.get("politics", {}))
	
	# Final resource override. This cancels accidental rewards during reconstruction.
	_apply_resource_save_data(data.get("resources", {}))
	
	if print_debug:
		print("GameSaveControllerV2: save data applied.")
	
	call_deferred("_finish_load")


func _finish_load() -> void:
	load_finished.emit()


func _find_missing_references() -> void:
	if world_generator == null:
		world_generator = get_tree().get_first_node_in_group("world_gen_controller")
	
	if economy == null:
		economy = get_tree().get_first_node_in_group("world_economy") as WorldEconomyV2
	
	if registry == null:
		registry = get_tree().get_first_node_in_group("building_registry") as BuildingRegistryV2
	
	if placement == null:
		placement = get_tree().get_first_node_in_group("building_placement") as BuildingPlacementV2
	
	if catalog == null:
		catalog = get_tree().get_first_node_in_group("building_catalog") as BuildingCatalogV2
	
	if politics == null:
		politics = get_tree().get_first_node_in_group("town_politics_manager") as TownPoliticsManagerV2
	
	if goals_manager == null:
		goals_manager = get_tree().get_first_node_in_group("settlement_goals_manager") as SettlementGoalsManagerV2
	
	if road_network == null:
		road_network = get_tree().get_first_node_in_group("road_network") as RoadNetworkV2


func _connect_world_ready_signal() -> void:
	if world_generator == null:
		call_deferred("notify_world_ready")
		return

	if world_generator.has_signal("world_generated"):
		if not world_generator.world_generated.is_connected(_on_world_generated):
			world_generator.world_generated.connect(_on_world_generated)
	else:
		push_warning("GameSaveControllerV2: world_generator has no world_generated signal.")
		call_deferred("notify_world_ready")


func _on_world_generated(_arg = null) -> void:
	notify_world_ready()


func _saved_seed_from_data(data: Dictionary) -> int:
	var map_data: Dictionary = data.get("map", {})
	return int(map_data.get("seed", 0))


func _current_world_seed() -> int:
	if world_generator == null:
		return 0

	var direct_seed = world_generator.get("current_seed")
	if direct_seed != null:
		return int(direct_seed)

	var current_map = world_generator.get("current_map")
	if current_map != null:
		var map_seed = current_map.get("seed")
		if map_seed != null:
			return int(map_seed)

	var current_settings = world_generator.get("current_settings")
	if current_settings != null:
		var settings_seed = current_settings.get("map_seed")
		if settings_seed != null:
			return int(settings_seed)

	return 0


func _collect_map_save_data() -> Dictionary:
	var seed_value := _current_world_seed()
	if print_debug:
		print("GameSaveControllerV2: saving map seed=", seed_value)
	return {"seed": seed_value}


func _collect_resource_save_data() -> Dictionary:
	if economy == null:
		return {}
	if economy.has_method("get_save_data"):
		return economy.get_save_data()
	return {
		"wood": _get_economy_amount(BuildingDefinition.ProducedResource.WOOD),
		"stone": _get_economy_amount(BuildingDefinition.ProducedResource.STONE),
		"food": _get_economy_amount(BuildingDefinition.ProducedResource.FOOD),
		"gold": _get_economy_amount(BuildingDefinition.ProducedResource.GOLD)
	}


func _apply_resource_save_data(data: Dictionary) -> void:
	if economy == null:
		push_warning("GameSaveControllerV2: economy missing, cannot load resources.")
		return
	if economy.has_method("load_save_data"):
		economy.load_save_data(data)
		return
	_set_economy_amount(BuildingDefinition.ProducedResource.WOOD, int(data.get("wood", 0)))
	_set_economy_amount(BuildingDefinition.ProducedResource.STONE, int(data.get("stone", 0)))
	_set_economy_amount(BuildingDefinition.ProducedResource.FOOD, int(data.get("food", 0)))
	_set_economy_amount(BuildingDefinition.ProducedResource.GOLD, int(data.get("gold", 0)))


func _collect_building_save_data() -> Array:
	if registry == null:
		return []
	if registry.has_method("get_save_data"):
		return registry.get_save_data()
	return []


func _apply_building_save_data(buildings_data: Array) -> void:
	if placement == null:
		push_warning("GameSaveControllerV2: placement missing, cannot restore buildings.")
		return
	
	if placement.has_method("prepare_for_load"):
		placement.prepare_for_load()
	
	if placement.has_method("clear_placed_buildings"):
		placement.clear_placed_buildings()
	
	for entry in buildings_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var building_id := StringName(str(entry.get("building_id", "")))
		var coord := Vector2i(int(entry.get("coord_x", 0)), int(entry.get("coord_y", 0)))
		if placement.has_method("place_building_from_save"):
			placement.place_building_from_save(building_id, coord)
		else:
			push_warning("GameSaveControllerV2: placement has no place_building_from_save().")
			return


func _collect_politics_save_data() -> Dictionary:
	if politics == null:
		return {}
	if politics.has_method("get_save_data"):
		return politics.get_save_data()
	return {}


func _apply_politics_save_data(data: Dictionary) -> void:
	if politics != null and politics.has_method("load_save_data"):
		politics.load_save_data(data)


func _collect_goals_save_data() -> Dictionary:
	if goals_manager == null:
		return {}
	if goals_manager.has_method("get_save_data"):
		return goals_manager.get_save_data()
	return {}


func _apply_goals_save_data(data: Dictionary) -> void:
	if goals_manager != null and goals_manager.has_method("load_save_data"):
		goals_manager.load_save_data(data)


func _collect_road_save_data() -> Array:
	if road_network == null:
		return []
	
	if road_network.has_method("get_save_data"):
		return road_network.get_save_data()
	
	return []


func _apply_road_save_data(data: Array) -> void:
	if road_network == null:
		return
	
	if road_network.has_method("load_save_data"):
		road_network.load_save_data(data)


func _get_economy_amount(resource: BuildingDefinition.ProducedResource) -> int:
	if economy == null:
		return 0
	if economy.has_method("get_resource_amount"):
		return int(economy.get_resource_amount(resource))
	if economy.has_method("get_amount"):
		return int(economy.get_amount(resource))
	return int(economy.get(_resource_property_name(resource)))


func _set_economy_amount(resource: BuildingDefinition.ProducedResource, amount: int) -> void:
	if economy == null:
		return
	if economy.has_method("set_resource"):
		economy.set_resource(resource, amount)
		return
	var property_name := _resource_property_name(resource)
	if property_name != &"":
		economy.set(property_name, amount)
	if economy.has_signal("resources_changed"):
		economy.emit_signal("resources_changed")


func _resource_property_name(resource: BuildingDefinition.ProducedResource) -> StringName:
	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			return &"wood"
		BuildingDefinition.ProducedResource.STONE:
			return &"stone"
		BuildingDefinition.ProducedResource.FOOD:
			return &"food"
		BuildingDefinition.ProducedResource.GOLD:
			return &"gold"
		_:
			return &""
