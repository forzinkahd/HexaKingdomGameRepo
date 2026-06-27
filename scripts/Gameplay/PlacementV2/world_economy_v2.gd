class_name WorldEconomyV2
extends Node

signal resources_changed

@export var wood: int = 200
@export var stone: int = 30
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

	add_resource(definition.produces_resource, definition.production_amount)


func add_resource(resource: BuildingDefinition.ProducedResource, amount: int) -> void:
	if amount <= 0:
		return

	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			wood += amount
		BuildingDefinition.ProducedResource.STONE:
			stone += amount
		BuildingDefinition.ProducedResource.FOOD:
			food += amount
		BuildingDefinition.ProducedResource.GOLD:
			gold += amount
		_:
			return

	resources_changed.emit()


func remove_resource(resource: BuildingDefinition.ProducedResource, amount: int) -> bool:
	if amount <= 0:
		return true

	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			if wood < amount:
				return false
			wood -= amount
		BuildingDefinition.ProducedResource.STONE:
			if stone < amount:
				return false
			stone -= amount
		BuildingDefinition.ProducedResource.FOOD:
			if food < amount:
				return false
			food -= amount
		BuildingDefinition.ProducedResource.GOLD:
			if gold < amount:
				return false
			gold -= amount
		_:
			return false

	resources_changed.emit()
	return true


func get_amount(resource: BuildingDefinition.ProducedResource) -> int:
	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			return wood
		BuildingDefinition.ProducedResource.STONE:
			return stone
		BuildingDefinition.ProducedResource.FOOD:
			return food
		BuildingDefinition.ProducedResource.GOLD:
			return gold
		_:
			return 0


func summary() -> String:
	return "Wood: %d   Stone: %d   Food: %d   Gold: %d" % [wood, stone, food, gold]


func get_save_data() -> Dictionary:
	return {
		"wood": get_amount(BuildingDefinition.ProducedResource.WOOD),
		"stone": get_amount(BuildingDefinition.ProducedResource.STONE),
		"food": get_amount(BuildingDefinition.ProducedResource.FOOD),
		"gold": get_amount(BuildingDefinition.ProducedResource.GOLD)
	}


func load_save_data(data: Dictionary) -> void:
	set_resource(BuildingDefinition.ProducedResource.WOOD, int(data.get("wood", 0)))
	set_resource(BuildingDefinition.ProducedResource.STONE, int(data.get("stone", 0)))
	set_resource(BuildingDefinition.ProducedResource.FOOD, int(data.get("food", 0)))
	set_resource(BuildingDefinition.ProducedResource.GOLD, int(data.get("gold", 0)))


func set_resource(resource: BuildingDefinition.ProducedResource, amount: int) -> void:
	amount = max(0, amount)
	match resource:
		BuildingDefinition.ProducedResource.WOOD:
			wood = amount
		BuildingDefinition.ProducedResource.STONE:
			stone = amount
		BuildingDefinition.ProducedResource.FOOD:
			food = amount
		BuildingDefinition.ProducedResource.GOLD:
			gold = amount
		_:
			return
	resources_changed.emit()
