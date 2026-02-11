extends CanvasLayer

@onready var wood_label: Label = $WoodLabel


func _ready() -> void:
	WorldMap.wood_changed.connect(_on_wood_changed)
	_on_wood_changed(WorldMap.wood_logs)


func _on_wood_changed(v: int) -> void:
	wood_label.text = "Wood: %d" % v
