extends Node3D

enum mode {SELECT, BUILD}
var interact_mode : mode = mode.SELECT
@export var voxel_cursor_scene : PackedScene
@export var unit_cursor_scene : PackedScene
@export var main_camera : Camera3D
@export var p_finder : Pathfinder
@export var selection_indicator : TextureRect
const BUILDSPRITE = preload("uid://qyfdlji7ypih")
const SELECTSPRITE = preload("uid://c043hv351ffiv")

var selected_voxel : Voxel
var selected_unit : Unit
var unit_moves : Array[Voxel]
# Cursors
var voxel_cursor : Node3D
var unit_cursor : Node3D
var initialized = false

###########################################################
# setup for building HUD
@export var placed_objects_root: Node3D
@export var town_center_banner_scene: PackedScene  # your obj_blue_banner (final)
@export var ghost_material: Material   # optional (override look)

@onready var build_panel: Panel = $"../../HUD/BuildPanel"
@onready var town_center_button: Button = $"../../HUD/BuildPanel/TownCenterButton"
@onready var confirm_button: Button = $"../../HUD/BuildPanel/ConfirmButton"
@onready var cancel_button: Button = $"../../HUD/BuildPanel/CancelButton"
@onready var rotate_left_button: Button = $"../../HUD/BuildPanel/RotateLeftButton"
@onready var rotate_right_button: Button = $"../../HUD/BuildPanel/RotateRightButton"
@onready var popup_founded: AcceptDialog = $"../../HUD/PopupFounded"

enum build_tool { NONE, TOWN_CENTER }
var active_tool: build_tool = build_tool.NONE

var ghost: Node3D = null
var ghost_voxel: Voxel = null
var ghost_yaw: float = 0.0

const ROT_STEP := deg_to_rad(30.0)

##############################################################

func init():
	if initialized:
		return
	if not voxel_cursor or voxel_cursor == null:
		voxel_cursor = voxel_cursor_scene.instantiate()
		add_child(voxel_cursor)
	if not unit_cursor:
		unit_cursor = unit_cursor_scene.instantiate()
		add_child(unit_cursor)
	
	var scalar = WorldMap.world_settings.voxel_size
	voxel_cursor.scale_object_local(Vector3(scalar, 1.0, scalar))
	deselect()
	selection_indicator.texture = SELECTSPRITE
	
	town_center_button.pressed.connect(_on_tc_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	rotate_left_button.pressed.connect(func(): _rotate_ghost(-1))
	rotate_right_button.pressed.connect(func(): _rotate_ghost(1))
	
	_set_build_panel_visible(false)
	
	initialized = true


func _process(_delta: float) -> void:
	#mode select
	if Input.is_action_just_pressed("Build"):
		interact_mode = mode.BUILD
		selection_indicator.texture = BUILDSPRITE
	elif Input.is_action_just_pressed("Select"):
		interact_mode = mode.SELECT
		selection_indicator.texture = SELECTSPRITE
		
	# Setup raycast
	if Input.is_action_just_pressed("Click") or Input.is_action_just_pressed("RightClick"):
		var mouse_pos = get_viewport().get_mouse_position()
		var origin = main_camera.project_ray_origin(mouse_pos)
		var dir = main_camera.project_ray_normal(mouse_pos)
		var end = origin + dir * 1000
		var hit_data = raycast_at_mouse(origin, end)
		if not hit_data:
			print("hit data is empty")
			return

		if Input.is_action_just_pressed("Click"):
			if interact_mode == mode.SELECT:
				attempt_select(hit_data)
			elif interact_mode == mode.BUILD:
				attempt_build(hit_data.object)
		elif Input.is_action_just_pressed("RightClick"):
			print("RightClick currently does nothing, check interaction.gd")


func raycast_at_mouse(origin, end) -> HitData:
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		var collision := get_world_3d().direct_space_state.intersect_ray(query)
		if collision and collision.has("collider"):
			var hit = collision.collider
			var data = HitData.new()
			data.object = collision.collider
			data.point = collision.position
			data.normal = collision.normal
			data.ray_origin = origin
			data.ray_dir = (end - origin).normalized()
			return data
		else:
			deselect()
			return null


func attempt_build(hit_object):
	if hit_object.is_in_group("voxels"):
		build_voxel(hit_object)


func build_voxel(hit_object):
	print(hit_object)


func deselect():
	_cancel_ghost()
	_set_build_panel_visible(false)
	hide_cursor(voxel_cursor)
	hide_cursor(unit_cursor)
	unit_moves.clear()
	selected_unit = null
	p_finder.clear_highlight()


func attempt_select(hit: HitData):
	deselect()
	if hit.object.is_in_group("voxels") or hit.object.get_parent().is_in_group("voxels"):
		highlight_voxel(hit)
		return
	"""if hit.object.is_in_group("units"):
		select_unit(hit.object)
	elif hit.object.get_parent().is_in_group("units"):
		select_unit(hit.object.get_parent())"""


"""func select_unit(unit : Unit):
	selected_voxel = null
	selected_unit = unit
	hide_cursor(voxel_cursor)
	if unit is Unit:
		highlight_unit(unit)
		unit_moves = p_finder.find_reachable_voxels(unit.occupied_voxel, unit)
		p_finder.highlight_voxel(unit_moves)"""


# We have clicked somewhere on a chunk of voxels
func highlight_voxel(hit: HitData):
	selected_unit = null
	hide_cursor(unit_cursor)

	var hit_chunk: Chunk = _chunk_from_hit(hit.object)
	if hit_chunk == null:
		return

	var hit_voxel: Voxel = hit_chunk.voxel_at_point(hit)
	if hit_voxel == null:
		print("Hit voxel is null!")
		return

	selected_voxel = hit_voxel

	var cap_y := _voxel_cap_y(hit_voxel)
	var cursor_pos := Vector3(hit_voxel.world_position.x, cap_y, hit_voxel.world_position.z)

	move_cursor(voxel_cursor, cursor_pos) # no "+1" anymore
	voxel_cursor.visible = true
	animate_cursor(voxel_cursor)
	
	# Place town center on newly selected tile
	if active_tool == build_tool.TOWN_CENTER and selected_voxel != null:
		_spawn_ghost_on_voxel(selected_voxel)
	
	# If a build tool is not active, just show the build panel for this selected tile
	if active_tool == build_tool.NONE:
		_set_build_panel_visible(true)


func highlight_unit(unit):
	move_cursor(unit_cursor, unit.position)
	unit_cursor.visible = true


## move cursor with optional height difference
func move_cursor(cursor : Node3D, pos : Vector3):
	cursor.position = pos


func animate_cursor(cursor : Node3D):
	var tween = get_tree().create_tween()
	var initial_scale = cursor.scale
	var target_scale = initial_scale * 1.15
	tween.set_trans(Tween.TRANS_SPRING)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cursor, "scale", target_scale, 0.175)
	tween.tween_property(cursor, "scale", initial_scale, 0.2)


func hide_cursor(cursor : Node3D):
	if cursor:
		move_cursor(cursor, Vector3.ZERO)
		cursor.visible = false


func _voxel_cap_y(v: Voxel) -> float:
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5)


func _chunk_from_hit(node: Node) -> Chunk:
	var n := node
	while n != null:
		if n is Chunk:
			return n as Chunk
		n = n.get_parent()
	return null


func _set_build_panel_visible(on: bool) -> void:
	build_panel.visible = on
	# Only enable confirm/rotate when ghost exists
	confirm_button.disabled = ghost == null
	rotate_left_button.disabled = ghost == null
	rotate_right_button.disabled = ghost == null


func _on_tc_pressed() -> void:
	print("tc pressed")
	if selected_voxel == null:
		return
	if selected_voxel.has_town_center:
		push_warning("This tile already has a town center.")
		return
	if not selected_voxel.placeable:
		push_warning("Tile not placeable.")
		return

	active_tool = build_tool.TOWN_CENTER
	_spawn_ghost_on_voxel(selected_voxel)
	_set_build_panel_visible(true)


func _spawn_ghost_on_voxel(v: Voxel) -> void:
	_cancel_ghost()

	if town_center_banner_scene == null:
		push_warning("town_center_banner_scene not assigned.")
		return

	ghost = town_center_banner_scene.instantiate() as Node3D
	
	for child in ghost.get_children():
		if child is MeshInstance3D:
			child.material_override = ghost_material
	
	ghost_voxel = v
	ghost_yaw = 0.0

	# position at tile center + cap height
	var cap_y := _voxel_cap_y(v)
	ghost.position = Vector3(v.world_position.x, cap_y, v.world_position.z)

	# make it look like a preview:
	_make_node_transparent(ghost)

	var root := _placed_root()
	if root == null:
		push_warning("PlacedObjects root not assigned/found.")
		return
	root.add_child(ghost)
	
	confirm_button.disabled = false
	rotate_left_button.disabled = false
	rotate_right_button.disabled = false


func _make_node_transparent(n: Node) -> void:
	# Option A: override materials in all MeshInstance3D children
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Variant = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if ghost_material != null:
				mi.material_override = ghost_material
			else:
				# quick built-in approach: duplicate its material and reduce alpha
				var mat := mi.get_active_material(0)
				if mat is StandardMaterial3D:
					var m := (mat as StandardMaterial3D).duplicate()
					m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					m.albedo_color.a = 0.35
					mi.material_override = m
		for ch in cur.get_children():
			stack.append(ch)


func _rotate_ghost(dir: int) -> void:
	if ghost == null:
		return
	ghost_yaw = wrapf(ghost_yaw + float(dir) * ROT_STEP, -PI, PI)
	ghost.rotation.y = ghost_yaw


func _on_cancel_pressed() -> void:
	_cancel_ghost()
	active_tool = build_tool.NONE
	_set_build_panel_visible(false)


func _on_confirm_pressed() -> void:
	if ghost == null or ghost_voxel == null:
		return

	# place final banner (non-transparent)
	var v := ghost_voxel

	# Prevent double placement
	if v.has_town_center:
		_cancel_ghost()
		return

	# Remove ghost
	ghost.queue_free()
	ghost = null

	# Spawn the real instance
	var placed := town_center_banner_scene.instantiate() as Node3D
	var cap_y := _voxel_cap_y(v)
	placed.position = Vector3(v.world_position.x, cap_y, v.world_position.z)
	placed.rotation.y = ghost_yaw

	var root := _placed_root()
	if root == null:
		push_warning("PlacedObjects root not assigned/found.")
		return
	root.add_child(placed)

	# Mark voxel state
	v.has_town_center = true
	v.town_center_rotation_y = ghost_yaw
	v.placeable = false

	active_tool = build_tool.NONE
	ghost_voxel = null

	_set_build_panel_visible(false)

	# Popup
	popup_founded.dialog_text = "Congratulations! You founded your kingdom."
	popup_founded.popup_centered()


func _cancel_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
	ghost = null
	ghost_voxel = null
	ghost_yaw = 0.0


func _placed_root() -> Node3D:
	if placed_objects_root != null:
		return placed_objects_root
	# fallback: try to find it by absolute path if you forget to assign
	var n := get_tree().root.get_node_or_null("World/PlacedObjects")
	return n as Node3D
