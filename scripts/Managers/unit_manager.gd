extends Node
class_name UnitManager

@export var units_root: Node3D
@export var villager_scene: PackedScene
@export var builder_scene: PackedScene


func get_first_villager() -> Villager:
	if units_root == null:
		return null
	for c in units_root.get_children():
		if c is Villager:
			return c as Villager
	return null


func spawn_first_villager_at_town_center() -> Villager:
	if villager_scene == null or units_root == null:
		return null
	if WorldMap.town_center_voxel == null:
		return null
	
	#print("villager spawned")
	var v := villager_scene.instantiate() as Villager
	units_root.add_child(v)
	v.place_on_voxel(WorldMap.town_center_voxel)
	return v


func spawn_builder_at_world_pos(pos: Vector3) -> Builder:
	if builder_scene == null or units_root == null:
		push_warning("builder scene missing")
		return null
	
	var builder := builder_scene.instantiate() as Builder
	units_root.add_child(builder)
	builder.global_position = pos
	return builder
