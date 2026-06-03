# scripts/WorldInteraction/selected_tile_marker.gd
class_name SelectedTileMarker
extends Node3D

@export var y_offset: float = 0.08

func bind_picker(picker: WorldTilePicker) -> void:
	picker.tile_selected.connect(_on_tile_selected)

func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	if visual_node == null:
		return

	global_position = visual_node.global_position + Vector3.UP * y_offset
	visible = true
