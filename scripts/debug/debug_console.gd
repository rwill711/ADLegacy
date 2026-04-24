class_name DebugConsole extends CanvasLayer
## In-game console. Toggled with backtick (`). Renders the full log buffer
## (colored per category), accepts commands via a LineEdit, keeps input
## history navigable with up/down arrows.
##
## Binds to DebugManager at _ready — refreshes on log_added / scene_bound
## so the console survives scene reloads (Retry) with history intact.


const TOGGLE_KEYCODE: int = KEY_QUOTELEFT   # backtick
const MAX_VISIBLE_ENTRIES: int = 200


@onready var _root: Control = %Root
@onready var _output: RichTextLabel = %Output
@onready var _input_field: LineEdit = %Input


var _manager: Node = null

## Command history — ring-buffer of recently entered lines, walked via
## up/down arrows in the input. Surviving scene reloads would require
## storing on the manager; for Alpha, per-scene history is fine.
var _history: PackedStringArray = []
var _history_cursor: int = -1  # -1 = not navigating history


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_root.visible = false

	_register_toggle_action()

	_input_field.text_submitted.connect(_on_submit)

	_manager = get_tree().root.get_node_or_null("DebugManager")
	if _manager != null:
		_manager.log_added.connect(_on_log_added)
		_manager.scene_bound.connect(_on_scene_bound)
		_rebuild_output()


# =============================================================================
# TOGGLE / INPUT
# =============================================================================

func _register_toggle_action() -> void:
	if not InputMap.has_action("debug_console_toggle"):
		InputMap.add_action("debug_console_toggle")
	# Idempotent — skip if already bound.
	for existing in InputMap.action_get_events("debug_console_toggle"):
		if existing is InputEventKey and (existing as InputEventKey).keycode == TOGGLE_KEYCODE:
			return
	var ev := InputEventKey.new()
	ev.keycode = TOGGLE_KEYCODE
	InputMap.action_add_event("debug_console_toggle", ev)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console_toggle"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	# While open, up/down walk history and ESC closes.
	if _root.visible and event is InputEventKey and event.pressed:
		var k: InputEventKey = event
		match k.keycode:
			KEY_UP:
				_history_back()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_history_forward()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_close()
				get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _root.visible:
		_close()
	else:
		_open()


func _open() -> void:
	_root.visible = true
	_rebuild_output()
	# One-frame deferral so the LineEdit is ready to receive focus.
	await get_tree().process_frame
	_input_field.grab_focus()
	_input_field.clear()


func _close() -> void:
	_root.visible = false
	_input_field.release_focus()


# =============================================================================
# SUBMIT
# =============================================================================

func _on_submit(line: String) -> void:
	_input_field.clear()
	if line.strip_edges().is_empty():
		return

	_history.append(line)
	_history_cursor = -1

	if _manager == null:
		_append_line(DebugEnums.CATEGORY_CONSOLE, "> " + line)
		_append_line(DebugEnums.CATEGORY_SYSTEM, "(DebugManager not available)")
		return

	_manager.log(DebugEnums.CATEGORY_CONSOLE, "> " + line)
	var output: String = _manager.execute_command(line)
	if not output.is_empty():
		_manager.log(DebugEnums.CATEGORY_CONSOLE, output)

	_input_field.grab_focus()


# =============================================================================
# HISTORY NAVIGATION
# =============================================================================

func _history_back() -> void:
	if _history.is_empty():
		return
	if _history_cursor == -1:
		_history_cursor = _history.size() - 1
	else:
		_history_cursor = maxi(0, _history_cursor - 1)
	_input_field.text = _history[_history_cursor]
	_input_field.caret_column = _input_field.text.length()


func _history_forward() -> void:
	if _history.is_empty() or _history_cursor == -1:
		return
	_history_cursor += 1
	if _history_cursor >= _history.size():
		_history_cursor = -1
		_input_field.clear()
		return
	_input_field.text = _history[_history_cursor]
	_input_field.caret_column = _input_field.text.length()


# =============================================================================
# LOG RENDERING
# =============================================================================

func _on_log_added(entry: Dictionary) -> void:
	_append_entry(entry)


func _on_scene_bound() -> void:
	# Full rebuild so newly-bound commands / changed context show latest state.
	_rebuild_output()


func _rebuild_output() -> void:
	_output.clear()
	if _manager == null:
		return
	var entries: Array = _manager.get_log()
	# Only show the tail — avoids multi-megabyte output if someone spams actions.
	var start: int = maxi(0, entries.size() - MAX_VISIBLE_ENTRIES)
	for i in range(start, entries.size()):
		_append_entry(entries[i])


func _append_entry(entry: Dictionary) -> void:
	_append_line(entry["category"], entry["text"])


func _append_line(category: String, text: String) -> void:
	var color: Color = DebugEnums.category_color(category)
	_output.push_color(color)
	_output.append_text("[%s] %s\n" % [category, text])
	_output.pop()
