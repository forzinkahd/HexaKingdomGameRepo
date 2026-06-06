class_name WorldEconomyV2
extends Node

signal resources_changed

@export var wood: int = 200
@export var stone: int = 100
@export var food: int = 0
@export var gold: int = 0


func can_afford(definition: BuildingDefinition) -> bool:
	if definition == null:
		return false

	return (
		wood >= definition.cost_wood
		and stone >= definition.cost_stone
		and food >= definition.cost_food
		and gold >= definition.cost_gold
	)


func missing_cost_reason(definition: BuildingDefinition) -> String:
	if definition == null:
		return "No building selected"

	var missing: Array[String] = []

	if wood < definition.cost_wood:
		missing.append("wood %d/%d" % [wood, definition.cost_wood])
	if stone < definition.cost_stone:
		missing.append("stone %d/%d" % [stone, definition.cost_stone])
	if food < definition.cost_food:
		missing.append("food %d/%d" % [food, definition.cost_food])
	if gold < definition.cost_gold:
		missing.append("gold %d/%d" % [gold, definition.cost_gold])

	if missing.is_empty():
		return "OK"

	return "Missing " + ", ".join(missing)


func spend_for(definition: BuildingDefinition) -> bool:
	if not can_afford(definition):
		return false

	wood -= definition.cost_wood
	stone -= definition.cost_stone
	food -= definition.cost_food
	gold -= definition.cost_gold

	resources_changed.emit()
	return true


func refund_for(definition: BuildingDefinition) -> void:
	if definition == null:
		return

	wood += definition.cost_wood
	stone += definition.cost_stone
	food += definition.cost_food
	gold += definition.cost_gold

	resources_changed.emit()


func add_production(definition: BuildingDefinition) -> void:
	if definition == null:
		return

	if definition.production_amount <= 0:
		return

	match definition.produces_resource:
		BuildingDefinition.ProducedResource.WOOD:
			wood += definition.production_amount
		BuildingDefinition.ProducedResource.STONE:
			stone += definition.production_amount
		BuildingDefinition.ProducedResource.FOOD:
			food += definition.production_amount
		BuildingDefinition.ProducedResource.GOLD:
			gold += definition.production_amount
		_:
			return

	resources_changed.emit()


func summary() -> String:
	return "Wood: %d   Stone: %d   Food: %d   Gold: %d" % [wood, stone, food, gold]
