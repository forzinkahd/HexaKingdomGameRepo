class_name BuildingPreviewV2
extends Node3D

@export var y_offset: float = 0.08
@export var valid_color: Color = Color(0.2, 1.0, 0.2, 0.45)
@export var invalid_color: Color = Color(1.0, 0.15, 0.1, 0.45)

var _preview_visual: Node3D
var _last_definition: BuildingDefinition


func _ready() -> void:
	visible = false


func show_preview(
	tile: WorldTile,
	visual_node: Node3D,
	definition: BuildingDefinition,
	is_valid: bool
) -> void:
	if tile == null:
		visible = false
		return

	if definition != _last_definition or _preview_visual == null:
		_rebuild_preview(definition)

	var base_position := tile.world_position

	if visual_node != null:
		base_position = visual_node.global_position

	global_position = base_position + Vector3.UP * y_offset
	_apply_preview_material(is_valid)
	visible = true


func hide_preview() -> void:
	visible = false


func _rebuild_preview(definition: BuildingDefinition) -> void:
	for child in get_children():
		child.queue_free()

	_last_definition = definition
	_preview_visual = null

	if definition != null and definition.scene != null:
		_preview_visual = definition.scene.instantiate() as Node3D

	if _preview_visual == null:
		_preview_visual = _fallback_preview_visual()

	add_child(_preview_visual)


func _fallback_preview_visual() -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "FallbackPreviewVisual"

	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 0.7)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3.UP * 0.35

	return mesh_instance


func _apply_preview_material(is_valid: bool) -> void:
	var color := valid_color if is_valid else invalid_color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_apply_material_recursive(self, mat)


func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material

	for child in node.get_children():
		_apply_material_recursive(child, material)
