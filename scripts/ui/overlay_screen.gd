class_name OverlayScreen extends CanvasLayer
## Base for modal menus (equipment, inventory, shop).
##
## - Dims and blocks the board behind it, so clicks can't leak through to
##   the grid or the deploy panel while the menu is up.
## - Keeps the panel centred with a scrolling body, so the footer buttons
##   never fall off-screen no matter how many units/items are listed.
## - ESC closes the topmost menu (unless `closable_by_escape` is false).
## - Every open menu is in GROUP, so close_all() can sweep them away when
##   the game moves on (e.g. battle start).

signal closed

const GROUP := &"overlay_screens"
const SCREEN_MARGIN: float = 40.0

## Set false for menus that are a required step (the shop's Continue).
var closable_by_escape: bool = true

var _closing: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


## Close every open overlay. Safe to call when none are open.
static func close_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(GROUP):
		if node is OverlayScreen:
			node.close()


static func is_any_open(tree: SceneTree) -> bool:
	return not tree.get_nodes_in_group(GROUP).is_empty()


func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not closable_by_escape or _closing:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	# Only the most recently opened menu reacts.
	var open: Array = get_tree().get_nodes_in_group(GROUP)
	if open.is_empty() or open[open.size() - 1] != self:
		return
	get_viewport().set_input_as_handled()
	close()


## Build backdrop + centred panel. Returns {"body": VBoxContainer (scrolls),
## "footer": VBoxContainer (always visible)}. Subclasses fill both.
func _build_frame(panel_size: Vector2, title_text: String) -> Dictionary:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size \
		if get_viewport() != null else Vector2(1280, 720)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(
		minf(panel_size.x, viewport_size.x - SCREEN_MARGIN),
		minf(panel_size.y, viewport_size.y - SCREEN_MARGIN),
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	var footer := VBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 8)
	outer.add_child(footer)

	return {"body": body, "footer": footer}


## Standard footer button, centred.
func _add_footer_button(footer: VBoxContainer, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 42)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(callback)
	footer.add_child(btn)
	return btn


## Small grey "coming soon" style note for the footer.
func _add_footer_note(footer: VBoxContainer, text: String) -> void:
	var note := Label.new()
	note.text = text
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(0.6, 0.6, 0.6)
	footer.add_child(note)
