class_name CombatLog extends CanvasLayer
## Fixed-height bottom-of-screen scrollable action log.
## Pure widget — call push(text) from anywhere with a reference.

const MAX_ENTRIES: int = 80

@onready var _scroll: ScrollContainer = %Scroll
@onready var _log_list: VBoxContainer  = %LogList


func push(text: String) -> void:
	if _log_list == null or text.is_empty():
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_list.add_child(lbl)

	while _log_list.get_child_count() > MAX_ENTRIES:
		_log_list.get_child(0).queue_free()

	call_deferred("_scroll_to_bottom")


func _scroll_to_bottom() -> void:
	if _scroll == null:
		return
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
