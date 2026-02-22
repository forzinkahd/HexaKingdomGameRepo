extends Node
class_name RoadTool

@export var camera: Camera3D
@export var overlay_visuals: OverlayVisuals
@export var overlay_root: Node3D            # same root used by OverlayVisuals
@export var world_theme: WorldTheme

var active := false
var anchor: Voxel = null          # “road front” / last placed tile
var ghost: Node3D = null
var ghost_dir := 0                # 0..5
const GHOST_INDEX := 12           # M
const GHOST_LETTER := "M"

func set_active(on: bool) -> void:
	active = on
	if not active:
		_clear_ghost()
		anchor = null



func _clear_ghost() -> void:
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


func begin_from_voxel(v: Voxel) -> void:
	if v == null or not v.can_place_road():
		return
	set_active(true)
	anchor = v
	ghost_dir = 0
	_show_ghost_on(v)


func _show_ghost_on(v: Voxel) -> void:
	_ensure_ghost()
	
	var scene: PackedScene = world_theme.road_variants[GHOST_INDEX]
	if scene == null:
		return
	
	# rebuild ghost if wrong scene
	if ghost.get_meta("variant_idx") != GHOST_INDEX:
		ghost.queue_free()
		ghost = null
		_ensure_ghost()

	if ghost == null:
		ghost = scene.instantiate() as Node3D
		ghost.set_meta("variant_idx", GHOST_INDEX)
		add_child(ghost)
		
		# make it look “ghosty”
		_set_ghost_material(ghost)
	
	_position_ghost(v)


func _ensure_ghost() -> void:
	if ghost != null and is_instance_valid(ghost):
		return

	if world_theme == null:
		return

	# resolve ghost scene using same mapping you use for real tiles
	var idx: int = VoxelData.ROAD_LETTER_TO_INDEX.get(GHOST_LETTER, 12)
	if idx < 0 or idx >= world_theme.road_variants.size():
		return
	var scene := world_theme.road_variants[idx] as PackedScene
	if scene == null:
		return

	ghost = scene.instantiate() as Node3D
	if ghost == null:
		return

	# Make ghost semi-transparent / unshaded if you want:
	# (optional) walk all MeshInstance3D children and set material override.

	overlay_root.add_child(ghost)
	_update_ghost_rot()


func _update_ghost_rot() -> void:
	if ghost == null:
		return
	ghost.rotation.y = float(ghost_dir) * (TAU / 6.0)


func _position_ghost(v: Voxel) -> void:
	if ghost == null:
		return
	var y := float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5) + 0.02
	ghost.position = Vector3(v.world_position.x, y, v.world_position.z)
	ghost.rotation.y = float(ghost_dir + 1) * (TAU / 6.0)  # +1 offset_steps


func rotate_left() -> void:
	ghost_dir = (ghost_dir + 5) % 6
	if anchor: _position_ghost(anchor)


func rotate_right() -> void:
	ghost_dir = (ghost_dir + 1) % 6
	if anchor: _position_ghost(anchor)


func _set_ghost_material(root: Node) -> void:
	for c in root.get_children():
		_set_ghost_material(c)
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		mi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.modulate.a = 0.35
		
