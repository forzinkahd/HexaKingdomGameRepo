extends Node
class_name BuildingPlacer

@export var placed_root: Node3D
@export var town_center_scene: PackedScene

const ID_TOWN_CENTER := &"town_center"


@export var building_scenes: Dictionary = {
	&"town_center": null,
	# later:
	# &"builders_hut": preload("res://..."),
	# &"house": preload("res://..."),
}


func get_scene(building_id: StringName) -> PackedScene:
	var s: Variant = building_scenes.get(building_id)
	return s as PackedScene


func can_place(building_id: StringName, v: Voxel) -> bool:
	if v == null:
		return false
	if not v.can_place_building():
		return false

	# uniqueness
	if building_id == ID_TOWN_CENTER and WorldMap.has_town_center():
		return false

	return true


func place(building_id: StringName, v: Voxel, rotation_y: float) -> Node3D:
	if not can_place(building_id, v):
		return null

	var scene := _scene_for(building_id)
	if scene == null:
		return null

	var inst := scene.instantiate() as Node3D
	inst.position = Vector3(v.world_position.x, _voxel_cap_y(v), v.world_position.z)
	inst.rotation.y = rotation_y

	placed_root.add_child(inst)

	# write voxel state
	v.building_id = building_id
	v.building_node = inst
	v.placeable = false

	# write global state
	if building_id == ID_TOWN_CENTER:
		WorldMap.town_center_voxel = v
		WorldMap.town_center_node = inst

	return inst


func _scene_for(building_id: StringName) -> PackedScene:
	match building_id:
		ID_TOWN_CENTER:
			return town_center_scene
		_:
			return null


func _voxel_cap_y(v: Voxel) -> float:
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5)
