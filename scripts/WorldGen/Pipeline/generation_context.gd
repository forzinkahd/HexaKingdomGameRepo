# scripts/WorldGen/pipeline/generation_context.gd
class_name GenerationContext
extends RefCounted

var settings: GenerationSettings
var rng: RandomNumberGenerator
var noise: FastNoiseLite
var theme: WorldTheme

var noise_min: float = INF
var noise_max: float = -INF


func setup(settings: GenerationSettings, theme: WorldTheme) -> GenerationContext:
	var ctx := GenerationContext.new()
	ctx.settings = settings
	ctx.theme = theme
	ctx.rng = RandomNumberGenerator.new()

	if settings.map_seed == 0:
		ctx.rng.randomize()
		settings.noise.seed = ctx.rng.randi()
	else:
		ctx.rng.seed = settings.map_seed
		settings.noise.seed = settings.map_seed

	ctx.noise = settings.noise
	return ctx
