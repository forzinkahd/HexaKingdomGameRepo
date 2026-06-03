class_name HexGrid
extends RefCounted

const AXIAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

const COAST_BAKED_ROTATION := -PI / 6.0 - PI * 2.0 / 3.0

static func axial_to_world(coord: Vector2i, tile_size: float) -> Vector3:
	var q := float(coord.x)
	var r := float(coord.y)
	var x := tile_size * sqrt(3.0) * (q + r * 0.5)
	var z := tile_size * 1.5 * r
	return Vector3(x, 0.0, z)

static func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var aq := a.x
	var ar := a.y
	var as_ := -aq - ar
	var bq := b.x
	var br := b.y
	var bs := -bq - br
	return int((abs(aq - bq) + abs(ar - br) + abs(as_ - bs)) / 2)

static func hexagonal_positions(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		var r1: int = max(-radius, -q - radius)
		var r2: int = min(radius, -q + radius)
		for r in range(r1, r2 + 1):
			result.append(Vector2i(q, r))
	return result

static func corner_coord(corner: int, radius: int) -> Vector2i:
	match corner:
		GenerationSettingsV2.OceanCorner.EAST:
			return Vector2i(radius, 0)
		GenerationSettingsV2.OceanCorner.NORTH_EAST:
			return Vector2i(radius, -radius)
		GenerationSettingsV2.OceanCorner.NORTH_WEST:
			return Vector2i(0, -radius)
		GenerationSettingsV2.OceanCorner.WEST:
			return Vector2i(-radius, 0)
		GenerationSettingsV2.OceanCorner.SOUTH_WEST:
			return Vector2i(-radius, radius)
		GenerationSettingsV2.OceanCorner.SOUTH_EAST:
			return Vector2i(0, radius)
		_:
			return Vector2i.ZERO

static func distance_to_edge(coord: Vector2i, radius: int, edge: int) -> int:
	var q := coord.x
	var r := coord.y
	var s := -q - r
	match edge:
		GenerationSettingsV2.OceanEdge.EAST:
			return radius - q
		GenerationSettingsV2.OceanEdge.WEST:
			return radius + q
		GenerationSettingsV2.OceanEdge.NORTH_EAST:
			return radius + s
		GenerationSettingsV2.OceanEdge.SOUTH_WEST:
			return radius - s
		GenerationSettingsV2.OceanEdge.NORTH_WEST:
			return radius + r
		GenerationSettingsV2.OceanEdge.SOUTH_EAST:
			return radius - r
		_:
			return 999999

static func bit_count(mask: int) -> int:
	var count := 0
	var m := mask
	while m != 0:
		count += m & 1
		m >>= 1
	return count

static func longest_contiguous_run(mask: int) -> int:
	var best := 0
	for start in range(6):
		var run := 0
		for offset in range(6):
			var bit := (start + offset) % 6
			if (mask & (1 << bit)) == 0:
				break
			run += 1
		best = max(best, run)
	return best

static func coast_variant_index(mask: int) -> int:
	var bits := bit_count(mask)
	if bits <= 0:
		return -1
	if bits == 1:
		return 0
	var run := longest_contiguous_run(mask)
	if bits == 2 and run == 2:
		return 1
	if bits == 3 and run == 3:
		return 2
	if bits >= 4 and run >= 4:
		return 3
	return 4

static func yaw_from_mask(tile: WorldTile, map: WorldMapData, mask: int) -> float:
	var acc := Vector2.ZERO
	for i in range(6):
		if (mask & (1 << i)) == 0:
			continue
		var n := map.get_tile(tile.coord + AXIAL_DIRECTIONS[i])
		if n != null:
			var dx := n.world_position.x - tile.world_position.x
			var dz := n.world_position.z - tile.world_position.z
			var v := Vector2(dx, dz)
			if v.length() > 0.0001:
				acc += v.normalized()
		else:
			acc += Vector2(float(AXIAL_DIRECTIONS[i].x), float(AXIAL_DIRECTIONS[i].y)).normalized()
	if acc.length() < 0.0001:
		return 0.0
	return atan2(acc.x, acc.y) - COAST_BAKED_ROTATION
