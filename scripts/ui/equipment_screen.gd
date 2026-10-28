class_name EquipmentScreen extends OverlayScreen
## Per-unit equipment management overlay shown during deployment.
## Stub — full implementation deferred. Lists units and their gear slots.

var _units: Array = []


func init(units: Array) -> void:
	_units = units
	layer = 16
	_build_ui()


func _build_ui() -> void:
	var frame: Dictionary = _build_frame(Vector2(520, 520), "Equipment")
	var body: VBoxContainer = frame["body"]

	for unit in _units:
		if unit == null:
			continue
		var unit_lbl := Label.new()
		unit_lbl.text = unit.display_name
		unit_lbl.add_theme_font_size_override("font_size", 15)
		unit_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		body.add_child(unit_lbl)

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
				body.add_child(row_lbl)

	var footer: VBoxContainer = frame["footer"]
	_add_footer_note(footer, "Full equipment management coming soon.  (Esc to close)")
	_add_footer_button(footer, "Close", close)
