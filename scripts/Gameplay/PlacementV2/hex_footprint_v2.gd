class_name HexFootprintV2
extends RefCounted

# Axial hex directions for Vector2i(q, r).
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


static func coords_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if radius <= 0:
		result.append(center)
		return result

	for dq in range(-radius, radius + 1):
		var min_dr: int = max(-radius, -dq - radius)
		var max_dr: int = min(radius, -dq + radius)

		for dr in range(min_dr, max_dr + 1):
			result.append(Vector2i(center.x + dq, center.y + dr))

	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := -dq - dr
	return int((abs(dq) + abs(dr) + abs(ds)) / 2)
