class_name HeightStage
extends RefCounted

func run(settings: GenerationSettingsV2, map: WorldMapData) -> void:
	var noise := settings.noise
	if noise == null:
		noise = FastNoiseLite.new()
		settings.noise = noise
	for tile in map.tiles:
		var n := noise.get_noise_2d(float(tile.coord.x) / max(settings.noise_scale, 0.0001), float(tile.coord.y) / max(settings.noise_scale, 0.0001))
		var normalized := clampf((n + 1.0) * 0.5, 0.0, 1.0)
		var curved := pow(normalized, settings.height_curve)
		tile.noise_height = normalized
		tile.height_units = int(round(curved * float(settings.max_height_units)))
