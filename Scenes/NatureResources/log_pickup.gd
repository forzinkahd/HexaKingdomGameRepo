extends Node3D
class_name LogPickup

#var claimed: bool = false
@export var amount: int = 1
var is_reserved: bool = false


func _ready() -> void:
	var s: float = clamp(1.0 + float(amount - 1) * 0.12, 1.0, 1.8)
	scale = Vector3.ONE * s


func reserve() -> bool:
	if is_reserved:
		return false
	is_reserved = true
	return true
