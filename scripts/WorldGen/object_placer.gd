extends Node
class_name ObjectPlacer

# from Prototype, either rework for props or delete at some point 10.02.2026

# ====================================
# IS THIS STILL IN USE????
# ====================================


# Spawn an object on a tile
func spawn_on_tile(voxel : Voxel, scene : PackedScene):
	if not voxel or not scene:
		push_warning("tile not found!")
		return

	var instance = scene.instantiate()
	add_child(instance)
	call_deferred("position_object", instance, voxel.world_position, 1)


func position_object(object : Node3D, target_location : Vector3, add_height : float = 0):
	object.position = target_location
	object.position.y += add_height

func clear_objects():
	var children = get_children()
	for c in children:
		c.free()
