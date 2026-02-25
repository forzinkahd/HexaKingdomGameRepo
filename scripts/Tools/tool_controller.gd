extends Node
class_name ToolController

# ----------------------------------------------------------------
# MANAGE ACTIVE TOOL LIFECYCLE: BEGIN/ROTATE/CYCLE/COMMIT/CANCEL
# ----------------------------------------------------------------

var active_tool: Node = null


func set_tool(t: Node) -> void:
	if active_tool != null and active_tool.has_method("cancel"):
		active_tool.cancel()
	active_tool = t


func commit() -> void:
	if active_tool != null and active_tool.has_method("commit_current"):
		active_tool.commit_current()


func cancel() -> void:
	if active_tool != null and active_tool.has_method("cancel"):
		active_tool.cancel()
	active_tool = null


func rotate(delta: int) -> void:
	if active_tool == null: return
	if delta > 0 and active_tool.has_method("rotate_right"):
		active_tool.rotate_right()
	elif delta < 0 and active_tool.has_method("rotate_left"):
		active_tool.rotate_left()


func cycle(delta: int) -> void:
	if active_tool != null and active_tool.has_method("cycle_variant"):
		active_tool.cycle_variant(delta)
