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
@export var ghost_material: Material   # optional (override look)
@export var building_placer: BuildingPlacer
@export var unit_manager: UnitManager
@export var task_manager: TaskManager
@export var resource_root: Node3D

@onready var build_panel: Panel = $"../../HUD/BuildPanel"
@onready var town_center_button: Button = $"../../HUD/BuildPanel/TownCenterButton"
@onready var workshop_button: Button = $"../../HUD/BuildPanel/WorkshopButton"
@onready var confirm_button: Button = $"../../HUD/BuildPanel/ConfirmButton"
@onready var cancel_button: Button = $"../../HUD/BuildPanel/CancelButton"
@onready var rotate_left_button: Button = $"../../HUD/BuildPanel/RotateLeftButton"
@onready var rotate_right_button: Button = $"../../HUD/BuildPanel/RotateRightButton"
@onready var popup_founded: AcceptDialog = $"../../HUD/PopupFounded"
@onready var workshop_panel: Panel = $"../../HUD/WorkshopPanel"
@onready var train_builder_button: Button = $"../../HUD/WorkshopPanel/TrainBuilderButton"
@onready var close_workshop_button: Button = $"../../HUD/WorkshopPanel/CloseWorkshopButton"


enum build_tool { NONE, TOWN_CENTER }
var active_tool: build_tool = build_tool.NONE

var ghost: Node3D = null
var ghost_voxel: Voxel = null
var ghost_yaw: float = 0.0

const ROT_STEP := deg_to_rad(30.0)

##############################################################


var active_building_id: StringName = &""			# replacing hardcoded scenes

var _task_running: bool = false

var _open_workshop: BuilderWorkshop = null

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
	workshop_button.pressed.connect(_on_workshop_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	rotate_left_button.pressed.connect(func(): _rotate_ghost(1))
	rotate_right_button.pressed.connect(func(): _rotate_ghost(-1))
	train_builder_button.pressed.connect(_on_train_builder_pressed)
	close_workshop_button.pressed.connect(func():
		_open_workshop = null
		workshop_panel.visible = false
	)
	workshop_panel.visible = false
	
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_world_click(false)
			get_viewport().set_input_as_handled()
			return
		
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_handle_world_click(true)
			get_viewport().set_input_as_handled()
			return


func _handle_world_click(is_right_click: bool) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := main_camera.project_ray_origin(mouse_pos)
	var dir := main_camera.project_ray_normal(mouse_pos)
	var end := origin + dir * 1000.0
	
	var hit_data := raycast_at_mouse(origin, end)
	if hit_data == null:
		return
		
	if is_right_click:
		print("RightClick currently does nothing, check interaction.gd")
		return
		
	if interact_mode == mode.SELECT:
		attempt_select(hit_data)
	elif interact_mode == mode.BUILD:
		attempt_build(hit_data.object)


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
	var ws := _workshop_from_hit(hit.object)
	if ws != null:
		_open_workshop = ws
		workshop_panel.visible = true
		train_builder_button.disabled = not ws.can_train_builder()
		return
	
	# handle tree clusters
	var tree := _tree_from_hit(hit.object)
	if tree != null:
		_command_chop_tree(tree, hit)
		return
	
	deselect()
	if hit.object.is_in_group("voxels") or hit.object.get_parent().is_in_group("voxels"):
		highlight_voxel(hit)
		return


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
	
	# disable workshop if logs insufficient
	workshop_button.disabled = WorldMap.wood_logs < 5


func _on_tc_pressed() -> void:
	active_building_id = &"town_center"
	if selected_voxel == null or building_placer == null:
		return

	if not building_placer.can_place(active_building_id, selected_voxel):
		push_warning("Can't place Town Center here (occupied, not placeable, or already exists).")
		return

	_spawn_ghost_on_voxel(selected_voxel)
	_set_build_panel_visible(true)


func _on_workshop_pressed() -> void:
	active_building_id = &"builders_workshop"
	if selected_voxel == null or building_placer == null:
		return

	if not building_placer.can_place(active_building_id, selected_voxel):
		push_warning("Can't place Builder Workshop (need 5 logs / tile not placeable).")
		return

	_spawn_ghost_on_voxel(selected_voxel)
	_set_build_panel_visible(true)


func _spawn_ghost_on_voxel(v: Voxel) -> void:
	_cancel_ghost()

	if building_placer == null:
		push_warning("BuildingPlacer not assigned.")
		return
	if active_building_id == &"":
		push_warning("No active building selected.")
		return

	var def := building_placer.get_definition(active_building_id)
	if def == null or def.scene == null:
		push_warning("No BuildingDefinition/scene for building_id: %s" % [active_building_id])
		return

	ghost = def.scene.instantiate() as Node3D
	ghost_voxel = v
	ghost_yaw = 0.0

	var cap_y: float = _voxel_cap_y(v)
	ghost.position = Vector3(v.world_position.x, cap_y, v.world_position.z)
	ghost.rotation.y = ghost_yaw

	_make_node_transparent(ghost)

	var root := _placed_root()
	if root == null:
		push_warning("PlacedObjects root not assigned/found.")
		ghost.queue_free()
		ghost = null
		return

	root.add_child(ghost)

	confirm_button.disabled = false
	rotate_left_button.disabled = false
	rotate_right_button.disabled = false


func _rotate_ghost(dir: int) -> void:
	if ghost == null:
		return
	ghost_yaw = wrapf(ghost_yaw + float(dir) * ROT_STEP, -PI, PI)
	ghost.rotation.y = ghost_yaw


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


func _on_cancel_pressed() -> void:
	_cancel_ghost()
	active_tool = build_tool.NONE
	_set_build_panel_visible(false)


func _on_confirm_pressed() -> void:
	if ghost == null or ghost_voxel == null:
		return
	if building_placer == null:
		return
	if active_building_id == &"":
		return

	var id := active_building_id # capture it BEFORE you clear/reset anything

	var placed := building_placer.place(id, ghost_voxel, ghost_yaw)
	if placed == null:
		push_warning("Cannot place building.")
		return

	_cancel_ghost()
	_set_build_panel_visible(false)

	if id == &"town_center":
		# spawn villager now that WorldMap.town_center_voxel is guaranteed set
		#var um := get_node_or_null("../../Managers/UnitManager") as UnitManager
		if unit_manager != null:
			unit_manager.spawn_first_villager_at_town_center()

		popup_founded.dialog_text = "Congratulations! You founded your kingdom."
		popup_founded.popup_centered()

	if id == &"builders_workshop":
		push_warning("builder's workshop created, unlock/implement progression")

	active_building_id = &""


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


func _tree_from_hit(n: Node) -> TreeCluster:
	var current := n
	while current != null:
		if current is TreeCluster:
			return current as TreeCluster
		if current.is_in_group("harvestable_tree"):
			# if you didn't use TreeCluster class_name
			return current as TreeCluster
		current = current.get_parent()
	return null


func _command_chop_tree(tree: TreeCluster, hit: HitData) -> void:
	if task_manager == null:
		return

	# pick the surface voxel under the tree:
	# simplest: use currently selected_voxel if it matches; better: raycast hit voxel
	var v: Voxel = null
	if hit != null:
		var hit_chunk := _chunk_from_hit(hit.object)
		if hit_chunk != null:
			v = hit_chunk.voxel_at_point(hit)

	if v == null:
		push_warning("Couldn't resolve target voxel for tree.")
		return

	if not task_manager.create_chop_task(tree, v):
		push_warning("Could not create chop task (busy, invalid, or already claimed).")
		return

	_assign_task_to_first_villager()


func _assign_task_to_first_villager() -> void:
	if _task_running:
		return
	if unit_manager == null or task_manager == null:
		return
	if not task_manager.has_task():
		return

	var villager := unit_manager.get_first_villager()
	if villager == null:
		push_warning("No villager available.")
		task_manager.clear_task()
		return
	if villager.is_busy:
		return

	_task_running = true
	villager.is_busy = true
	_run_active_task(villager)


func _run_active_task(villager: Villager) -> void:
	var task_type := task_manager.get_task_type()

	if task_type == &"chop_tree":
		await _run_task_chop_tree(villager)
	else:
		push_warning("Unknown task: %s" % [task_type])
		task_manager.clear_task()

	villager.is_busy = false
	_task_running = false


func _workshop_from_hit(n: Node) -> BuilderWorkshop:
	var current := n
	while current != null:
		if current is BuilderWorkshop:
			return current as BuilderWorkshop
		current = current.get_parent()
	return null


func _on_train_builder_pressed() -> void:
	if _open_workshop == null or not is_instance_valid(_open_workshop):
		workshop_panel.visible = false
		return
	if unit_manager == null:
		return

	var b := _open_workshop.train_builder(unit_manager)
	if b == null:
		# not enough logs etc.
		train_builder_button.disabled = true
		return

	# update UI state after purchase
	train_builder_button.disabled = not _open_workshop.can_train_builder()


func _run_task_chop_tree(villager: Villager) -> void:
	var tree := task_manager.get_treecluster()
	if tree == null or not is_instance_valid(tree):
		task_manager.clear_task()
		return

	# walk to tree
	var approach: Vector3 = tree.global_position + (villager.global_position - tree.global_position).normalized() * 0.6
	villager.move_to_world(approach)
	await villager.await_reach_target()

	# tree might have been removed while walking
	if tree == null or not is_instance_valid(tree):
		task_manager.clear_task()
		return

	# IMPORTANT: since TaskManager already set tree.is_being_chopped=true,
	# TreeCluster.chop_and_harvest() should NOT early-return because of that.
	# So: remove the "is_being_chopped" check inside chop_and_harvest OR
	# don't set it in TaskManager. Pick ONE owner of that flag.
	#
	# I recommend: TaskManager claims by setting is_being_chopped=true,
	# and TreeCluster.chop_and_harvest() should accept that state.
	#
	# Quick fix: change TreeCluster.can_harvest() for external checks,
	# and in chop_and_harvest() remove "or is_being_chopped" from the guard.

	var spawn_y := _terrain_cap_y_at(tree.global_position)
	var logs: Array[LogPickup] = await tree.chop_and_harvest(resource_root, spawn_y)

	# if logs empty, tree might have been removed/cancelled
	if logs.is_empty():
		task_manager.clear_task()
		return

	# pickup
	for log in logs:
		if not is_instance_valid(log):
			continue
		if not villager.can_carry_more():
			break

		# move to log
		villager.move_to_world(log.global_position)
		await villager.await_reach_target()

		# pickup (includes reserve + animation + queue_free)
		await villager.pickup_log_with_animation(log)


	# deliver (prototype)
	if WorldMap.town_center_voxel != null:
		var drop := Vector3(
			WorldMap.town_center_voxel.world_position.x,
			villager.global_position.y,
			WorldMap.town_center_voxel.world_position.z
		)
		villager.move_to_world(drop)
		await villager.await_reach_target()
		WorldMap.wood_logs += villager.carrying_logs
		villager.carrying_logs = 0
		#print("Delivered logs to Town Center! Total: ", WorldMap.wood_logs)

	task_manager.clear_task()


func _terrain_cap_y_at(world_xz: Vector3) -> float:
	var from := world_xz + Vector3(0, 50.0, 0)
	var to := world_xz + Vector3(0, -50.0, 0)

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_bodies = true
	q.collide_with_areas = false
	q.collision_mask = 1 # your voxel collision layer

	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return world_xz.y

	# Find chunk
	var col := hit["collider"] as Object
	var node := col as Node
	while node != null and not (node is Chunk):
		node = node.get_parent()
	if node == null:
		return hit["position"].y

	# Build HitData for voxel lookup
	var hd := HitData.new()
	hd.object = col
	hd.point = hit["position"]
	hd.normal = hit["normal"]
	hd.ray_origin = from
	hd.ray_dir = (to - from).normalized()

	var v := (node as Chunk).voxel_at_point(hd)
	if v == null:
		return hit["position"].y

	return _voxel_cap_y(v) + 0.03


func _cap_y_for_world_xz(world_pos: Vector3) -> float:
	# Find surface voxel at this xz and use its cap height
	var v: Variant = WorldMap.surface_layer.get(Vector2i(
		int(round(world_pos.x / (WorldMap.world_settings.voxel_size * 1.5))), # rough fallback, not used if you do chunk mapping
		0
	))
	# ^ ignore this fallback if you do the chunk mapping approach below
	return world_pos.y
