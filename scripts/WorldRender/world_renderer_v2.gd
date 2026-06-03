class_name WorldRendererV2
extends RefCounted


@export var use_debug_materials: bool = true

var _debug_materials: Dictionary = {}

func _ready() -> void:
	_create_debug_materials()


func render(map: WorldMapData, settings: GenerationSettingsV2, theme: WorldTheme = null) -> Node3D:
	if use_debug_materials and _debug_materials.is_empty():
		_create_debug_materials()
	
	var root := Node3D.new()
	root.name = "WorldGen2Root"
	if map == null:
		return root
	for tile in map.tiles:
		_render_tile(root, tile, settings, theme)
	return root

func _render_tile(root: Node3D, tile: WorldTile, settings: GenerationSettingsV2, theme: WorldTheme) -> void:
	_render_padding(root, tile, settings, theme)
	var scene := _scene_for_tile(tile, theme)
	var node: Node3D = null
	if scene != null:
		node = scene.instantiate() as Node3D
	elif settings.spawn_debug_fallback_meshes:
		node = _fallback_hex(tile, settings)
	if node == null:
		return
	node.name = "Tile_%s_%s" % [tile.coord.x, tile.coord.y]
	node.position = Vector3(tile.world_position.x, _tile_y(tile, settings), tile.world_position.z)
	if tile.coast_variant_index >= 0:
		node.rotation.y = tile.coast_yaw
	_tag_tile_node_recursive(node, tile)
	
	if use_debug_materials:
		_apply_debug_material(node, tile)
	
	root.add_child(node)
	_ensure_pick_collider(node, tile)		# Early debug

func _render_padding(root: Node3D, tile: WorldTile, settings: GenerationSettingsV2, theme: WorldTheme) -> void:
	if not settings.render_padding or theme == null or theme.grass_padding_scene == null:
		return
	if tile.is_water():
		return
	var steps : Variant = min(tile.height_units, settings.max_padding_steps_to_render)
	for i in range(steps):
		var padding := theme.grass_padding_scene.instantiate() as Node3D
		if padding == null:
			continue
		padding.name = "Padding_%s_%s_%s" % [tile.coord.x, tile.coord.y, i]
		padding.position = Vector3(tile.world_position.x, float(i) * settings.height_step, tile.world_position.z)
		_tag_tile_node_recursive(padding, tile)
		root.add_child(padding)

func _tile_y(tile: WorldTile, settings: GenerationSettingsV2) -> float:
	if tile.is_water():
		return float(settings.sea_level_units) * settings.height_step
	return float(tile.height_units) * settings.height_step

func _scene_for_tile(tile: WorldTile, theme: WorldTheme) -> PackedScene:
	if theme == null:
		return null
	if tile.coast_variant_index >= 0 and tile.coast_variant_index < theme.coast_variants.size():
		return theme.coast_variants[tile.coast_variant_index]
	if tile.is_water():
		return theme.sea_top_scene
	match tile.terrain_kind:
		WorldTile.TerrainKind.STONE:
			if theme.stone_top_scene != null:
				return theme.stone_top_scene
		WorldTile.TerrainKind.DIRT:
			if theme.dirt_top_scene != null:
				return theme.dirt_top_scene
		WorldTile.TerrainKind.SAND:
			if theme.dirt_top_scene != null:
				return theme.dirt_top_scene
	return theme.grass_top_scene

func _fallback_hex(tile: WorldTile, settings: GenerationSettingsV2) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 6
	mesh.top_radius = settings.tile_size
	mesh.bottom_radius = settings.tile_size
	mesh.height = max(settings.height_step * 0.15, 0.05)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = mesh.height * 0.5
	return mesh_instance

func _tag_tile_node_recursive(node: Node, tile: WorldTile) -> void:
	node.set_meta("world_tile", tile)
	node.set_meta("coord", tile.coord)
	for child in node.get_children():
		_tag_tile_node_recursive(child, tile)


# Early debug: Collider for raycast to select tile
func _ensure_pick_collider(root: Node3D, tile: WorldTile) -> void:
	var body := StaticBody3D.new()
	body.name = "PickCollider"

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.12, 1.6)
	shape.shape = box
	shape.position = Vector3(0.0, 0.08, 0.0)

	body.add_child(shape)
	root.add_child(body)

	root.set_meta("world_tile", tile)
	root.set_meta("coord", tile.coord)

	body.set_meta("world_tile", tile)
	body.set_meta("coord", tile.coord)


func _create_debug_materials() -> void:
	_debug_materials.clear()

	_debug_materials["ocean"] = _make_material(Color(0.1, 0.25, 0.8))
	_debug_materials["coast"] = _make_material(Color(0.85, 0.75, 0.35))
	_debug_materials["plains"] = _make_material(Color(0.25, 0.65, 0.25))
	_debug_materials["forest"] = _make_material(Color(0.1, 0.4, 0.15))
	_debug_materials["hills"] = _make_material(Color(0.45, 0.35, 0.2))
	_debug_materials["mountain"] = _make_material(Color(0.55, 0.55, 0.55))
	_debug_materials["fallback"] = _make_material(Color(0.8, 0.8, 0.8))

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat

func _apply_debug_material(root: Node, tile: WorldTile) -> void:
	var mat := _debug_material_for_tile(tile)
	_apply_material_recursive(root, mat)

func _debug_material_for_tile(tile: WorldTile) -> Material:
	var fallback: Material = _debug_materials.get("fallback", null)

	if fallback == null:
		fallback = _make_material(Color(0.8, 0.8, 0.8))
		_debug_materials["fallback"] = fallback

	if tile.water_kind == WorldTile.WaterKind.OCEAN:
		return _debug_materials.get("ocean", fallback)

	if tile.coast_mask != 0:
		return _debug_materials.get("coast", fallback)

	match tile.biome_kind:
		WorldTile.BiomeKind.PLAINS:
			return _debug_materials.get("plains", fallback)
		WorldTile.BiomeKind.FOREST:
			return _debug_materials.get("forest", fallback)
		WorldTile.BiomeKind.HILLS:
			return _debug_materials.get("hills", fallback)
		WorldTile.BiomeKind.MOUNTAIN:
			return _debug_materials.get("mountain", fallback)

	return fallback

func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material

	for child in node.get_children():
		_apply_material_recursive(child, material)
