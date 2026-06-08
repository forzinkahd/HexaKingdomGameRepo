class_name BuildingRegistryDebugLabelV2
extends Label

@export var registry: BuildingRegistryV2


func _ready() -> void:
	if registry != null and not registry.registry_changed.is_connected(_refresh):
		registry.registry_changed.connect(_refresh)

	_refresh()


func _refresh(_arg = null) -> void:
	if registry == null:
		text = "Registry: missing"
		return

	var lines: Array[String] = []
	lines.append("Buildings placed: %d" % [registry.get_total_count()])

	var ids: Array = registry._count_by_id.keys()
	ids.sort()

	for id in ids:
		lines.append("%s: %d" % [str(id), registry.get_count(id)])

	text = "\n".join(lines)
