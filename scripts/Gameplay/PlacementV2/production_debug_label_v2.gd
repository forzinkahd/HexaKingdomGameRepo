class_name ProductionDebugLabelV2
extends Label

@export var production: WorldProductionV2
@export var economy: WorldEconomyV2


func _ready() -> void:
	if production != null:
		if not production.production_tick.is_connected(_on_production_tick):
			production.production_tick.connect(_on_production_tick)

		if not production.production_building_registered.is_connected(_refresh):
			production.production_building_registered.connect(_refresh)

		if not production.production_building_unregistered.is_connected(_refresh):
			production.production_building_unregistered.connect(_refresh)

		if not production.productivity_changed.is_connected(_refresh):
			production.productivity_changed.connect(_refresh)

	if economy != null and not economy.resources_changed.is_connected(_refresh):
		economy.resources_changed.connect(_refresh)

	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	if production == null:
		text = "Production: missing"
		return

	var lines: Array[String] = []
	lines.append("Global Production")
	lines.append("Buildings: %d" % [production.production_building_count()])
	lines.append("")

	_append_resource_line(lines, BuildingDefinition.ProducedResource.WOOD)
	_append_resource_line(lines, BuildingDefinition.ProducedResource.STONE)
	_append_resource_line(lines, BuildingDefinition.ProducedResource.FOOD)
	_append_resource_line(lines, BuildingDefinition.ProducedResource.GOLD)

	if economy != null:
		lines.append("")
		lines.append(economy.summary())

	text = "\n".join(lines)


func _append_resource_line(
	lines: Array[String],
	resource: BuildingDefinition.ProducedResource
) -> void:
	var resource_name := BuildingDefinition.resource_name(resource)
	var count := production.get_building_count_for_resource(resource)
	var base := production.get_base_amount_per_tick(resource)
	var multiplier := production.get_productivity_multiplier(resource)
	var amount := production.get_amount_per_tick(resource)
	var progress := production.get_progress_ratio(resource) * 100.0
	var interval := production.get_tick_interval(resource)

	lines.append(
		"%s: %d buildings | base +%d | x%.2f = +%d / %.1fs | %.0f%%" % [
			resource_name,
			count,
			base,
			multiplier,
			amount,
			interval,
			progress
		]
	)


func _on_production_tick(
	resource: BuildingDefinition.ProducedResource,
	resource_name: String,
	amount: int
) -> void:
	_refresh()
