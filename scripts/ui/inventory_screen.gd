class_name InventoryScreen extends OverlayScreen
## Party inventory / item-catalog overlay.
## Stub — full implementation deferred. Shows item list and a close button.

enum Mode {
	FREE_CATALOG,   ## Browse all items; add/remove freely (pre-battle setup).
	BATTLE_USE,     ## Use consumables from the party bag during battle.
}

var _mode: Mode = Mode.FREE_CATALOG


func init(mode: Mode) -> void:
	_mode = mode
	layer = 16
	_build_ui()


func _build_ui() -> void:
	var title: String = "Inventory" if _mode == Mode.FREE_CATALOG else "Use Item"
	var frame: Dictionary = _build_frame(Vector2(480, 420), title)
	var body: VBoxContainer = frame["body"]

	var inv: Inventory = SceneManager.get_party_inventory()
	if inv == null or inv.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No items in inventory."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 14)
		body.add_child(empty_lbl)
	else:
		for item in inv.get_all_items():
			if item == null:
				continue
			var lbl := Label.new()
			lbl.text = "  • " + item.display_name
			lbl.add_theme_font_size_override("font_size", 14)
			body.add_child(lbl)

	var footer: VBoxContainer = frame["footer"]
	_add_footer_note(footer, "Full inventory management coming soon.  (Esc to close)")
	_add_footer_button(footer, "Close", close)
