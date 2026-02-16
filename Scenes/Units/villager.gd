extends Unit
class_name Villager

signal reached_target

@export var move_speed: float = 2.5
@export var arrive_distance: float = 0.25
@export var pickup_time: float = 0.45
@export var pickup_lunge_distance: float = 0.12
@export var height_lerp_speed: float = 14.0
#@export var ground_offset: float = 0.02
@export var auto_work_enabled: bool = true
@export var auto_retry_delay: float = 0.6
@export var auto_after_task_delay: float = 0.2

var _auto_running: bool = false

@onready var visual: Node3D = $Visual


var carrying_logs: int = 0
var is_busy: bool = false
#var occupied_voxel: Voxel

var _target_pos: Vector3
var _has_target := false
var _moving := false


func place_on_voxel(v: Voxel) -> void:
	occupied_voxel = v
	global_position = Vector3(v.world_position.x, _cap_y(v), v.world_position.z)


func move_to_world(pos: Vector3) -> void:
	_target_pos = pos
	_has_target = true
	_moving = true


func await_reach_target() -> void:
	if not _moving:
		return
	await reached_target


func can_carry_more() -> bool:
	# keep your capacity logic if you have it
	return true


func face_point_yaw(p: Vector3) -> void:
	var dir := p - global_position
	dir.y = 0.0
	if dir.length() < 0.0001:
		return

	# Godot forward is -Z, so yaw from X/Z:
	var yaw := atan2(dir.x, dir.z)
	rotation.y = yaw

	# hard lock pitch/roll so nothing accumulates
	rotation.x = 0.0
	rotation.z = 0.0


# works nicely
func pickup_log_with_animation(log: LogPickup) -> bool:
	if log == null or not is_instance_valid(log):
		return false
	
	# reserve first so others don’t steal it during animation
	if not log.reserve():
		return false
	
	# face it
	face_point_yaw(log.global_position)
	
	# small lunge forward (optional but feels good)
	var start_pos := global_position
	var dir := (log.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()
		global_position = start_pos + dir * pickup_lunge_distance
	
	# play a tiny “pickup” tween on the visual (optional)
	var t := get_tree().create_tween()
	if visual != null:
		var start_rot := visual.rotation
		t.tween_property(visual, "rotation:x", start_rot.x + deg_to_rad(10.0), pickup_time * 0.4)
		t.tween_property(visual, "rotation:x", start_rot.x, pickup_time * 0.6)
	else:
		# no visual node, just wait the beat
		t.tween_interval(pickup_time)
	
	await t.finished
	
	if visual != null:
		visual.rotation.x = 0.0
		visual.rotation.z = 0.0
	
	# log might be gone (collected by someone else / freed)
	if not is_instance_valid(log):
		return false
	
	# collect
	carrying_logs += log.amount
	log.collect_and_free() # safe free + prevents double collect
	return true


func _physics_process(delta: float) -> void:
	# Keep body on top of terrain
	var desired_y := _terrain_cap_y_at(global_position) + ground_offset
	global_position.y = lerp(global_position.y, desired_y, clamp(delta * height_lerp_speed, 0.0, 1.0))
	
	# Also hard-lock pitch/roll each frame (prevents any drift from other calls)
	rotation.x = 0.0
	rotation.z = 0.0
	
	if not _has_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var to := _target_pos - global_position
	to.y = 0.0
	var dist := to.length()
	
	if dist <= arrive_distance:
		_has_target = false
		_moving = false
		velocity = Vector3.ZERO
		move_and_slide()
		reached_target.emit()
		return
	
	var dir: Vector3 = to / max(dist, 0.0001)
	velocity = dir * move_speed
	move_and_slide()


# auto working
func start_auto_work(resource_root: Node3D) -> void:
	if _auto_running:
		return
	_auto_running = true
	_auto_work_loop(resource_root) # async fire-and-forget


func stop_auto_work() -> void:
	auto_work_enabled = false
	_auto_running = false


func _auto_work_loop(resource_root: Node3D) -> void:
	while _auto_running and is_inside_tree():
		if not auto_work_enabled:
			await get_tree().create_timer(0.3).timeout
			continue
		
		# Don't interrupt manual tasks
		if is_busy:
			await get_tree().process_frame
			continue
		
		var tree := _find_nearest_available_tree()
		if tree == null:
			await get_tree().create_timer(auto_retry_delay).timeout
			continue
		
		# Claim the tree before walking (prevents future multi-villager issues)
		if not tree.try_claim():
			await get_tree().process_frame
			continue
		
		is_busy = true
		await _do_chop_and_haul(tree, resource_root)
		is_busy = false
		
		await get_tree().create_timer(auto_after_task_delay).timeout


func _find_nearest_available_tree() -> TreeCluster:
	var best: TreeCluster = null
	var best_d2 := INF
	
	for n in get_tree().get_nodes_in_group("harvestable_tree"):
		var t := n as TreeCluster
		if t == null or not is_instance_valid(t):
			continue
		if t.is_depleted or t.is_being_chopped:
			continue
		
		var d2 := global_position.distance_squared_to(t.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = t
	
	return best


func _do_chop_and_haul(tree: TreeCluster, resource_root: Node3D) -> void:
	# Walk to tree
	var approach := tree.global_position + (global_position - tree.global_position).normalized() * 0.6
	move_to_world(approach)
	await await_reach_target()
	
	# Tree might be gone
	if tree == null or not is_instance_valid(tree):
		return
	
	# Determine spawn Y on terrain so logs are visible
	var spawn_y := _terrain_cap_y_at(tree.global_position)
	
	var logs: Array[LogPickup] = await tree.chop_and_harvest(resource_root, spawn_y)
	
	# If nothing came back, release claim (tree cancelled / removed)
	if logs.is_empty():
		if tree != null and is_instance_valid(tree):
			tree.release_claim()
		return
	
	# Pick up all logs (your animation already handles reserve + collect)
	for log in logs:
		if not is_instance_valid(log):
			continue
		
		# optional: walk to it before pickup
		move_to_world(log.global_position)
		await await_reach_target()
		
		await pickup_log_with_animation(log)

	# Deliver to Town Center
	if WorldMap.town_center_voxel != null:
		var drop := Vector3(
			WorldMap.town_center_voxel.world_position.x,
			global_position.y,
			WorldMap.town_center_voxel.world_position.z
		)
		move_to_world(drop)
		await await_reach_target()
		
		WorldMap.wood_logs += carrying_logs
		carrying_logs = 0


func can_receive_move_commands() -> bool:
	return true


func command_move(dest: Vector3) -> void:
	move_to_world(dest)



func _terrain_cap_y_at(world_pos: Vector3) -> float:
	var key: Vector2i
	if WorldMap.is_map_staggered:
		key = _pick_offset_hex_xz(world_pos)
	else:
		key = _pick_axial_hex_xz(world_pos)
	
	var v: Voxel = WorldMap.surface_layer.get(key)
	if v == null:
		return global_position.y
	
	return float(v.height_units) * (WorldMap.world_settings.voxel_height * 0.5) + 0.02


func _pick_axial_hex_xz(p: Vector3) -> Vector2i:
	var size: float = WorldMap.world_settings.voxel_size
	var sqrt3: float = sqrt(3.0)
	var px: float = p.x / size
	var pz: float = p.z / size
	var qf: float = (2.0 / 3.0) * px
	var rf: float = (-1.0 / 3.0) * px + (1.0 / sqrt3) * pz
	var xf: float = qf
	var zf: float = rf
	var yf: float = -xf - zf
	var rx: int = int(round(xf))
	var ry: int = int(round(yf))
	var rz: int = int(round(zf))
	var x_diff: float = abs(rx - xf)
	var y_diff: float = abs(ry - yf)
	var z_diff: float = abs(rz - zf)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	
	return Vector2i(rx, rz)


func _pick_offset_hex_xz(p: Vector3) -> Vector2i:
	var size: float = WorldMap.world_settings.voxel_size
	var sqrt3: float = sqrt(3.0)
	var col_f: float = (2.0 / 3.0) * (p.x / size)
	var col: int = int(round(col_f))
	var parity: int = ((col % 2) + 2) % 2
	var row_f: float = (p.z / (sqrt3 * size)) - float(parity) * 0.5
	var row: int = int(round(row_f))
	
	return Vector2i(col, row)
