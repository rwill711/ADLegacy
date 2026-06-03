class_name DialogueBox extends CanvasLayer
## Full-screen dialogue overlay used by SceneDirector.
## Portrait is a solid ColorRect (silhouette placeholder).
## Text uses a typewriter effect; Next skips to end then advances.

signal advanced()

const TYPEWRITER_CPS: float = 40.0   # characters per second

var _portrait:    ColorRect       = null
var _name_lbl:    Label           = null
var _text_lbl:    RichTextLabel   = null
var _next_btn:    Button          = null
var _typewriter_timer: float      = 0.0
var _full_text:   String          = ""
var _typing_done: bool            = true


func _ready() -> void:
	layer = 20
	_build_ui()
	hide()


# =============================================================================
# PUBLIC API
# =============================================================================

func show_line(actor_role: String, text: String, portrait_color: Color) -> void:
	_portrait.color    = portrait_color
	_name_lbl.text     = actor_role
	_full_text         = text
	_text_lbl.text     = text
	_text_lbl.visible_characters = 0
	_typing_done       = false
	_typewriter_timer  = 0.0
	show()


## Force-closes the dialogue box immediately, unblocking any awaiting step.
func dismiss() -> void:
	hide()
	advanced.emit()


## Deterministic color for a role name — same role always gets the same color.
## "Narrator" (and empty string) always returns a neutral silver.
static func portrait_color_for(role: String) -> Color:
	if role.is_empty() or role == "Narrator":
		return Color(0.62, 0.62, 0.65)
	var h: int = role.hash() & 0x7FFFFFFF
	return Color.from_hsv(float(h % 360) / 360.0, 0.55, 0.65)


# =============================================================================
# BUILD UI
# =============================================================================

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top    = -220.0
	panel.offset_bottom = 0.0
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 200)
	panel.add_child(hbox)

	# Portrait placeholder.
	_portrait = ColorRect.new()
	_portrait.custom_minimum_size = Vector2(160, 0)
	_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_portrait)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 18)
	text_vbox.add_child(_name_lbl)

	_text_lbl = RichTextLabel.new()
	_text_lbl.bbcode_enabled     = false
	_text_lbl.scroll_active      = false
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_lbl.add_theme_font_size_override("normal_font_size", 16)
	text_vbox.add_child(_text_lbl)

	_next_btn = Button.new()
	_next_btn.text = "Next ▶"
	_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next_btn.pressed.connect(_on_next)
	text_vbox.add_child(_next_btn)


# =============================================================================
# TYPEWRITER
# =============================================================================

func _process(delta: float) -> void:
	if _typing_done or not visible:
		return
	_typewriter_timer += delta
	var chars_to_show: int = int(_typewriter_timer * TYPEWRITER_CPS)
	_text_lbl.visible_characters = mini(chars_to_show, _text_lbl.get_total_character_count())
	if _text_lbl.visible_characters >= _text_lbl.get_total_character_count():
		_typing_done = true


# =============================================================================
# INPUT
# =============================================================================

func _on_next() -> void:
	if not _typing_done:
		# Skip to end on first press.
		_text_lbl.visible_characters = -1
		_typing_done = true
		return
	hide()
	advanced.emit()
