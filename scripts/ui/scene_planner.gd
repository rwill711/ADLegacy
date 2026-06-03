class_name ScenePlanner extends CanvasLayer

const MINI_TILE_PX:  int = 36
const MINI_COLS:     int = LevelData.DEFAULT_WIDTH   # 12
const MINI_ROWS:     int = LevelData.DEFAULT_HEIGHT  # 12
const ROW_LBL_W:     int = 20   # width of the row-number ruler column
const STEP_TYPES:    Array = ["DIALOGUE", "MOVE", "FACE", "WAIT", "CAMERA"]
const DIRECTIONS:    Array = ["N", "E", "S", "W"]

# ── scene state ───────────────────────────────────────────────────────────────
var _scene:           SceneData  = null
var _selected_idx:    int        = -1
var _selected_coord:  Vector2i   = Vector2i.ZERO
var _updating:        bool       = false
var _loaded_level:    LevelData  = null
var _placing_actor:   String     = ""   # role being placed; "" = not in place mode

# ── top bar refs ──────────────────────────────────────────────────────────────
var _name_edit:       LineEdit     = null
var _load_picker:     OptionButton = null

# ── panel refs ────────────────────────────────────────────────────────────────
var _actor_vbox:      VBoxContainer = null
var _actor_role_edit: LineEdit      = null
var _step_vbox:       VBoxContainer = null

# ── editor refs ───────────────────────────────────────────────────────────────
var _editor_root:     VBoxContainer = null
var _type_picker:     OptionButton  = null
var _actor_row:       HBoxContainer = null
var _actor_picker:    OptionButton  = null
var _text_row:        VBoxContainer = null
var _text_edit:       TextEdit      = null
var _dir_row:         HBoxContainer = null
var _dir_picker:      OptionButton  = null
var _dur_row:         HBoxContainer = null
var _dur_spin:        SpinBox       = null
var _coord_lbl:       Label         = null
var _coord_row:       HBoxContainer = null
var _cam_target_row:  HBoxContainer = null
var _cam_target_picker: OptionButton = null
var _mini_root:       VBoxContainer = null
var _mini_grid:       GridContainer = null
var _mini_btns:       Array         = []
var _mini_styles:     Array         = []
var _level_picker:    OptionButton  = null
var _place_mode_lbl:  Label         = null
var _test_director:   SceneDirector = null


func _ready() -> void:
	_scene = SceneData.create("New Scene")
	_build_ui()


# =============================================================================
# UI BUILD
# =============================================================================

func _build_ui() -> void:
	var root := PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var vbox := VBoxContainer.new()
	root.add_child(vbox)

	_build_top_bar(vbox)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_build_actor_panel(hbox)
	_build_step_panel(hbox)
	_build_editor_panel(hbox)


func _build_top_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	parent.add_child(bar)

	var lbl := Label.new()
	lbl.text = "Name:"
	bar.add_child(lbl)

	_name_edit = LineEdit.new()
	_name_edit.text = _scene.scene_name
	_name_edit.custom_minimum_size = Vector2(180, 0)
	_name_edit.text_changed.connect(func(t): _scene.scene_name = t)
	bar.add_child(_name_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_new_scene)
	bar.add_child(new_btn)

	_load_picker = OptionButton.new()
	_load_picker.custom_minimum_size = Vector2(160, 0)
	_refresh_load_picker()
	bar.add_child(_load_picker)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_load_scene_by_name)
	bar.add_child(load_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_scene)
	bar.add_child(save_btn)

	var test_btn := Button.new()
	test_btn.text = "▶ Test"
	test_btn.pressed.connect(_on_test_scene)
	bar.add_child(test_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_go_back)
	bar.add_child(back_btn)


func _build_actor_panel(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(220, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "─ Actors ─"
	vbox.add_child(title)

	_actor_role_edit = LineEdit.new()
	_actor_role_edit.placeholder_text = "Role name…"
	vbox.add_child(_actor_role_edit)

	var add_btn := Button.new()
	add_btn.text = "+ Add Actor"
	add_btn.pressed.connect(_on_add_actor)
	vbox.add_child(add_btn)

	_actor_vbox = VBoxContainer.new()
	vbox.add_child(_actor_vbox)

	_refresh_actor_list()


func _build_step_panel(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "─ Steps ─"
	vbox.add_child(title)

	var add_btn := Button.new()
	add_btn.text = "+ Add Step"
	add_btn.pressed.connect(_on_add_step)
	vbox.add_child(add_btn)

	_step_vbox = VBoxContainer.new()
	vbox.add_child(_step_vbox)

	_refresh_step_list()


func _build_editor_panel(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_editor_root = VBoxContainer.new()
	_editor_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_editor_root)

	var title := Label.new()
	title.text = "─ Step Editor ─"
	_editor_root.add_child(title)

	# Type row
	var type_row := HBoxContainer.new()
	_editor_root.add_child(type_row)
	var type_lbl := Label.new()
	type_lbl.text = "Type:"
	type_lbl.custom_minimum_size = Vector2(72, 0)
	type_row.add_child(type_lbl)
	_type_picker = OptionButton.new()
	for t in STEP_TYPES:
		_type_picker.add_item(t)
	_type_picker.item_selected.connect(_on_type_selected)
	type_row.add_child(_type_picker)

	# Camera target row (CAMERA steps only) — coordinate vs. unit
	_cam_target_row = HBoxContainer.new()
	_editor_root.add_child(_cam_target_row)
	var cam_lbl := Label.new()
	cam_lbl.text = "Target:"
	cam_lbl.custom_minimum_size = Vector2(72, 0)
	_cam_target_row.add_child(cam_lbl)
	_cam_target_picker = OptionButton.new()
	_cam_target_picker.add_item("Coordinate")
	_cam_target_picker.add_item("Unit")
	_cam_target_picker.item_selected.connect(_on_cam_target_selected)
	_cam_target_row.add_child(_cam_target_picker)

	# Actor row
	_actor_row = HBoxContainer.new()
	_editor_root.add_child(_actor_row)
	var actor_lbl := Label.new()
	actor_lbl.text = "Actor:"
	actor_lbl.custom_minimum_size = Vector2(72, 0)
	_actor_row.add_child(actor_lbl)
	_actor_picker = OptionButton.new()
	_actor_picker.item_selected.connect(_on_actor_selected)
	_actor_row.add_child(_actor_picker)

	# Text row (DIALOGUE)
	_text_row = VBoxContainer.new()
	_editor_root.add_child(_text_row)
	var text_lbl := Label.new()
	text_lbl.text = "Text:"
	_text_row.add_child(text_lbl)
	_text_edit = TextEdit.new()
	_text_edit.custom_minimum_size = Vector2(0, 80)
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text_edit.text_changed.connect(_on_text_changed)
	_text_row.add_child(_text_edit)

	# Direction row (FACE)
	_dir_row = HBoxContainer.new()
	_editor_root.add_child(_dir_row)
	var dir_lbl := Label.new()
	dir_lbl.text = "Direction:"
	dir_lbl.custom_minimum_size = Vector2(72, 0)
	_dir_row.add_child(dir_lbl)
	_dir_picker = OptionButton.new()
	for d in DIRECTIONS:
		_dir_picker.add_item(d)
	_dir_picker.item_selected.connect(_on_dir_selected)
	_dir_row.add_child(_dir_picker)

	# Duration row (WAIT)
	_dur_row = HBoxContainer.new()
	_editor_root.add_child(_dur_row)
	var dur_lbl := Label.new()
	dur_lbl.text = "Duration (s):"
	dur_lbl.custom_minimum_size = Vector2(72, 0)
	_dur_row.add_child(dur_lbl)
	_dur_spin = SpinBox.new()
	_dur_spin.min_value = 0.1
	_dur_spin.max_value = 30.0
	_dur_spin.step      = 0.1
	_dur_spin.value     = 1.0
	_dur_spin.value_changed.connect(_on_dur_changed)
	_dur_row.add_child(_dur_spin)

	# Coord row (MOVE, CAMERA)
	_coord_row = HBoxContainer.new()
	_editor_root.add_child(_coord_row)
	var coord_title := Label.new()
	coord_title.text = "Coord:"
	coord_title.custom_minimum_size = Vector2(72, 0)
	_coord_row.add_child(coord_title)
	_coord_lbl = Label.new()
	_coord_lbl.text = "(0, 0)"
	_coord_row.add_child(_coord_lbl)

	# ── Map section — always visible ────────────────────────────────────────────
	_editor_root.add_child(HSeparator.new())

	# Level loading row
	var level_row := HBoxContainer.new()
	_editor_root.add_child(level_row)
	var level_lbl := Label.new()
	level_lbl.text = "Level:"
	level_row.add_child(level_lbl)
	_level_picker = OptionButton.new()
	_level_picker.custom_minimum_size = Vector2(140, 0)
	_refresh_level_picker()
	level_row.add_child(_level_picker)
	var load_lv_btn := Button.new()
	load_lv_btn.text = "Load"
	load_lv_btn.pressed.connect(_load_level)
	level_row.add_child(load_lv_btn)

	var map_lbl := Label.new()
	map_lbl.text = "Click map: set MOVE/CAMERA coord.  Use Actors panel to place start positions."
	map_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_editor_root.add_child(map_lbl)

	_place_mode_lbl = Label.new()
	_place_mode_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	_place_mode_lbl.visible = false
	_place_mode_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_editor_root.add_child(_place_mode_lbl)

	# Mini map grid (rulers + tiles)
	_mini_root = VBoxContainer.new()
	_editor_root.add_child(_mini_root)
	_build_mini_map()

	_set_editor_visible(false)


func _build_mini_map() -> void:
	_mini_btns.clear()
	_mini_styles.clear()

	# Column header row: spacer + 0..MINI_COLS-1 labels
	var col_header := HBoxContainer.new()
	col_header.add_theme_constant_override("separation", 0)
	_mini_root.add_child(col_header)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(ROW_LBL_W, 0)
	col_header.add_child(spacer)
	for col in range(MINI_COLS):
		var lbl := Label.new()
		lbl.text = char(65 + col)   # A … L
		lbl.custom_minimum_size = Vector2(MINI_TILE_PX, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		col_header.add_child(lbl)

	# Main area: row labels + grid side by side
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 0)
	_mini_root.add_child(main_hbox)

	var row_labels := VBoxContainer.new()
	row_labels.add_theme_constant_override("separation", 0)
	main_hbox.add_child(row_labels)
	for row in range(MINI_ROWS):
		var lbl := Label.new()
		lbl.text = str(row + 1)     # 1 … 12
		lbl.custom_minimum_size = Vector2(ROW_LBL_W, MINI_TILE_PX)
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.add_theme_font_size_override("font_size", 9)
		row_labels.add_child(lbl)

	_mini_grid = GridContainer.new()
	_mini_grid.columns = MINI_COLS
	_mini_grid.add_theme_constant_override("h_separation", 0)
	_mini_grid.add_theme_constant_override("v_separation", 0)
	main_hbox.add_child(_mini_grid)

	for row in range(MINI_ROWS):
		for col in range(MINI_COLS):
			var coord := Vector2i(col, row)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.3, 0.35)

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(MINI_TILE_PX, MINI_TILE_PX)
			btn.add_theme_stylebox_override("normal",  style)
			btn.add_theme_stylebox_override("hover",   style)
			btn.add_theme_stylebox_override("pressed", style)
			btn.add_theme_font_size_override("font_size", 9)
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			btn.pressed.connect(_on_mini_tile_pressed.bind(coord))
			_mini_grid.add_child(btn)
			_mini_btns.append(btn)
			_mini_styles.append(style)

	_refresh_mini_map()


# =============================================================================
# ACTOR ROSTER
# =============================================================================

func _refresh_actor_list() -> void:
	for child in _actor_vbox.get_children():
		child.queue_free()
	for role in _scene.get_actor_roles():
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		_actor_vbox.add_child(card)

		# Name + delete row
		var top_row := HBoxContainer.new()
		card.add_child(top_row)
		var name_lbl := Label.new()
		name_lbl.text = role
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)
		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.pressed.connect(_on_remove_actor.bind(role))
		top_row.add_child(del_btn)

		# Unit assignment row
		var unit_row := HBoxContainer.new()
		card.add_child(unit_row)
		var unit_lbl := Label.new()
		unit_lbl.text = "Unit:"
		unit_row.add_child(unit_lbl)
		var slot_opt := OptionButton.new()
		slot_opt.add_theme_font_size_override("font_size", 12)
		slot_opt.add_item("— Unassigned —")
		for p in range(1, 8):
			slot_opt.add_item("Player %d" % p)
		for e in range(1, 8):
			slot_opt.add_item("Enemy %d" % e)
		slot_opt.selected = _slot_to_dropdown_idx(_scene.get_actor_unit_slot(role))
		slot_opt.item_selected.connect(func(idx): _on_unit_slot_selected(role, idx))
		slot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_row.add_child(slot_opt)

		# Start position + place/clear row
		var pos_row := HBoxContainer.new()
		card.add_child(pos_row)
		var pos: Vector2i = _scene.get_actor_start_position(role)
		var pos_lbl := Label.new()
		if pos == Vector2i(-1, -1):
			pos_lbl.text = "  Start: Current Pos"
			pos_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		else:
			pos_lbl.text = "  Start: %s" % _coord_to_str(pos)
			pos_lbl.add_theme_color_override("font_color", DialogueBox.portrait_color_for(role))
		pos_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pos_row.add_child(pos_lbl)

		var place_btn := Button.new()
		place_btn.text = "Set"
		place_btn.pressed.connect(_enter_place_mode.bind(role))
		pos_row.add_child(place_btn)

		if pos != Vector2i(-1, -1):
			var clr_btn := Button.new()
			clr_btn.text = "✕"
			clr_btn.tooltip_text = "Clear fixed start (revert to current pos)"
			clr_btn.pressed.connect(_on_clear_actor_position.bind(role))
			pos_row.add_child(clr_btn)

		var sep := HSeparator.new()
		_actor_vbox.add_child(sep)


func _on_add_actor() -> void:
	var role: String = _actor_role_edit.text.strip_edges()
	if role.is_empty():
		return
	_scene.add_actor(role)
	_actor_role_edit.text = ""
	_refresh_actor_list()
	_refresh_actor_picker()
	_refresh_mini_map()


func _on_remove_actor(role: String) -> void:
	_scene.remove_actor(role)
	_scene.clear_actor_start_position(role)
	if _placing_actor == role:
		_exit_place_mode()
	_refresh_actor_list()
	_refresh_actor_picker()
	_refresh_mini_map()


func _on_unit_slot_selected(role: String, idx: int) -> void:
	_scene.set_actor_unit_slot(role, _dropdown_idx_to_slot(idx))


func _on_clear_actor_position(role: String) -> void:
	_scene.clear_actor_start_position(role)
	_refresh_actor_list()
	_refresh_mini_map()


# =============================================================================
# STEP LIST
# =============================================================================

func _refresh_step_list() -> void:
	for child in _step_vbox.get_children():
		child.queue_free()
	for i in range(_scene.steps.size()):
		var step: Dictionary = _scene.steps[i]
		var row := HBoxContainer.new()
		_step_vbox.add_child(row)

		var up_btn := Button.new()
		up_btn.text = "▲"
		up_btn.disabled = (i == 0)
		up_btn.pressed.connect(_on_move_step_up.bind(i))
		row.add_child(up_btn)

		var dn_btn := Button.new()
		dn_btn.text = "▼"
		dn_btn.disabled = (i == _scene.steps.size() - 1)
		dn_btn.pressed.connect(_on_move_step_down.bind(i))
		row.add_child(dn_btn)

		var sel_btn := Button.new()
		sel_btn.text = _step_summary(step)
		sel_btn.toggle_mode = true
		sel_btn.button_pressed = (i == _selected_idx)
		sel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel_btn.pressed.connect(_on_select_step.bind(i))
		row.add_child(sel_btn)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.pressed.connect(_on_remove_step.bind(i))
		row.add_child(del_btn)


func _step_summary(step: Dictionary) -> String:
	match step.get("type", ""):
		"DIALOGUE": return "DIALOGUE: %s" % step.get("actor_role", "?")
		"MOVE":     return "MOVE: %s → %s" % [step.get("actor_role", "?"), _coord_to_str(Vector2i(int(step.get("to_x", 0)), int(step.get("to_y", 0))))]
		"FACE":     return "FACE: %s %s" % [step.get("actor_role", "?"), step.get("direction", "?")]
		"WAIT":     return "WAIT: %.1fs" % float(step.get("duration", 1.0))
		"CAMERA":
			if step.get("camera_target", "coord") == "unit":
				return "CAMERA → [%s]" % step.get("actor_role", "?")
			return "CAMERA → %s" % _coord_to_str(Vector2i(int(step.get("target_x", 0)), int(step.get("target_y", 0))))
	return "???"


func _on_add_step() -> void:
	var step: Dictionary = SceneData.make_dialogue_step("Narrator", "")
	_scene.add_step(step)
	_selected_idx = _scene.steps.size() - 1
	_refresh_step_list()
	_refresh_editor()


func _on_select_step(idx: int) -> void:
	_selected_idx = idx
	_exit_place_mode()
	_refresh_step_list()
	_refresh_editor()


func _on_remove_step(idx: int) -> void:
	_scene.remove_step(idx)
	if _selected_idx >= _scene.steps.size():
		_selected_idx = _scene.steps.size() - 1
	_refresh_step_list()
	_refresh_editor()


func _on_move_step_up(idx: int) -> void:
	_scene.move_step(idx, idx - 1)
	_selected_idx = idx - 1
	_refresh_step_list()
	_refresh_editor()


func _on_move_step_down(idx: int) -> void:
	_scene.move_step(idx, idx + 1)
	_selected_idx = idx + 1
	_refresh_step_list()
	_refresh_editor()


# =============================================================================
# STEP EDITOR
# =============================================================================

func _refresh_editor() -> void:
	if _selected_idx < 0 or _selected_idx >= _scene.steps.size():
		_set_editor_visible(false)
		return

	_set_editor_visible(true)
	_updating = true

	var step: Dictionary = _scene.steps[_selected_idx]
	var stype: String    = step.get("type", "DIALOGUE")

	_type_picker.selected = maxi(0, STEP_TYPES.find(stype))

	_refresh_actor_picker()
	var actor_role: String = step.get("actor_role", "")
	if actor_role.is_empty():
		actor_role = "Narrator"
	var picker_roles: Array = ["Narrator"] + _scene.get_actor_roles()
	var actor_idx: int = picker_roles.find(actor_role)
	_actor_picker.selected = maxi(0, actor_idx)

	_text_edit.text = step.get("text", "")

	var dir_idx: int = DIRECTIONS.find(step.get("direction", "S"))
	_dir_picker.selected = maxi(0, dir_idx)

	_dur_spin.value = float(step.get("duration", 1.0))

	match stype:
		"MOVE":
			_selected_coord = Vector2i(int(step.get("to_x", 0)), int(step.get("to_y", 0)))
		"CAMERA":
			_selected_coord = Vector2i(int(step.get("target_x", 0)), int(step.get("target_y", 0)))
	_coord_lbl.text = _coord_to_str(_selected_coord)
	_refresh_mini_map()

	var cam_target: String = step.get("camera_target", "coord")
	_cam_target_row.visible = (stype == "CAMERA")
	if stype == "CAMERA":
		_cam_target_picker.selected = 1 if cam_target == "unit" else 0
	var needs_actor: bool = stype in ["DIALOGUE", "MOVE", "FACE"] or (stype == "CAMERA" and cam_target == "unit")
	_actor_row.visible  = needs_actor
	_text_row.visible   = (stype == "DIALOGUE")
	_dir_row.visible    = (stype == "FACE")
	_dur_row.visible    = (stype == "WAIT")
	var needs_coord: bool = stype == "MOVE" or (stype == "CAMERA" and cam_target == "coord")
	_coord_row.visible = needs_coord

	_updating = false


func _refresh_actor_picker() -> void:
	_actor_picker.clear()
	_actor_picker.add_item("Narrator")  # always index 0
	for role in _scene.get_actor_roles():
		_actor_picker.add_item(role)


func _set_editor_visible(show: bool) -> void:
	_type_picker.get_parent().visible = show
	_cam_target_row.visible = show
	_actor_row.visible  = show
	_text_row.visible   = show
	_dir_row.visible    = show
	_dur_row.visible    = show
	_coord_row.visible  = show
	# _mini_root and the level loader are always visible — not toggled here.


# ── editor signals ────────────────────────────────────────────────────────────

func _on_cam_target_selected(idx: int) -> void:
	if _updating or _selected_idx < 0:
		return
	var step: Dictionary = _scene.steps[_selected_idx]
	if step.get("type", "") != "CAMERA":
		return
	step["camera_target"] = "unit" if idx == 1 else "coord"
	_refresh_editor()
	_refresh_step_list()


func _on_type_selected(idx: int) -> void:
	if _updating or _selected_idx < 0:
		return
	var new_type: String = STEP_TYPES[idx]
	var old_step: Dictionary = _scene.steps[_selected_idx]
	var role: String = old_step.get("actor_role", "")

	var new_step: Dictionary
	match new_type:
		"DIALOGUE": new_step = SceneData.make_dialogue_step(role, old_step.get("text", ""))
		"MOVE":     new_step = SceneData.make_move_step(role, _selected_coord)
		"FACE":     new_step = SceneData.make_face_step(role, old_step.get("direction", "S"))
		"WAIT":     new_step = SceneData.make_wait_step(float(old_step.get("duration", 1.0)))
		"CAMERA":   new_step = SceneData.make_camera_step(_selected_coord)
		_:          new_step = SceneData.make_dialogue_step(role, "")

	_scene.steps[_selected_idx] = new_step
	_refresh_step_list()
	_refresh_editor()


func _on_actor_selected(idx: int) -> void:
	if _updating or _selected_idx < 0:
		return
	var picker_roles: Array = ["Narrator"] + _scene.get_actor_roles()
	if idx < picker_roles.size():
		_scene.steps[_selected_idx]["actor_role"] = picker_roles[idx]
		_refresh_step_list()


func _on_text_changed() -> void:
	if _updating or _selected_idx < 0:
		return
	_scene.steps[_selected_idx]["text"] = _text_edit.text
	_refresh_step_list()


func _on_dir_selected(idx: int) -> void:
	if _updating or _selected_idx < 0:
		return
	_scene.steps[_selected_idx]["direction"] = DIRECTIONS[idx]
	_refresh_step_list()


func _on_dur_changed(value: float) -> void:
	if _updating or _selected_idx < 0:
		return
	_scene.steps[_selected_idx]["duration"] = value
	_refresh_step_list()


func _on_mini_tile_pressed(coord: Vector2i) -> void:
	# Actor placement mode takes priority.
	if _placing_actor != "":
		_scene.set_actor_start_position(_placing_actor, coord)
		_exit_place_mode()
		_refresh_actor_list()
		_refresh_mini_map()
		return

	# Otherwise set the step's target coord (MOVE / CAMERA).
	if _selected_idx < 0:
		return
	_selected_coord = coord
	_coord_lbl.text = _coord_to_str(coord)
	var step: Dictionary = _scene.steps[_selected_idx]
	match step.get("type", ""):
		"MOVE":
			step["to_x"] = coord.x
			step["to_y"] = coord.y
		"CAMERA":
			step["target_x"] = coord.x
			step["target_y"] = coord.y
	_refresh_step_list()
	_refresh_mini_map()


# =============================================================================
# MINI MAP RENDERING
# =============================================================================

func _refresh_mini_map() -> void:
	# Build a lookup: coord → list of roles starting there
	var actor_at: Dictionary = {}
	for role in _scene.get_actor_roles():
		var pos: Vector2i = _scene.get_actor_start_position(role)
		if pos != Vector2i(-1, -1):
			if not actor_at.has(pos):
				actor_at[pos] = []
			actor_at[pos].append(role)

	for i in range(_mini_btns.size()):
		var col: int = i % MINI_COLS
		var row: int = i / MINI_COLS
		var coord := Vector2i(col, row)
		var style: StyleBoxFlat = _mini_styles[i]
		var btn: Button         = _mini_btns[i]

		# Base terrain color
		var bg := Color(0.28, 0.28, 0.32)
		if _loaded_level != null:
			var td: Dictionary = _loaded_level.get_tile_data(coord)
			bg = _terrain_color(td.get("terrain", int(GridEnums.TerrainType.GRASS)))

		# Highlight selected step coord (MOVE / CAMERA)
		var is_target: bool = false
		if _selected_idx >= 0 and _selected_idx < _scene.steps.size():
			var stype: String = _scene.steps[_selected_idx].get("type", "")
			if stype in ["MOVE", "CAMERA"] and coord == _selected_coord:
				bg = Color(0.65, 0.45, 0.15)
				is_target = true

		style.bg_color = bg

		# Actor border — first actor at this coord sets the border color
		if actor_at.has(coord):
			var role: String = actor_at[coord][0]
			var c: Color = DialogueBox.portrait_color_for(role)
			style.border_width_left   = 3
			style.border_width_right  = 3
			style.border_width_top    = 3
			style.border_width_bottom = 3
			style.border_color = c
		else:
			style.border_width_left   = 0
			style.border_width_right  = 0
			style.border_width_top    = 0
			style.border_width_bottom = 0

		# Button label: actor initials (if any) then coord
		var label_parts: Array = []
		if actor_at.has(coord):
			var initials: String = ""
			for role in actor_at[coord]:
				initials += role[0].to_upper()
			label_parts.append(initials)
		label_parts.append(_coord_to_str(coord))
		btn.text = "\n".join(label_parts)


# =============================================================================
# LEVEL LOADING
# =============================================================================

func _load_level() -> void:
	if _level_picker.item_count == 0:
		return
	var fname: String = _level_picker.get_item_text(_level_picker.selected)
	var loaded: LevelData = LevelLibrary.load_level(fname)
	if loaded == null:
		return
	_loaded_level = loaded
	_refresh_mini_map()


func _refresh_level_picker() -> void:
	_level_picker.clear()
	for fname in LevelLibrary.list_levels():
		_level_picker.add_item(fname)


# =============================================================================
# ACTOR PLACEMENT MODE
# =============================================================================

func _enter_place_mode(role: String) -> void:
	_placing_actor = role
	_place_mode_lbl.text = "Placing: %s — click a map tile to set start position." % role
	_place_mode_lbl.visible = true


func _exit_place_mode() -> void:
	_placing_actor = ""
	_place_mode_lbl.text = ""
	_place_mode_lbl.visible = false


# =============================================================================
# COORDINATE HELPERS
# =============================================================================

## Converts internal Vector2i(col, row) to display string: col→letter, row→1-based.
## e.g. Vector2i(2, 4) → "C5"
func _coord_to_str(coord: Vector2i) -> String:
	return "%s%d" % [char(65 + coord.x), coord.y + 1]


## Maps a unit-slot dropdown index to the stored slot string.
func _dropdown_idx_to_slot(idx: int) -> String:
	if idx >= 1 and idx <= 7:
		return "player_%d" % idx
	elif idx >= 8 and idx <= 14:
		return "enemy_%d" % (idx - 7)
	return ""


## Maps a stored slot string back to a dropdown index.
func _slot_to_dropdown_idx(slot: String) -> int:
	if slot.begins_with("player_"):
		return int(slot.substr(7))
	elif slot.begins_with("enemy_"):
		return int(slot.substr(6)) + 7
	return 0


# =============================================================================
# TERRAIN COLOR
# =============================================================================

func _terrain_color(terrain: int) -> Color:
	match terrain:
		GridEnums.TerrainType.GRASS:      return Color(0.35, 0.65, 0.30)
		GridEnums.TerrainType.STONE:      return Color(0.60, 0.58, 0.52)
		GridEnums.TerrainType.FOREST:     return Color(0.15, 0.45, 0.15)
		GridEnums.TerrainType.MOUNTAIN:   return Color(0.55, 0.50, 0.45)
		GridEnums.TerrainType.WATER:      return Color(0.20, 0.45, 0.80)
		GridEnums.TerrainType.DEEP_WATER: return Color(0.10, 0.25, 0.60)
		GridEnums.TerrainType.LAVA:       return Color(0.90, 0.30, 0.05)
		GridEnums.TerrainType.FIRE:       return Color(0.95, 0.55, 0.10)
		GridEnums.TerrainType.VOID:       return Color(0.10, 0.05, 0.15)
		_:                                return Color(0.28, 0.28, 0.32)


# =============================================================================
# SAVE / LOAD / NEW
# =============================================================================

func _new_scene() -> void:
	_scene        = SceneData.create("New Scene")
	_selected_idx = -1
	_exit_place_mode()
	_name_edit.text = _scene.scene_name
	_refresh_actor_list()
	_refresh_step_list()
	_set_editor_visible(false)
	_refresh_load_picker()


func _save_scene() -> void:
	var fname: String = _scene.scene_name.strip_edges().replace(" ", "_")
	if fname.is_empty():
		return
	SceneLibrary.save_scene(_scene, fname)
	_refresh_load_picker()


func _load_scene_by_name() -> void:
	if _load_picker.item_count == 0:
		return
	var fname: String = _load_picker.get_item_text(_load_picker.selected)
	var loaded: SceneData = SceneLibrary.load_scene(fname)
	if loaded == null:
		return
	_scene        = loaded
	_selected_idx = -1
	_exit_place_mode()
	_name_edit.text = _scene.scene_name
	_refresh_actor_list()
	_refresh_step_list()
	_set_editor_visible(false)
	_refresh_mini_map()


func _refresh_load_picker() -> void:
	_load_picker.clear()
	for fname in SceneLibrary.list_scenes():
		_load_picker.add_item(fname)


func _on_test_scene() -> void:
	if _test_director != null:
		return  # already running
	if _scene.steps.is_empty():
		return
	_test_director = SceneDirector.new()
	add_child(_test_director)
	_test_director.finished.connect(_on_test_finished)
	_test_director.start(_scene, {}, null)


func _on_test_finished() -> void:
	if _test_director != null:
		_test_director.queue_free()
		_test_director = null


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
