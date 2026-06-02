# scripts/WorldGen/pipeline/world_generation_pipeline.gd
class_name WorldGenerationPipeline
extends RefCounted

func generate(settings: GenerationSettings, theme: WorldTheme) -> GenerationResult:
	var ctx := GenerationBootstrap.setup(settings, theme)

	var tiles := MapLayoutStage.new().run(ctx)
	NoiseStage.new().run(ctx, tiles)
	HeightStage.new().run(ctx, tiles)
	WaterStage.new().run(ctx, tiles)
	LakeStage.new().run(ctx, tiles)
	BiomeStage.new().run(ctx, tiles)

	var result := GenerationResult.from_tiles(tiles)

	CoastResolver.new().run(result.surface_tiles, result.tiles_by_xz)
	# Later:
	# RiverResolver.new().run(result)
	# RoadResolver.new().run(result)

	return result
