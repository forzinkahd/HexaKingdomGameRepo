extends Node

enum voxel_type {AIR, BEDROCK, GRASS, DIRT, STONE, SAND}

# Convert voxel_type to position in our texture_atlas, bottom is optional
const tile_map = {
	voxel_type.BEDROCK: {
		"top": Vector2(0, 1),
		"side": Vector2(0, 1)
	},
	voxel_type.GRASS: {
		"top": Vector2i(0, 0),
		"side": Vector2i(1, 0),
		"bottom": Vector2i(2, 0),
		"underground": voxel_type.DIRT
	},
	voxel_type.DIRT: {
		"top": Vector2i(2, 0),
		"side": Vector2i(3, 0),
		"surface": voxel_type.GRASS
	},
	voxel_type.STONE: {
		"top": Vector2i(4, 0),
		"side": Vector2i(5, 0)
	},
	voxel_type.SAND: {
		"top": Vector2i(6, 0),
		"side": Vector2i(7, 0),
		"bottom": Vector2i(8, 0)
	}
}

## Shorthand for different layout/neighbor configurations depending on map-shape and stagger
const HEXAGONAL_NEIGHBOR_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, -1),  # Face 0: Top-Right → NE
	Vector2i(1, 0),   # Face 1: Right → E
	Vector2i(0, 1),   # Face 2: Bottom-Right → SE
	Vector2i(-1, 1),  # Face 3: Bottom-Left → SW
	Vector2i(-1, 0),  # Face 4: Left → W
	Vector2i(0, -1)   # Face 5: Top-Left → NW
]

const NEIGHBOR_DIRECTIONS_EVEN: Array[Vector2i] = [ # For even rows (x % 2 == 0) 
	Vector2i(1, -1), # Northeast 
	Vector2i(1, 0), # East 
	Vector2i(0, 1), # Southeast 
	Vector2i(-1, 0), # Southwest 
	Vector2i(-1, -1), # Northwest 
	Vector2i(0, -1) # West 
	] 

const NEIGHBOR_DIRECTIONS_ODD: Array[Vector2i] = [ # For odd rows (x % 2 == 1) 
	Vector2i(1, 0), # Northeast 
	Vector2i(1, 1), # East 
	Vector2i(0, 1), # Southeast 
	Vector2i(-1, 1), # Southwest 
	Vector2i(-1, 0), # Northwest 
	Vector2i(0, -1) # West 
	]


const ROAD_LETTER_TO_INDEX := {
	"A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "F": 5,
	"G": 6, "H": 7, "I": 8, "J": 9, "K": 10, "L": 11, "M": 12
}

const RIVER_LETTER_TO_INDEX := {
	"A": 0, "B": 1, "C": 2, "D": 3, "E": 4, "F": 5,
	"G": 6, "H": 7, "I": 8, "J": 9, "K": 10, "L": 11, "M": 12,
	"N": 13, "O": 14, "P": 15
}

const COAST_LETTER_TO_INDEX := {
	"A": 0, "B": 1, "C": 2, "D": 3
}

static func get_tile_neighbor_table(row) -> Array[Vector2i]:
	if WorldMap.is_map_staggered:
		if row % 2 == 0:
			return NEIGHBOR_DIRECTIONS_EVEN
		else:
			return NEIGHBOR_DIRECTIONS_ODD
	return HEXAGONAL_NEIGHBOR_DIRECTIONS


static func neighbor_dirs_for_col(col: int) -> Array[Vector2i]:
	return get_tile_neighbor_table(col) # must be length 6


static func neighbor_key(v: Voxel, i: int) -> Vector2i:
	var dirs := neighbor_dirs_for_col(v.grid_position_xz.x)
	return v.grid_position_xz + dirs[i]


static func mask_bit_count(mask: int) -> int:
	var c := 0
	for i in range(6):
		if (mask & (1 << i)) != 0:
			c += 1
	return c


static func mask_is_straight(mask: int) -> bool:
	return mask == ((1<<0)|(1<<3)) \
		or mask == ((1<<1)|(1<<4)) \
		or mask == ((1<<2)|(1<<5))


static func variant_letter_from_mask(mask: int) -> String:
	var n := mask_bit_count(mask)
	match n:
		0:
			return "M"
		1:
			return "C"
		2:
			return "A" if mask_is_straight(mask) else "B"
		3:
			return "G"
		4:
			return "H"
		5:
			return "L"
		6:
			return "I"
		_:
			return "M"


static func coast_letter_from_mask(mask: int) -> String:
	var n := mask_bit_count(mask)
	if n <= 0:
		push_warning("coast is weird")
		return "A"	# shouldnt trigger, but safefail
	if n == 1:
		return "A"
	if n == 2:
		return "B"
	if n == 3:
		return "C"
	return "D"


static func yaw_from_mask_centroid(mask: int, offset_steps: int = 0) -> float:
	if mask == 0:
		return 0.0

	var step := TAU / 6.0
	var v := Vector2.ZERO

	# Sum unit vectors for all set bits (stable for multi-edge masks)
	for i in range(6):
		if (mask & (1 << i)) != 0:
			v += Vector2(cos(step * float(i)), sin(step * float(i)))

	if v.length() < 0.0001:
		return 0.0

	var angle := atan2(v.y, v.x)
	var idx := int(round(angle / step)) % 6
	if idx < 0:
		idx += 6

	return float(idx + offset_steps) * step


"""static func yaw_from_mask(mask: int, edge_offset_steps: int = 1) -> float:
	var first := -1
	for i in range(6):
		if (mask & (1 << i)) != 0:
			first = i
			break
	if first == -1:
		return 0.0
	return float(first + edge_offset_steps) * (TAU / 6.0)"""
