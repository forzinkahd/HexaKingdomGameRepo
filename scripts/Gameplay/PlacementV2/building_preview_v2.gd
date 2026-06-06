class_name BuildingPreviewV2
extends Node3D

@export var y_offset: float = 0.08
@export var valid_color: Color = Color(0.2, 1.0, 0.2, 0.45)
@export var invalid_color: Color = Color(1.0, 0.15, 0.1, 0.45)
@export var footprint_valid_color: Color = Color(0.2, 1.0, 0.2, 0.18)
@export var footprint_invalid_color: Color = Color(1.0, 0.15, 0.1, 0.18)

var _preview_visual: Node3D
var _last_definition: BuildingDefinition
var _footprint_root: Node3D


func _ready() -> void:
	visible = false
	_footprint_root = Node3D.new()
	_footprint_root.name = "FootprintPreview"
	add_child(_footprint_root)


func show_preview(
	tile: WorldTile,
	visual_node: Node3D,
	definition: BuildingDefinition,
	is_valid: bool,
	footprint_coords: Array[Vector2i] = [],
	world_map: WorldMapData = null
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
	_rebuild_footprint(tile, is_valid, footprint_coords, world_map)
	visible = true


func hide_preview() -> void:
	visible = false


func _rebuild_preview(definition: BuildingDefinition) -> void:
	for child in get_children():
		child.queue_free()

	_footprint_root = Node3D.new()
	_footprint_root.name = "FootprintPreview"
	add_child(_footprint_root)

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


func _rebuild_footprint(
	center_tile: WorldTile,
	is_valid: bool,
	footprint_coords: Array[Vector2i],
	world_map: WorldMapData
) -> void:
	if _footprint_root == null:
		return

	for child in _footprint_root.get_children():
		child.queue_free()

	if footprint_coords.size() <= 1 or world_map == null:
		return

	var material := _make_footprint_material(is_valid)

	for coord in footprint_coords:
		if coord == center_tile.coord:
			continue

		var footprint_tile := world_map.get_tile(coord)
		if footprint_tile == null:
			continue

		var marker := _make_footprint_marker(material)
		marker.position = footprint_tile.world_position - center_tile.world_position + Vector3.UP * 0.03
		_footprint_root.add_child(marker)


func _make_footprint_marker(material: Material) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "FootprintMarker"

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.68
	mesh.bottom_radius = 0.68
	mesh.height = 0.025
	mesh.radial_segments = 32
	marker.mesh = mesh
	marker.material_override = material

	return marker


func _make_footprint_material(is_valid: bool) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = footprint_valid_color if is_valid else footprint_invalid_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _apply_preview_material(is_valid: bool) -> void:
	var color := valid_color if is_valid else invalid_color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if _preview_visual != null:
		_apply_material_recursive(_preview_visual, mat)


func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material

	for child in node.get_children():
		_apply_material_recursive(child, material)
