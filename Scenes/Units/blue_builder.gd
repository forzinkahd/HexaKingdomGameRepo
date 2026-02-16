extends Villager
class_name Builder

# later: building tasks, repair, faster building

func can_receive_move_commands() -> bool:
	return true

func command_move(dest: Vector3) -> void:
	move_to_world(dest)
