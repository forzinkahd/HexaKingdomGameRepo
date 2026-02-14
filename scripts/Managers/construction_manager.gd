extends Node
class_name ConstructionManager

@export var placed_root: Node3D
@export var construction_site_scene: PackedScene
@export var building_placer: BuildingPlacer

var active_sites: Array[ConstructionSite] = []

# prototype for building progression, move into builder later
func _process(delta: float) -> void:
	for s in active_sites:
		if is_instance_valid(s):
			s.add_progress(delta)


func spawn_site(def: BuildingDefinition, v: Voxel, rotation_y: float) -> ConstructionSite:
	if construction_site_scene == null or placed_root == null:
		push_warning("no construction site scene or placed root loaded")
		return null
	
	var site := construction_site_scene.instantiate() as ConstructionSite
	placed_root.add_child(site)
	
	site.global_position = Vector3(v.world_position.x, _voxel_cap_y(v), v.world_position.z)
	site.rotation.y = rotation_y
	
	site.build_time = def.build_time
	site.log_cost = def.cost_logs
	site.voxel = v
	site.building_id = def.id
	site.rotation_y = rotation_y
	
	site.finished.connect(_on_site_finished)
	
	active_sites.append(site)
	site.start(def.progress_stages)
	return site


func _on_site_finished(site: ConstructionSite) -> void:
	active_sites.erase(site)

	if building_placer == null:
		return

	var def := building_placer.get_definition(site.building_id)
	if def == null or def.scene == null:
		return

	var v := site.voxel
	if v == null:
		site.queue_free()
		return

	# Replace site with final building
	var final := def.scene.instantiate() as Node3D
	placed_root.add_child(final)
	final.global_position = site.global_position
	final.rotation.y = site.rotation_y

	# Update voxel to point to final building
	v.building_node = final
	v.building_rotation_y = site.rotation_y

	# Unique bookkeeping if needed
	if def.unique:
		WorldMap.town_center_voxel = v
		WorldMap.town_center_node = final

	site.queue_free()


func _voxel_cap_y(v: Voxel) -> float:
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5)
