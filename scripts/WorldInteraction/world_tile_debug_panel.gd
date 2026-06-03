class_name WorldTileDebugPanel
extends Label

@export var picker: WorldTilePicker
@export var show_when_empty: bool = true


func _ready() -> void:
	text = "No tile selected"

	if picker != null:
		bind_picker(picker)


func bind_picker(target_picker: WorldTilePicker) -> void:
	if target_picker == null:
		return

	if target_picker.tile_selected.is_connected(_on_tile_selected):
		return

	target_picker.tile_selected.connect(_on_tile_selected)


func _on_tile_selected(tile: WorldTile, visual_node: Node3D) -> void:
	if tile == null:
		text = "No tile selected"
		return

	text = _format_tile(tile)


func _format_tile(tile: WorldTile) -> String:
	return (
		"Selected Tile\n"
		+ "Coord: %s\n" % [str(tile.coord)]
		+ "World: %s\n" % [_format_vec3(tile.world_position)]
		+ "Height: %s\n" % [str(tile.height_units)]
		+ "Terrain: %s\n" % [_terrain_name(tile.terrain_kind)]
		+ "Water: %s\n" % [_water_name(tile.water_kind)]
		+ "Biome: %s\n" % [_biome_name(tile.biome_kind)]
		+ "Coast Mask: %s\n" % [str(tile.coast_mask)]
		+ "Walkable: %s\n" % [str(tile.walkable)]
		+ "Buildable: %s" % [str(tile.buildable)]
	)


func _format_vec3(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]


func _terrain_name(value: int) -> String:
	match value:
		WorldTile.TerrainKind.GRASS:
			return "Grass"
		WorldTile.TerrainKind.DIRT:
			return "Dirt"
		WorldTile.TerrainKind.STONE:
			return "Stone"
		WorldTile.TerrainKind.SAND:
			return "Sand"
		_:
			return "Unknown(%s)" % [str(value)]


func _water_name(value: int) -> String:
	match value:
		WorldTile.WaterKind.NONE:
			return "None"
		WorldTile.WaterKind.OCEAN:
			return "Ocean"
		WorldTile.WaterKind.LAKE:
			return "Lake"
		_:
			return "Unknown(%s)" % [str(value)]


func _biome_name(value: int) -> String:
	match value:
		WorldTile.BiomeKind.NONE:
			return "None"
		WorldTile.BiomeKind.PLAINS:
			return "Plains"
		WorldTile.BiomeKind.COAST:
			return "Coast"
		WorldTile.BiomeKind.FOREST:
			return "Forest"
		WorldTile.BiomeKind.HILLS:
			return "Hills"
		WorldTile.BiomeKind.MOUNTAIN:
			return "Mountain"
		_:
			return "Unknown(%s)" % [str(value)]
