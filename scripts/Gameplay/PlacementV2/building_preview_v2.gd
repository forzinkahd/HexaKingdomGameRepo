class_name BuildingPreviewV2
extends Node3D

@export var valid_color: Color = Color(0.2, 1.0, 0.25, 0.55)
@export var invalid_color: Color = Color(1.0, 0.15, 0.1, 0.55)
@export var fallback_radius: float = 0.72
@export var fallback_height: float = 0.12

var current_definition: BuildingDefinition
var current_instance: Node3D
var fallback_mesh: MeshInstance3D


func _ready() -> void:
	visible = false


func set_definition(definition: BuildingDefinition) -> void:
	current_definition = definition
	_rebuild_preview_visual()


func show_for_tile(tile: WorldTile, visual_node: Node3D, allowed: bool) -> void:
	if tile == null:
		visible = false
		return

	var base_position := tile.world_position
	if visual_node != null:
		base_position = visual_node.global_position

	var offset := 0.18
	if current_definition != null:
		offset = current_definition.preview_y_offset

	global_position = base_position + Vector3.UP * offset
	_apply_preview_material(allowed)
	visible = true


func hide_preview() -> void:
	visible = false


func _rebuild_preview_visual() -> void:
	for child in get_children():
		child.queue_free()

	current_instance = null
	fallback_mesh = null

	if current_definition != null and current_definition.scene != null:
		var node := current_definition.scene.instantiate()
		if node is Node3D:
			current_instance = node as Node3D
			add_child(current_instance)
			_apply_preview_material(false)
			return
		else:
			node.queue_free()

	fallback_mesh = MeshInstance3D.new()
	fallback_mesh.name = "FallbackBuildingPreview"

	var mesh := CylinderMesh.new()
	mesh.top_radius = fallback_radius
	mesh.bottom_radius = fallback_radius
	mesh.height = fallback_height
	mesh.radial_segments = 32
	fallback_mesh.mesh = mesh

	add_child(fallback_mesh)
	_apply_preview_material(false)


func _apply_preview_material(allowed: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = valid_color if allowed else invalid_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_apply_material_recursive(self, mat)


func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material

	for child in node.get_children():
		_apply_material_recursive(child, material)
