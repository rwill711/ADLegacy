class_name InventoryScreen extends CanvasLayer
## Party inventory / item-catalog overlay.
## Stub — full implementation deferred. Shows item list and a close button.

enum Mode {
	FREE_CATALOG,   ## Browse all items; add/remove freely (pre-battle setup).
	BATTLE_USE,     ## Use consumables from the party bag during battle.
}

signal closed

var _mode: Mode = Mode.FREE_CATALOG


func init(mode: Mode) -> void:
	_mode = mode
	layer = 16
	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 340)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Inventory" if _mode == Mode.FREE_CATALOG else "Use Item"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	vbox.add_child(title)

	var inv: Inventory = SceneManager.get_party_inventory()
	if inv == null or inv.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No items in inventory."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(empty_lbl)
	else:
		for item in inv.get_all_items():
			if item == null:
				continue
			var lbl := Label.new()
			lbl.text = "  • " + item.display_name
			lbl.add_theme_font_size_override("font_size", 14)
			vbox.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var note := Label.new()
	note.text = "Full inventory management coming soon."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(note)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(140, 42)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(_on_close)
	vbox.add_child(close_btn)


func _on_close() -> void:
	closed.emit()
	queue_free()
