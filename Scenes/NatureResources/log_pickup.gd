extends Node3D
class_name LogPickup

#var claimed: bool = false
@export var amount: int = 1
var is_reserved: bool = false
var _reserved := false
var _collected := false


func _ready() -> void:
	var s: float = clamp(1.0 + float(amount - 1) * 0.12, 1.0, 1.8)
	scale = Vector3.ONE * s


func reserve() -> bool:
	if is_reserved:
		return false
	is_reserved = true
	return true

func collect_and_free() -> void:
	if _collected:
		return
	_collected = true

	var t := get_tree().create_tween()
	t.tween_property(self, "scale", scale * 1.15, 0.08)
	t.tween_property(self, "scale", Vector3.ZERO, 0.10)
	await t.finished
	queue_free()
