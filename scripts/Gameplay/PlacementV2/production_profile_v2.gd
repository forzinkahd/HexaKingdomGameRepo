class_name ProductionProfileV2
extends Resource

@export var resource: BuildingDefinition.ProducedResource = BuildingDefinition.ProducedResource.WOOD
@export_range(0.1, 9999.0) var tick_interval_seconds: float = 5.0
@export_range(0.0, 100.0) var productivity_multiplier: float = 1.0


func resource_name() -> String:
	return BuildingDefinition.resource_name(resource)
