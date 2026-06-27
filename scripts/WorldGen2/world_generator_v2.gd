class_name WorldGeneratorV2
extends RefCounted

signal world_generated

var current_seed: int = 0

func generate(settings: GenerationSettingsV2) -> WorldMapData:
	var prepared := _prepare_settings(settings)
	var map := WorldMapData.new()
	map.seed = prepared.map_seed
	current_seed = map.seed
	
	LayoutStage.new().run(prepared, map)
	HeightStage.new().run(prepared, map)
	WaterStage.new().run(prepared, map)
	BiomeStage.new().run(prepared, map)
	CoastStage.new().run(prepared, map)
	
	world_generated.emit()
	return map

func _prepare_settings(settings: GenerationSettingsV2) -> GenerationSettingsV2:
	var result := settings
	if result == null:
		result = GenerationSettingsV2.new()
	if result.noise == null:
		result.noise = FastNoiseLite.new()
	if result.map_seed == 0:
		result.map_seed = randi()
	result.noise.seed = result.map_seed
	return result
