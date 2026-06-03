class_name ShopScreen extends CanvasLayer
## Between-rounds shop overlay for endless mode.
## Stub — full implementation deferred. Emits `closed` immediately on confirm.

signal closed

var _round: int = 0
var _avg_level: int = 1
var _units: Array = []


func init(round: int, avg_level: int, units: Array) -> void:
	_round   = round
	_avg_level = avg_level
	_units   = units
	layer = 15
	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 260)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Shop  (Round %d complete)" % _round
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	vbox.add_child(title)

	var note := Label.new()
	note.text = "Full shop coming soon.\nAvg party level: %d" % _avg_level
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(note)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var confirm := Button.new()
	confirm.text = "Continue →"
	confirm.custom_minimum_size = Vector2(160, 44)
	confirm.add_theme_font_size_override("font_size", 16)
	confirm.pressed.connect(_on_confirm)
	vbox.add_child(confirm)


func _on_confirm() -> void:
	closed.emit()
	queue_free()
