class_name BuildMenuButtonV2
extends Button

signal building_pressed(definition: BuildingDefinition)

@export var show_cost: bool = true
@export var show_production: bool = true
@export var selected_prefix: String = "▶ "

var definition: BuildingDefinition
var selected: bool = false


func setup(source_definition: BuildingDefinition) -> void:
	definition = source_definition
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_update_text()


func set_selected(value: bool) -> void:
	selected = value
	_update_text()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	_update_text()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _on_pressed() -> void:
	if definition == null:
		return

	building_pressed.emit(definition)


func _update_text() -> void:
	if definition == null:
		text = "Missing Building"
		disabled = true
		return

	disabled = false

	var lines: Array[String] = []
	var title := definition.display_name

	if selected:
		title = selected_prefix + title

	lines.append(title)

	var category_name := BuildingDefinition.category_name(definition.category)
	lines.append(category_name)

	if show_cost:
		lines.append("Cost: %s" % [definition.cost_summary()])

	if show_production:
		var production := definition.production_summary()
		if production != "None":
			lines.append("Produces: %s" % [production])

	if definition.footprint_radius > 0:
		lines.append("Footprint: r%d" % [definition.footprint_radius])

	text = "\n".join(lines)
