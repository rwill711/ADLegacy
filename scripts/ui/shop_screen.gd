class_name ShopScreen extends OverlayScreen
## Between-rounds shop overlay for endless mode.
## Stub — full implementation deferred. Emits `closed` immediately on confirm.
## Esc is disabled: Continue is the only way forward to the next round.

var _round: int = 0
var _avg_level: int = 1
var _units: Array = []


func init(round: int, avg_level: int, units: Array) -> void:
	_round   = round
	_avg_level = avg_level
	_units   = units
	layer = 15
	closable_by_escape = false
	_build_ui()


func _build_ui() -> void:
	var frame: Dictionary = _build_frame(Vector2(420, 260), "Shop  (Round %d complete)" % _round)
	var body: VBoxContainer = frame["body"]

	var note := Label.new()
	note.text = "Full shop coming soon.\nAvg party level: %d" % _avg_level
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(note)

	_add_footer_button(frame["footer"], "Continue →", close)
