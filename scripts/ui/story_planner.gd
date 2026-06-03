class_name StoryPlanner extends CanvasLayer

const _MapLibrary = preload("res://scripts/grid/map_library.gd")

const PARTY_SIZE: int = 7
const EMPTY_LABEL: String = "— Empty —"
const WIN_CONDITIONS: Array = ["Defeat All Enemies", "Defeat the Boss", "Loot All Chests"]
const INTENSITY_LEVELS: Array = [
	{"label": "Sparse",  "value": 0.5},
	{"label": "Normal",  "value": 1.0},
	{"label": "Dense",   "value": 1.5},
	{"label": "Extreme", "value": 2.0},
]

# ── state ─────────────────────────────────────────────────────────────────────
var _acts:           Array  = []
var _selected_idx:   int    = -1
var _story_name:     String = "New Story"
var _job_names:      Array  = []   # StringName; index 0 = empty sentinel
var _scene_names:    Array  = []   # bare names (no extension)
var _template_names: Array  = []
var _level_names:    Array  = []

# ── top bar refs ──────────────────────────────────────────────────────────────
var _name_edit:   LineEdit     = null
var _load_picker: OptionButton = null

# ── act list refs ─────────────────────────────────────────────────────────────
var _act_vbox: VBoxContainer = null

# ── editor refs (rebuilt on selection change) ─────────────────────────────────
var _editor_root: VBoxContainer = null


func _ready() -> void:
	_job_names.append(&"")
	for job in JobLibrary.all_alpha_jobs():
		_job_names.append(job.job_name)
	_refresh_asset_lists()
	_build_ui()


func _refresh_asset_lists() -> void:
	_scene_names    = SceneLibrary.list_scene_names()
	_template_names = []
	for t in _MapLibrary.all_templates():
		_template_names.append(t.template_name)
	_level_names = LevelLibrary.list_level_names()


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

	_build_act_panel(hbox)
	_build_editor_panel(hbox)


func _build_top_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	parent.add_child(bar)

	var lbl := Label.new()
	lbl.text = "Story:"
	bar.add_child(lbl)

	_name_edit = LineEdit.new()
	_name_edit.text = _story_name
	_name_edit.custom_minimum_size = Vector2(180, 0)
	_name_edit.text_changed.connect(func(t): _story_name = t)
	bar.add_child(_name_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_load_picker = OptionButton.new()
	_load_picker.custom_minimum_size = Vector2(160, 0)
	_refresh_load_picker()
	bar.add_child(_load_picker)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_load_story)
	bar.add_child(load_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_story)
	bar.add_child(save_btn)

	var play_btn := Button.new()
	play_btn.text = "▶ Play"
	play_btn.pressed.connect(_play_story)
	bar.add_child(play_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_go_back)
	bar.add_child(back_btn)


func _build_act_panel(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(210, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "─ Acts ─"
	vbox.add_child(title)

	var add_scene_btn := Button.new()
	add_scene_btn.text = "+ Add Scene"
	add_scene_btn.pressed.connect(_on_add_scene_act)
	vbox.add_child(add_scene_btn)

	var add_mission_btn := Button.new()
	add_mission_btn.text = "+ Add Mission"
	add_mission_btn.pressed.connect(_on_add_mission_act)
	vbox.add_child(add_mission_btn)

	_act_vbox = VBoxContainer.new()
	vbox.add_child(_act_vbox)

	_refresh_act_list()


func _build_editor_panel(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_editor_root = VBoxContainer.new()
	_editor_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_editor_root)

	_refresh_editor()


# =============================================================================
# ACT LIST
# =============================================================================

func _refresh_act_list() -> void:
	for child in _act_vbox.get_children():
		child.queue_free()

	for i in _acts.size():
		var act: Dictionary = _acts[i]
		var row := HBoxContainer.new()
		_act_vbox.add_child(row)

		var up_btn := Button.new()
		up_btn.text = "▲"
		up_btn.disabled = (i == 0)
		up_btn.pressed.connect(_on_move_act_up.bind(i))
		row.add_child(up_btn)

		var dn_btn := Button.new()
		dn_btn.text = "▼"
		dn_btn.disabled = (i == _acts.size() - 1)
		dn_btn.pressed.connect(_on_move_act_down.bind(i))
		row.add_child(dn_btn)

		var sel_btn := Button.new()
		sel_btn.text = _act_summary(act)
		sel_btn.toggle_mode = true
		sel_btn.button_pressed = (i == _selected_idx)
		sel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel_btn.pressed.connect(_on_select_act.bind(i))
		row.add_child(sel_btn)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.pressed.connect(_on_remove_act.bind(i))
		row.add_child(del_btn)


func _act_summary(act: Dictionary) -> String:
	var label: String = act.get("label", "").strip_edges()
	var atype: String = act.get("type", "?").to_upper()
	if label.is_empty():
		match act.get("type", ""):
			"scene":   label = act.get("file", "—").trim_suffix(SceneLibrary.FILE_EXT)
			"mission": label = act.get("map_template", act.get("level_name", "—"))
	return "[%s]  %s" % [atype, label]


func _on_add_scene_act() -> void:
	_acts.append({"type": "scene", "label": "", "file": ""})
	_selected_idx = _acts.size() - 1
	_refresh_act_list()
	_refresh_editor()


func _on_add_mission_act() -> void:
	_acts.append({
		"type":         "mission",
		"label":        "",
		"map_type":     "template",
		"map_template": _template_names[0] if not _template_names.is_empty() else "",
		"level_name":   "",
		"intensity":    1.0,
		"win_condition": 0,
		"enemy_jobs":   [],
		"player_jobs":  [],
		"pre_scene":    "",
		"post_scene":   "",
		"mid_scenes":   [],
	})
	_selected_idx = _acts.size() - 1
	_refresh_act_list()
	_refresh_editor()


func _on_select_act(idx: int) -> void:
	_selected_idx = idx
	_refresh_act_list()
	_refresh_editor()


func _on_remove_act(idx: int) -> void:
	_acts.remove_at(idx)
	_selected_idx = clampi(_selected_idx, -1, _acts.size() - 1)
	_refresh_act_list()
	_refresh_editor()


func _on_move_act_up(idx: int) -> void:
	if idx <= 0:
		return
	var tmp: Dictionary = _acts[idx]
	_acts[idx] = _acts[idx - 1]
	_acts[idx - 1] = tmp
	_selected_idx = idx - 1
	_refresh_act_list()
	_refresh_editor()


func _on_move_act_down(idx: int) -> void:
	if idx >= _acts.size() - 1:
		return
	var tmp: Dictionary = _acts[idx]
	_acts[idx] = _acts[idx + 1]
	_acts[idx + 1] = tmp
	_selected_idx = idx + 1
	_refresh_act_list()
	_refresh_editor()


# =============================================================================
# ACT EDITOR  (fully rebuilt on each selection change)
# =============================================================================

func _refresh_editor() -> void:
	for child in _editor_root.get_children():
		child.queue_free()

	if _selected_idx < 0 or _selected_idx >= _acts.size():
		var hint := Label.new()
		hint.text = "Select an act to edit, or add one."
		hint.modulate = Color(0.6, 0.6, 0.6)
		_editor_root.add_child(hint)
		return

	var act: Dictionary = _acts[_selected_idx]

	_field_row("Label:", act.get("label", ""), "Optional name…",
		func(v): act["label"] = v; _refresh_act_list()
	)
	_editor_root.add_child(HSeparator.new())

	match act.get("type", ""):
		"scene":   _build_scene_editor(act)
		"mission": _build_mission_editor(act)


# ── editor helpers ────────────────────────────────────────────────────────────

func _field_row(lbl_text: String, value: String, placeholder: String, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	_editor_root.add_child(row)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(on_change)
	row.add_child(edit)


func _picker_row(lbl_text: String, items: Array, selected_val: String, on_select: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	_editor_root.add_child(row)
	var lbl := Label.new()
	lbl.text = lbl_text
	lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel_idx: int = 0
	for i in items.size():
		opt.add_item(str(items[i]))
		if str(items[i]) == selected_val:
			sel_idx = i
	opt.selected = sel_idx
	row.add_child(opt)
	opt.item_selected.connect(on_select)
	return opt


# ── scene act ─────────────────────────────────────────────────────────────────

func _build_scene_editor(act: Dictionary) -> void:
	var title := Label.new()
	title.text = "─ Scene Act ─"
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_editor_root.add_child(title)

	var scene_items: Array = ["— None —"] + _scene_names
	var cur: String = act.get("file", "").trim_suffix(SceneLibrary.FILE_EXT)
	var on_scene_change := func(idx: int) -> void:
		act["file"] = (scene_items[idx] + SceneLibrary.FILE_EXT) if idx > 0 else ""
		act.erase("actor_slots")
		_refresh_act_list()
		_refresh_editor()
	_picker_row("Scene:", scene_items, cur, on_scene_change)

	# Background map for this cutscene (used by the Test preview and, later,
	# by StoryManager when it needs to place actors in 3D space).
	_editor_root.add_child(HSeparator.new())
	var map_display: Array = ["— Default Field —"]
	for lvl in _level_names:
		map_display.append("Level: " + lvl)
	for tmpl in _template_names:
		map_display.append("Proc: " + tmpl)

	var cur_map:      String = act.get("scene_map", "")
	var cur_map_type: String = act.get("scene_map_type", "level")
	var cur_map_disp: String = "— Default Field —"
	if not cur_map.is_empty():
		cur_map_disp = ("Level: " if cur_map_type == "level" else "Proc: ") + cur_map

	var on_map_change := func(idx: int) -> void:
		if idx == 0:
			act["scene_map"] = ""
			act["scene_map_type"] = "level"
		elif idx <= _level_names.size():
			act["scene_map"] = _level_names[idx - 1]
			act["scene_map_type"] = "level"
		else:
			act["scene_map"] = _template_names[idx - 1 - _level_names.size()]
			act["scene_map_type"] = "template"
	_picker_row("Scene Map:", map_display, cur_map_disp, on_map_change)

	# Actor casting — load the selected scene's roster and let the user bind
	# each role to a player/enemy slot for this act.
	var scene_file: String  = act.get("file", "")
	var scene_data: SceneData = null
	if not scene_file.is_empty():
		scene_data = SceneLibrary.load_scene(scene_file)

	if scene_data != null and not scene_data.get_actor_roles().is_empty():
		_editor_root.add_child(HSeparator.new())
		var cast_lbl := Label.new()
		cast_lbl.text = "─ Cast ─"
		cast_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		_editor_root.add_child(cast_lbl)

		if not act.has("actor_slots"):
			# Seed from the scene's own saved slot assignments so defaults carry over.
			var seeded: Dictionary = {}
			for role in scene_data.get_actor_roles():
				var s: String = scene_data.get_actor_unit_slot(role)
				if not s.is_empty():
					seeded[role] = s
			act["actor_slots"] = seeded
		if not act.has("actor_facings"):
			act["actor_facings"] = {}

		var slot_options: Array = ["— Unassigned —"]
		for p in range(1, 8):
			slot_options.append("Player %d" % p)
		for e in range(1, 8):
			slot_options.append("Enemy %d" % e)

		const FACING_OPTIONS: Array = ["S", "N", "E", "W"]

		for role in scene_data.get_actor_roles():
			var row := HBoxContainer.new()
			_editor_root.add_child(row)
			var rlbl := Label.new()
			rlbl.text = role + ":"
			rlbl.custom_minimum_size = Vector2(110, 0)
			rlbl.add_theme_font_size_override("font_size", 13)
			row.add_child(rlbl)
			var opt := OptionButton.new()
			opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opt.add_theme_font_size_override("font_size", 13)
			for item in slot_options:
				opt.add_item(item)
			opt.selected = _scene_slot_to_idx(act["actor_slots"].get(role, ""))
			row.add_child(opt)
			opt.item_selected.connect(func(idx, r = role):
				act["actor_slots"][r] = _scene_idx_to_slot(idx)
			)
			# Facing picker — initial direction the actor faces when placed.
			var face_opt := OptionButton.new()
			face_opt.add_theme_font_size_override("font_size", 13)
			for f in FACING_OPTIONS:
				face_opt.add_item(f)
			var fi: int = FACING_OPTIONS.find(act["actor_facings"].get(role, "S"))
			face_opt.selected = maxi(0, fi)
			row.add_child(face_opt)
			face_opt.item_selected.connect(func(idx, r = role):
				act["actor_facings"][r] = FACING_OPTIONS[idx]
			)

	# Test button — launches a full 3D preview with camera movement.
	_editor_root.add_child(HSeparator.new())
	var test_btn := Button.new()
	test_btn.text = "▶ Test Scene on Map"
	test_btn.disabled = scene_file.is_empty()
	test_btn.pressed.connect(_test_scene_act.bind(act))
	_editor_root.add_child(test_btn)


# ── mission act ───────────────────────────────────────────────────────────────

func _build_mission_editor(act: Dictionary) -> void:
	var title := Label.new()
	title.text = "─ Mission Act ─"
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
	_editor_root.add_child(title)

	# Map type
	var map_type: String = act.get("map_type", "template")
	_picker_row("Map:", ["Procedural Template", "Custom Level"],
		"Procedural Template" if map_type == "template" else "Custom Level",
		func(idx):
			act["map_type"] = "template" if idx == 0 else "level"
			_refresh_editor()
	)

	if map_type == "template":
		# Pre-initialise so index-0 is stored even if the user never clicks.
		if act.get("map_template", "").is_empty() and not _template_names.is_empty():
			act["map_template"] = _template_names[0]
		_picker_row("Template:", _template_names, act.get("map_template", ""),
			func(idx): act["map_template"] = _template_names[idx] if idx < _template_names.size() else ""
		)
		# Intensity
		var cur_int: float = float(act.get("intensity", 1.0))
		var int_labels: Array = []
		var int_sel: int = 1
		for i in INTENSITY_LEVELS.size():
			int_labels.append(INTENSITY_LEVELS[i]["label"])
			if abs(float(INTENSITY_LEVELS[i]["value"]) - cur_int) < 0.01:
				int_sel = i
		var int_opt := _picker_row("Intensity:", int_labels, int_labels[int_sel],
			func(idx): act["intensity"] = float(INTENSITY_LEVELS[idx]["value"])
		)
		int_opt.selected = int_sel
	else:
		# Pre-initialise so index-0 selection is stored even if the user never clicks.
		if act.get("level_name", "").is_empty() and not _level_names.is_empty():
			act["level_name"] = _level_names[0]
		_picker_row("Level:", _level_names, act.get("level_name", ""),
			func(idx): act["level_name"] = _level_names[idx] if idx < _level_names.size() else ""
		)

	_picker_row("Win:", WIN_CONDITIONS,
		WIN_CONDITIONS[clampi(int(act.get("win_condition", 0)), 0, WIN_CONDITIONS.size() - 1)],
		func(idx): act["win_condition"] = idx
	)

	_editor_root.add_child(HSeparator.new())

	var cast_map: Dictionary = _collect_cast_map()

	# Player party slots — labeled with cast role names where established.
	var player_lbl := Label.new()
	player_lbl.text = "Player Party:"
	_editor_root.add_child(player_lbl)

	var player_jobs: Array = act.get("player_jobs", [])
	while player_jobs.size() < PARTY_SIZE:
		player_jobs.append(&"")
	act["player_jobs"] = player_jobs

	for slot_i in PARTY_SIZE:
		var pslot_key: String = "player_%d" % (slot_i + 1)
		var prole: String = cast_map.get(pslot_key, "")
		var prow := HBoxContainer.new()
		_editor_root.add_child(prow)
		var plbl := Label.new()
		plbl.text = (prole + ":") if not prole.is_empty() else ("Slot %d:" % (slot_i + 1))
		plbl.custom_minimum_size = Vector2(80, 0)
		if not prole.is_empty():
			plbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		prow.add_child(plbl)
		var popt := OptionButton.new()
		popt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		popt.add_theme_font_size_override("font_size", 13)
		for j in _job_names.size():
			var jname: StringName = _job_names[j]
			if jname == &"":
				popt.add_item(EMPTY_LABEL)
			else:
				var jdata = JobLibrary.get_job(jname)
				popt.add_item(jdata.display_name if jdata != null else String(jname))
		var pcur: StringName = StringName(str(player_jobs[slot_i]))
		popt.selected = maxi(0, _job_names.find(pcur))
		prow.add_child(popt)
		popt.item_selected.connect(func(idx, s = slot_i): act["player_jobs"][s] = _job_names[idx])

	_editor_root.add_child(HSeparator.new())

	# Enemy party slots — labeled with cast role names where established.
	var enemy_lbl := Label.new()
	enemy_lbl.text = "Enemy Party:"
	_editor_root.add_child(enemy_lbl)

	var enemy_jobs: Array = act.get("enemy_jobs", [])
	while enemy_jobs.size() < PARTY_SIZE:
		enemy_jobs.append(&"")
	act["enemy_jobs"] = enemy_jobs

	for slot_i in PARTY_SIZE:
		var eslot_key: String = "enemy_%d" % (slot_i + 1)
		var erole: String = cast_map.get(eslot_key, "")
		var slot_row := HBoxContainer.new()
		_editor_root.add_child(slot_row)
		var slot_lbl := Label.new()
		slot_lbl.text = (erole + ":") if not erole.is_empty() else ("Slot %d:" % (slot_i + 1))
		slot_lbl.custom_minimum_size = Vector2(80, 0)
		if not erole.is_empty():
			slot_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.65))
		slot_row.add_child(slot_lbl)
		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.add_theme_font_size_override("font_size", 13)
		for j in _job_names.size():
			var jname: StringName = _job_names[j]
			if jname == &"":
				opt.add_item(EMPTY_LABEL)
			else:
				var jdata = JobLibrary.get_job(jname)
				opt.add_item(jdata.display_name if jdata != null else String(jname))
		var cur_job: StringName = StringName(str(enemy_jobs[slot_i]))
		var job_sel: int = maxi(0, _job_names.find(cur_job))
		opt.selected = job_sel
		opt.item_selected.connect(
			func(idx, s = slot_i): act["enemy_jobs"][s] = _job_names[idx]
		)
		slot_row.add_child(opt)

	_editor_root.add_child(HSeparator.new())

	# Pre / post scene pickers
	var scene_items: Array = ["— None —"] + _scene_names
	var pre_cur:  String = act.get("pre_scene",  "").trim_suffix(SceneLibrary.FILE_EXT)
	var post_cur: String = act.get("post_scene", "").trim_suffix(SceneLibrary.FILE_EXT)
	_picker_row("Pre-scene:", scene_items, pre_cur,
		func(idx): act["pre_scene"] = (scene_items[idx] + SceneLibrary.FILE_EXT) if idx > 0 else ""
	)
	_picker_row("Post-scene:", scene_items, post_cur,
		func(idx): act["post_scene"] = (scene_items[idx] + SceneLibrary.FILE_EXT) if idx > 0 else ""
	)

	_editor_root.add_child(HSeparator.new())

	# Mid-scenes (turn triggers)
	var mid_header := HBoxContainer.new()
	_editor_root.add_child(mid_header)
	var mid_lbl := Label.new()
	mid_lbl.text = "Mid-scenes:"
	mid_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_header.add_child(mid_lbl)
	var add_mid := Button.new()
	add_mid.text = "+ Add"
	add_mid.pressed.connect(func():
		if not act.has("mid_scenes"):
			act["mid_scenes"] = []
		act["mid_scenes"].append({"trigger": "turn", "turn": 1, "file": ""})
		_refresh_editor()
	)
	mid_header.add_child(add_mid)

	var mid_scenes: Array = act.get("mid_scenes", [])
	for ms_i in mid_scenes.size():
		var ms: Dictionary = mid_scenes[ms_i]
		var ms_row := HBoxContainer.new()
		_editor_root.add_child(ms_row)

		var t_lbl := Label.new()
		t_lbl.text = "Turn:"
		ms_row.add_child(t_lbl)

		var t_spin := SpinBox.new()
		t_spin.min_value = 1
		t_spin.max_value = 99
		t_spin.value = int(ms.get("turn", 1))
		t_spin.custom_minimum_size = Vector2(64, 0)
		t_spin.value_changed.connect(func(v, i = ms_i): act["mid_scenes"][i]["turn"] = int(v))
		ms_row.add_child(t_spin)

		var s_opt := OptionButton.new()
		s_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_opt.add_theme_font_size_override("font_size", 12)
		var ms_sel: int = 0
		for si in scene_items.size():
			s_opt.add_item(str(scene_items[si]))
			var ms_bare: String = ms.get("file", "").trim_suffix(SceneLibrary.FILE_EXT)
			if str(scene_items[si]) == ms_bare:
				ms_sel = si
		s_opt.selected = ms_sel
		s_opt.item_selected.connect(func(idx, i = ms_i):
			act["mid_scenes"][i]["file"] = (scene_items[idx] + SceneLibrary.FILE_EXT) if idx > 0 else ""
		)
		ms_row.add_child(s_opt)

		var ms_del := Button.new()
		ms_del.text = "×"
		ms_del.pressed.connect(func(i = ms_i):
			act["mid_scenes"].remove_at(i)
			_refresh_editor()
		)
		ms_row.add_child(ms_del)


# =============================================================================
# CAST HELPERS
# =============================================================================

## Walk all scene acts and return a slot→role map so mission editors can label
## their party slots with the established character names.
## e.g. {"player_1": "Hero", "enemy_1": "Villain"}
## If a slot appears in multiple scenes, the first assignment wins.
func _collect_cast_map() -> Dictionary:
	var slot_to_role: Dictionary = {}
	for a in _acts:
		if a.get("type") != "scene":
			continue
		for role in a.get("actor_slots", {}).keys():
			var slot: String = a["actor_slots"][role]
			if not slot.is_empty() and not slot_to_role.has(slot):
				slot_to_role[slot] = role
	return slot_to_role


# =============================================================================
# SAVE / LOAD / PLAY
# =============================================================================

func _save_story() -> void:
	var fname: String = _story_name.strip_edges().replace(" ", "_")
	if fname.is_empty():
		return
	StoryLibrary.save_story(fname, _story_name, _acts)
	_refresh_load_picker()


func _load_story() -> void:
	if _load_picker.item_count == 0:
		return
	var fname: String = _load_picker.get_item_text(_load_picker.selected)
	var data: Dictionary = StoryLibrary.load_story(fname)
	if data.is_empty():
		return
	_story_name   = data.get("story_name", "Untitled")
	_acts         = data.get("acts", []).duplicate(true)
	_selected_idx = -1
	_name_edit.text = _story_name
	_refresh_act_list()
	_refresh_editor()


func _refresh_load_picker() -> void:
	_load_picker.clear()
	for fname in StoryLibrary.list_stories():
		_load_picker.add_item(fname)


func _play_story() -> void:
	if _acts.is_empty():
		return
	StoryManager.start_story(_acts.duplicate(true), _story_name)


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


# =============================================================================
# SCENE ACT — CASTING HELPERS + TEST
# =============================================================================

## Slot string ("player_2", "enemy_1", "") → option-button index.
func _scene_slot_to_idx(slot: String) -> int:
	if slot.begins_with("player_"):
		var n: int = int(slot.substr(7))
		if n >= 1 and n <= 7:
			return n
	elif slot.begins_with("enemy_"):
		var n: int = int(slot.substr(6))
		if n >= 1 and n <= 7:
			return n + 7
	return 0


## Option-button index → slot string.
func _scene_idx_to_slot(idx: int) -> String:
	if idx >= 1 and idx <= 7:
		return "player_%d" % idx
	elif idx >= 8 and idx <= 14:
		return "enemy_%d" % (idx - 7)
	return ""


## Walk the act list and return player_jobs from the first mission act that
## has them. Falls back to the default trio so the test always has something
## to spawn.
func _find_preview_player_jobs() -> Array:
	for act in _acts:
		if act.get("type", "") == "mission":
			var jobs: Array = act.get("player_jobs", [])
			jobs = jobs.filter(func(j): return String(j) != "")
			if not jobs.is_empty():
				return jobs
	return [&"rogue", &"squire", &"white_mage"]


## Launch a full 3D preview of the selected scene act. Configures SceneManager
## with preview state and loads main.tscn which will skip battle setup entirely.
func _test_scene_act(act: Dictionary) -> void:
	var scene_file: String = act.get("file", "")
	if scene_file.is_empty():
		return

	var scene_map:      String = act.get("scene_map", "")
	var scene_map_type: String = act.get("scene_map_type", "level")
	var level_name:    String = ""
	var map_template:  String = ""
	if not scene_map.is_empty():
		if scene_map_type == "level":
			level_name   = scene_map
		else:
			map_template = scene_map

	SceneManager.set_scene_preview(
		scene_file,
		act.get("actor_slots", {}),
		level_name,
		map_template,
		_find_preview_player_jobs(),
		"res://scenes/tools/story_planner.tscn",
		act.get("actor_facings", {})
	)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
