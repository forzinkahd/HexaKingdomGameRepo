extends Node
class_name OverlayVisuals

@export var theme: WorldTheme
@export var overlay_root: Node3D  # assign to "World/Overlays" or similar

var _road_nodes: Dictionary = {}  # Vector2i -> Node3D
var _river_nodes: Dictionary = {}

func refresh_voxel(v: Voxel) -> void:
	if v == null: return
	var key := v.grid_position_xz
	
	# roads
	if v.overlay == Voxel.Overlay.ROAD:
		_spawn_or_swap(_road_nodes, key, _scene_for(theme.road_variants, v.road_mask), v)
	else:
		_remove(_road_nodes, key)
	
	# rivers
	if v.overlay == Voxel.Overlay.RIVER:
		_spawn_or_swap(_river_nodes, key, _scene_for(theme.river_variants, v.river_mask), v)
	else:
		_remove(_river_nodes, key)

func _scene_for(dict: Dictionary, mask: int) -> PackedScene:
	var letter := VoxelData.variant_letter_from_mask(mask)
	return dict.get(letter)

func _spawn_or_swap(store: Dictionary, key: Vector2i, scene: PackedScene, v: Voxel) -> void:
	if scene == null:
		_remove(store, key)
		return
	
	var existing: Node3D = store.get(key)
	var want_path := scene.resource_path
	
	if existing != null and is_instance_valid(existing):
		# if already correct variant, do nothing
		if existing.scene_file_path == want_path:
			return
		existing.queue_free()
	
	var inst := scene.instantiate() as Node3D
	store[key] = inst
	
	var y := float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5) + 0.02
	inst.position = Vector3(v.world_position.x, y, v.world_position.z)
	
	overlay_root.add_child(inst)

func _remove(store: Dictionary, key: Vector2i) -> void:
	if store.has(key):
		var n: Node3D = store[key]
		if n != null and is_instance_valid(n):
			n.queue_free()
		store.erase(key)
