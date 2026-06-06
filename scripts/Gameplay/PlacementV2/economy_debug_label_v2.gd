class_name EconomyDebugLabelV2
extends Label

@export var economy: WorldEconomyV2


func _ready() -> void:
	if economy != null:
		if not economy.resources_changed.is_connected(_refresh):
			economy.resources_changed.connect(_refresh)

	_refresh()


func _refresh() -> void:
	if economy == null:
		text = "Economy: missing"
		return

	text = economy.summary()
