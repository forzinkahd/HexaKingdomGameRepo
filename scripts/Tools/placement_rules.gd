extends Node
class_name PlacementRules

# -----------------------------------
# CAN PLACE X ON THIS VOXEL? checks
# -----------------------------------

# After big refactor 25.02.26

func can_place_road(v: Voxel) -> bool:
	if v == null: return false
	if v.buffer: return false
	if v.has_building(): return false
	if v.has_resource(): return false
	if v.water: return false
	if v.overlay == Voxel.Overlay.RIVER: return false
	return true


func can_place_building(v: Voxel) -> bool:
	if v == null: return false
	if not v.placeable: return false
	if v.has_building(): return false
	if v.has_resource(): return false
	if v.occupier != null: return false
	return true
