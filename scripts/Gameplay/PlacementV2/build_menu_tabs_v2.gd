class_name BuildMenuTabsV2
extends TabContainer

@export var show_empty_tabs: bool = false
var _containers_by_category: Dictionary = {}


func clear_tabs() -> void:
	_containers_by_category.clear()
	for child in get_children():
		child.queue_free()


func ensure_category_tab(category: int, category_name: String) -> VBoxContainer:
	if _containers_by_category.has(category):
		return _containers_by_category[category] as VBoxContainer

	var scroll := ScrollContainer.new()
	scroll.name = category_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var container := VBoxContainer.new()
	container.name = "%sButtons" % [category_name]
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_theme_constant_override("separation", 6)

	scroll.add_child(container)
	add_child(scroll)

	_containers_by_category[category] = container
	return container


func get_category_container(category: int) -> VBoxContainer:
	return _containers_by_category.get(category, null)


func remove_empty_tabs() -> void:
	if show_empty_tabs:
		return

	for scroll in get_children():
		if not (scroll is ScrollContainer):
			continue

		if scroll.get_child_count() == 0:
			scroll.queue_free()
			continue

		var container := scroll.get_child(0)

		if container is VBoxContainer and container.get_child_count() == 0:
			scroll.queue_free()
