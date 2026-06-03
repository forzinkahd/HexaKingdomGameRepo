class_name SelectedTileMarker
extends Node3D

@export var picker: WorldTilePicker
@export var y_offset: float = 0.16
@export var radius: float = 0.78
@export var height: float = 0.04
@export var marker_color: Color = Color(1.0, 0.85, 0.1, 0.75)

var mesh_instance: MeshInstance3D


func _ready() -> void:
	visible = false
	_create_marker_mesh()

	if picker != null:
		bind_picker(picker)


func bind_picker(target_picker: WorldTilePicker) -> void:
	if target_picker == null:
		return

	if target_picker.tile_selected.is_connected(_on_tile_selected):
		return

	target_picker.tile_selected.connect(_on_tile_selected)


func _create_marker_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "SelectionMarkerMesh"

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	mesh.rings = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = marker_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false

	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat

	add_child(mesh_instance)


func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	if tile == null:
		visible = false
		return

	var base_position := tile.world_position

	if visual_node != null:
		base_position = visual_node.global_position

	global_position = base_position + Vector3.UP * y_offset
	visible = true
