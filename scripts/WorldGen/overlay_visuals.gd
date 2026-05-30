extends Node
class_name OverlayVisuals

@export var theme: WorldTheme
@export var overlay_root: Node3D  # assign to "World/Overlays" or similar

var _road_nodes: Dictionary = {}  # Vector2i -> Node3D
var _river_nodes: Dictionary = {} # Vector2i -> Node3D

# ==============================
# Is this still used?
# ===============================


"""func refresh_voxel(v: Voxel) -> void:
	#print("refresh_voxel overlay=", v.overlay, " road_mask=", v.road_mask, " river_mask=", v.river_mask)
	if v == null:
		return
	if theme == null:
		push_warning("OverlayVisuals.theme not assigned")
		return
	if overlay_root == null:
		push_warning("OverlayVisuals.overlay_root not assigned")
		return

	var key := v.grid_position_xz

	# roads
	if v.overlay == Voxel.Overlay.ROAD:
		var scene := _scene_for(theme.road_variants, v.road_mask, true)
		_spawn_or_swap(_road_nodes, key, scene, v, true)
	else:
		_remove(_road_nodes, key)

	# rivers
	if v.overlay == Voxel.Overlay.RIVER:
		var scene2 := _scene_for(theme.river_variants, v.river_mask, false)
		_spawn_or_swap(_river_nodes, key, scene2, v, false)
	else:
		_remove(_river_nodes, key)


func _scene_for(variants: Array, mask: int, is_road: bool) -> PackedScene:
	if variants == null or variants.is_empty():
		return null

	var letter := VoxelData.variant_letter_from_mask(mask)

	# Guard against missing mapping keys
	if is_road:
		if not VoxelData.ROAD_LETTER_TO_INDEX.has(letter):
			return null
	else:
		if not VoxelData.RIVER_LETTER_TO_INDEX.has(letter):
			return null

	var idx: int = VoxelData.ROAD_LETTER_TO_INDEX[letter] if is_road else VoxelData.RIVER_LETTER_TO_INDEX[letter]
	if idx < 0 or idx >= variants.size():
		return null

	return variants[idx] as PackedScene


func _spawn_or_swap(store: Dictionary, key: Vector2i, scene: PackedScene, v: Voxel, is_road: bool) -> void:
	if scene == null:
		_remove(store, key)
		return

	var want_path := scene.resource_path
	var existing: Node3D = store.get(key)

	# If existing and correct variant already, just update transform/rotation and return
	if existing != null and is_instance_valid(existing):
		var existing_path := str(existing.get_meta("variant_path", ""))
		if existing_path == want_path:
			_update_overlay_transform(existing, v, is_road)
			return
		existing.queue_free()
		store.erase(key)

	# Spawn new
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return

	inst.set_meta("variant_path", want_path)
	store[key] = inst
	overlay_root.add_child(inst)

	_update_overlay_transform(inst, v, is_road)


func _update_overlay_transform(node: Node3D, v: Voxel, is_road: bool) -> void:
	var y := float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5) + 0.02
	node.position = Vector3(v.world_position.x, y, v.world_position.z)

	var mask := v.road_mask if is_road else v.river_mask
	node.rotation.y = _overlay_yaw_from_mask(mask)


func _overlay_yaw_from_mask(mask: int) -> float:
	# rotate so the first connected edge becomes "edge 0" of the mesh authoring
	var first := -1
	for i in range(6):
		if (mask & (1 << i)) != 0:
			first = i
			break
	if first == -1:
		return 0.0

	var step := TAU / 6.0
	var offset_steps := 0 # tweak if your asset's "edge 0" doesn't match your direction 0
	return float(first + offset_steps) * step


func _remove(store: Dictionary, key: Vector2i) -> void:
	if store.has(key):
		var n: Node3D = store[key]
		if n != null and is_instance_valid(n):
			n.queue_free()
		store.erase(key)

# Debug
func debug_spawn_one(road_scene: PackedScene, river_scene: PackedScene, pos: Vector3) -> void:
	if overlay_root == null:
		push_warning("OverlayVisuals.overlay_root not assigned")
		return

	if road_scene != null:
		var r := road_scene.instantiate() as Node3D
		r.position = pos + Vector3(-2, 0.1, 0)
		overlay_root.add_child(r)
		print("Spawned debug road at ", r.global_position)

	if river_scene != null:
		var w := river_scene.instantiate() as Node3D
		w.position = pos + Vector3(2, 0.1, 0)
		overlay_root.add_child(w)
		print("Spawned debug river at ", w.global_position)"""
