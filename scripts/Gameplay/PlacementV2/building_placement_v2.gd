class_name BuildingPlacementV2
extends Node

signal placement_changed(tile: WorldTile, result: PlacementRulesV2.PlacementResult)
signal building_placed(building: PlacedBuildingV2, tile: WorldTile)
signal placement_failed(tile: WorldTile, reason: String)

@export var picker: WorldTilePicker
@export var preview: BuildingPreviewV2
@export var occupancy: WorldOccupancyV2
@export var economy: WorldEconomyV2
@export var production: WorldProductionV2
@export var registry: BuildingRegistryV2
@export var resource_map: WorldResourceMapV2
@export var building_root: Node3D
@export var active_definition: BuildingDefinition
@export var catalog: BuildingCatalogV2

@export var place_button: MouseButton = MOUSE_BUTTON_RIGHT
@export var place_y_offset: float = 0.0
@export var print_debug: bool = false
@export var ignore_clicks_over_ui: bool = true

@export var world_visual_root: Node3D

var world_map: WorldMapData
var current_tile: WorldTile
var current_visual_node: Node3D
var current_result: PlacementRulesV2.PlacementResult


func _ready() -> void:
	add_to_group("building_placement")

	if picker != null:
		if not picker.tile_selected.is_connected(_on_tile_selected):
			picker.tile_selected.connect(_on_tile_selected)

	if occupancy == null:
		occupancy = get_node_or_null("../WorldOccupancyV2") as WorldOccupancyV2

	if economy == null:
		economy = get_node_or_null("../WorldEconomyV2") as WorldEconomyV2

	if production == null:
		production = get_node_or_null("../WorldProductionV2") as WorldProductionV2

	if registry == null:
		registry = get_node_or_null("../BuildingRegistryV2") as BuildingRegistryV2

	if resource_map == null:
		resource_map = get_node_or_null("../WorldResourceMapV2") as WorldResourceMapV2

	if catalog == null:
		catalog = get_node_or_null("../BuildingCatalogV2") as BuildingCatalogV2

	if building_root == null:
		building_root = Node3D.new()
		building_root.name = "PlacedBuildings"
		add_child(building_root)


func configure_world_map(source_world_map: WorldMapData) -> void:
	world_map = source_world_map
	_update_current_result()


func set_active_definition(definition: BuildingDefinition) -> void:
	active_definition = definition
	_update_current_result()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == place_button and mb.pressed:
			if ignore_clicks_over_ui and _is_pointer_over_ui():
				return

			if try_place_current():
				get_viewport().set_input_as_handled()


func _is_pointer_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()

	while hovered != null:
		if hovered.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true

		hovered = hovered.get_parent_control()

	return false


func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	current_tile = tile
	current_visual_node = visual_node
	_update_current_result()


func _update_current_result() -> void:
	current_result = PlacementRulesV2.validate(
		current_tile,
		active_definition,
		occupancy,
		economy,
		world_map,
		registry,
		resource_map
	)

	if preview != null:
		preview.show_preview(
			current_tile,
			current_visual_node,
			active_definition,
			current_result.valid,
			current_result.footprint_coords,
			world_map
		)

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

	if economy != null and not economy.spend_for(active_definition):
		var reason := economy.missing_cost_reason(active_definition)
		placement_failed.emit(current_tile, reason)
		_update_current_result()
		return false

	var building := _spawn_building(current_tile, active_definition, current_result.footprint_coords)

	if building == null:
		if economy != null:
			economy.refund_for(active_definition)

		placement_failed.emit(current_tile, "Could not spawn building")
		return false

	if occupancy != null:
		if not occupancy.occupy_coords(current_result.footprint_coords, building, current_tile):
			building.queue_free()

			if economy != null:
				economy.refund_for(active_definition)

			placement_failed.emit(current_tile, "Footprint overlaps occupied tile")
			_update_current_result()
			return false

	if production != null:
		production.register_building(building)

	if registry != null:
		registry.register_building(building)

	building_placed.emit(building, current_tile)

	if print_debug:
		print("Placed building: ", building.get_display_name(), " at ", current_tile.coord)

	_update_current_result()
	return true


func _spawn_building(
	tile: WorldTile,
	definition: BuildingDefinition,
	footprint_coords: Array[Vector2i]
) -> PlacedBuildingV2:
	if tile == null or definition == null:
		return null

	var root := PlacedBuildingV2.new()
	root.setup(definition, tile, footprint_coords)

	var visual: Node3D = null

	if definition.scene != null:
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


func _spawn_building_at_position(
	tile: WorldTile,
	definition: BuildingDefinition,
	footprint_coords: Array[Vector2i],
	spawn_position: Vector3
) -> PlacedBuildingV2:
	if tile == null or definition == null:
		return null

	var root := PlacedBuildingV2.new()
	root.setup(definition, tile, footprint_coords)

	var visual: Node3D = null

	if definition.scene != null:
		visual = definition.scene.instantiate() as Node3D

	if visual == null:
		visual = _fallback_building_visual()

	root.add_child(visual)
	root.global_position = spawn_position + Vector3.UP * place_y_offset

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


func clear_placed_buildings() -> void:
	if occupancy != null and occupancy.has_method("clear"):
		occupancy.clear()

	if registry != null and registry.has_method("clear"):
		registry.clear()

	if production != null and production.has_method("clear"):
		production.clear()

	if building_root != null:
		for child in building_root.get_children():
			building_root.remove_child(child)
			child.queue_free()

	_update_current_result()


func place_building_from_save(building_id: StringName, coord: Vector2i) -> bool:
	var definition := _definition_by_id(building_id)

	if definition == null:
		push_warning("BuildingPlacementV2: missing definition for id: %s" % [str(building_id)])
		return false

	var tile := _get_tile_by_coord(coord)

	if tile == null:
		push_warning("BuildingPlacementV2: missing tile for coord: %s" % [str(coord)])
		return false

	return _place_loaded_building(definition, tile)


func _definition_by_id(building_id: StringName) -> BuildingDefinition:
	if catalog != null and catalog.has_method("get_building_by_id"):
		return catalog.get_building_by_id(building_id)

	if catalog != null and catalog.has_method("get_buildings"):
		for definition in catalog.get_buildings():
			if definition != null and definition.id == building_id:
				return definition

	return null


func _get_tile_by_coord(coord: Vector2i) -> WorldTile:
	if world_map == null:
		push_warning("BuildingPlacementV2: world_map is null while loading building.")
		return null

	if world_map.has_method("get_tile"):
		var tile_from_method = world_map.call("get_tile", coord)
		return tile_from_method as WorldTile

	var tiles_by_coord = world_map.get("tiles_by_coord")

	if tiles_by_coord is Dictionary and tiles_by_coord.has(coord):
		return tiles_by_coord[coord] as WorldTile

	var tiles = world_map.get("tiles")

	if tiles is Array:
		for tile in tiles:
			if tile is WorldTile and tile.coord == coord:
				return tile

	push_warning("BuildingPlacementV2: could not find tile by coord. Add get_tile(coord) to WorldMapData.")
	return null


func _place_loaded_building(definition: BuildingDefinition, tile: WorldTile) -> bool:
	# Loading restores state and bypasses resource cost.

	var result := PlacementRulesV2.validate(
		tile,
		definition,
		occupancy,
		null,
		world_map,
		registry,
		resource_map
	)

	if result == null or not result.valid:
		var reason := "invalid loaded placement"

		if result != null:
			reason = result.reason

		push_warning(
			"BuildingPlacementV2: could not load %s at %s: %s"
			% [definition.display_name, str(tile.coord), reason]
		)
		return false

	var visual_node := _get_visual_node_for_tile(tile)
	var spawn_position := tile.world_position

	if visual_node != null:
		spawn_position = visual_node.global_position
	else:
		push_warning(
			"BuildingPlacementV2: no visual node found for loaded building at %s, using tile.world_position"
			% [str(tile.coord)]
		)

	var building := _spawn_building_at_position(
		tile,
		definition,
		result.footprint_coords,
		spawn_position
	)

	if building == null:
		push_warning("BuildingPlacementV2: could not spawn loaded building.")
		return false

	if occupancy != null:
		if not occupancy.occupy_coords(result.footprint_coords, building, tile):
			building.queue_free()
			push_warning("BuildingPlacementV2: loaded building overlaps occupied tile.")
			return false

	if production != null:
		production.register_building(building)

	if registry != null:
		registry.register_building(building)

	building_placed.emit(building, tile)

	if print_debug:
		print(
			"Loaded building: ",
			building.get_display_name(),
			" at ",
			tile.coord,
			" spawn_position=",
			spawn_position
		)

	_update_current_result()
	return true


func _get_visual_node_for_tile(tile: WorldTile) -> Node3D:
	if tile == null:
		return null

	if world_visual_root == null:
		return null

	var matches: Array[Node3D] = []
	_collect_visual_nodes_for_coord(world_visual_root, tile.coord, matches)

	if matches.is_empty():
		return null

	var highest := matches[0]

	for node in matches:
		if node.global_position.y > highest.global_position.y:
			highest = node

	return highest


func _collect_visual_nodes_for_coord(node: Node, coord: Vector2i, matches: Array[Node3D]) -> void:
	if node == null:
		return

	if node is Node3D:
		var node3d := node as Node3D
		var is_match := false

		if node3d.has_meta("coord"):
			var stored_coord = node3d.get_meta("coord")

			if stored_coord == coord:
				is_match = true

		if not is_match and node3d.has_meta("world_tile"):
			var stored_tile = node3d.get_meta("world_tile")

			if stored_tile is WorldTile and stored_tile.coord == coord:
				is_match = true

		if is_match:
			matches.append(node3d)

	for child in node.get_children():
		_collect_visual_nodes_for_coord(child, coord, matches)


func _find_visual_node_for_coord_recursive(node: Node, coord: Vector2i) -> Node3D:
	if node == null:
		return null

	if node is Node3D:
		var node3d := node as Node3D

		if node3d.has_meta("coord"):
			var stored_coord = node3d.get_meta("coord")

			if stored_coord == coord:
				return node3d

		if node3d.has_meta("world_tile"):
			var stored_tile = node3d.get_meta("world_tile")

			if stored_tile is WorldTile and stored_tile.coord == coord:
				return node3d

	for child in node.get_children():
		var found := _find_visual_node_for_coord_recursive(child, coord)

		if found != null:
			return found

	return null
