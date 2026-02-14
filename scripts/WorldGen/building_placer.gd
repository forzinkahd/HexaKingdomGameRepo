extends Node
class_name BuildingPlacer

@export var placed_root: Node3D
@export var buildings: Array[BuildingDefinition] = []
@export var construction_manager: ConstructionManager


const ID_TOWN_CENTER: StringName = &"town_center"

func get_definition(id: StringName) -> BuildingDefinition:
	for b in buildings:
		if b != null and b.id == id:
			return b
	return null

func can_place(building_id: StringName, v: Voxel) -> bool:
	if v == null:
		push_warning("null")
		return false
	
	if not v.can_place_building():
		return false

	var def := get_definition(building_id)
	if def == null or def.scene == null:
		return false

	# Uniqueness guard:
	if building_id == ID_TOWN_CENTER and WorldMap.has_town_center():
		return false
	
	if def.unique and WorldMap.has_unique_building(def.id):
		return false

	# cost check
	if WorldMap.wood_logs < def.cost_logs:
		push_warning("Not enough logs")
		return false

	return true

func place(building_id: StringName, v: Voxel, rotation_y: float) -> Node3D:
	if not can_place(building_id, v):
		return null

	var def := get_definition(building_id)
	if def == null:
		return null
	
	
	WorldMap.wood_logs -= def.cost_logs
	
	# If building requires construction, spawn a site instead
	if def.requires_construction and construction_manager != null:
		var site := construction_manager.spawn_site(def, v, rotation_y)
		if site == null:
			push_warning("site is null")
			return null
		
		# lock voxel to prohibit double placing
		v.building_id = def.id
		v.building_node = site
		v.building_rotation_y = rotation_y
		v.placeable = false
		
		return site
	
	# Instantly place certain props
	var inst := def.scene.instantiate() as Node3D
	inst.position = Vector3(v.world_position.x, _voxel_cap_y(v), v.world_position.z)
	inst.rotation.y = rotation_y
	placed_root.add_child(inst)

	# write voxel state
	v.building_id = def.id
	v.building_node = inst
	v.building_rotation_y = rotation_y
	v.placeable = false

	# set global Town Center state by ID (NOT by def.unique)
	if building_id == ID_TOWN_CENTER:
		WorldMap.town_center_voxel = v
		WorldMap.town_center_node = inst

	return inst

func _voxel_cap_y(v: Voxel) -> float:
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5)
