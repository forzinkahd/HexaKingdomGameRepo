extends Node
class_name PreviewSystem

# ----------------------------------------
# SHOWING/CLEARING PREVIEWS 
# ----------------------------------------

var preview_by_xz := {} # Vector2i -> { "type": StringName, "variant": int, "yaw": float }


func set_road_preview(xz: Vector2i, variant: int, yaw: float) -> void:
	preview_by_xz[xz] = {"type": &"road", "variant": variant, "yaw": yaw}


func clear_preview(xz: Vector2i) -> void:
	preview_by_xz.erase(xz)


func has_preview(xz: Vector2i) -> bool:
	return preview_by_xz.has(xz)
