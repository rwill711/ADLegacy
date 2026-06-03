class_name EquipmentScreen extends CanvasLayer
## Per-unit equipment management overlay shown during deployment.
## Stub — full implementation deferred. Lists units and their gear slots.

signal closed

var _units: Array = []


func init(units: Array) -> void:
	_units = units
	layer = 16
	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 400)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Equipment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	vbox.add_child(title)

	for unit in _units:
		if unit == null:
			continue
		var unit_lbl := Label.new()
		unit_lbl.text = unit.display_name
		unit_lbl.add_theme_font_size_override("font_size", 15)
		unit_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		vbox.add_child(unit_lbl)

		if unit.equipment != null:
			var slots := [
				ItemEnums.EquipSlot.MAIN_HAND,
				ItemEnums.EquipSlot.OFF_HAND,
				ItemEnums.EquipSlot.HELM,
				ItemEnums.EquipSlot.BODY,
			]
			for slot in slots:
				var item: ItemData = unit.equipment.get_item(slot)
				var slot_name: String = ItemEnums.slot_display_name(slot)
				var item_name: String = item.display_name if item != null else "—"
				var row_lbl := Label.new()
				row_lbl.text = "    %-12s %s" % [slot_name + ":", item_name]
				row_lbl.add_theme_font_size_override("font_size", 13)
				vbox.add_child(row_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var note := Label.new()
	note.text = "Full equipment management coming soon."
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
