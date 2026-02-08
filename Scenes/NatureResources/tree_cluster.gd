extends Node3D
class_name TreeCluster

@export var max_hp: int = 5
@export var logs_scene: PackedScene
@export var poof_scene: PackedScene

var _hp: int
var _base_xform: Transform3D
var _is_dead: bool = false
var _shake_tween: Tween

func _ready() -> void:
	_hp = max_hp
	_base_xform = transform

func apply_chop(damage: int = 1) -> void:
	if _is_dead:
		return
	
	_hp -= damage
	_shake()
	
	if _hp <= 0:
		_die()

func _shake() -> void:
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
	
	# quick cartoony wobble
	_shake_tween = create_tween()
	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.set_ease(Tween.EASE_OUT)
	
	var a := deg_to_rad(4.0)
	_shake_tween.tween_property(self, "rotation:z", a, 0.06)
	_shake_tween.tween_property(self, "rotation:z", -a, 0.08)
	_shake_tween.tween_property(self, "rotation:z", 0.0, 0.06)

func _die() -> void:
	_is_dead = true
	
	# VFX
	if poof_scene != null:
		var poof := poof_scene.instantiate() as Node3D
		get_parent().add_child(poof)
		poof.global_position = global_position
	
	# Spawn logs
	if logs_scene != null:
		var logs := logs_scene.instantiate() as Node3D
		get_parent().add_child(logs)
		logs.global_position = global_position
	
	queue_free()
