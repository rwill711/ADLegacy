class_name CharacterSelect extends Control
## Party configuration screen — dropdown per slot for both sides.
## Eventually becomes the Practice Arena setup screen.
## SceneManager carries selections into main.gd.

const _MapLibrary  = preload("res://scripts/grid/map_library.gd")
const _MapTemplate = preload("res://scripts/grid/map_template.gd")

const PARTY_SIZE: int = 7   ## Max units per side; rounds are capped at this many.
const EMPTY_LABEL: String = "— Empty —"

## Ordered list of all selectable jobs — drives every OptionButton.
## Index 0 is always the EMPTY sentinel; actual jobs start at index 1.
var _job_names: Array = []   # Array[StringName]
var _player_dropdowns: Array  = []  # Array[OptionButton]
var _enemy_dropdowns: Array   = []  # Array[OptionButton]
var _player_name_edits: Array = []  # Array[LineEdit]
var _player_slot_rows: Array  = []  # Array[HBoxContainer] — one per player slot
var _enemy_slot_rows: Array   = []  # Array[HBoxContainer] — one per enemy slot
var _active_player_slots: int = 3
var _active_enemy_slots: int  = 3
var _player_count_label: Label = null
var _enemy_count_label: Label  = null
var _map_dropdown: OptionButton = null
var _map_templates: Array = []      # Array[MapTemplate] — procedural entries
var _custom_level_names: Array = [] # Array[String] — bare names from LevelLibrary
var _intensity_dropdown: OptionButton = null
var _win_condition_dropdown: OptionButton = null

const INTENSITY_LEVELS: Array = [
	{"label": "Sparse",  "value": 0.5},
	{"label": "Normal",  "value": 1.0},
	{"label": "Dense",   "value": 1.5},
	{"label": "Extreme", "value": 2.0},
]
const INTENSITY_DEFAULT: int = 1  # index into INTENSITY_LEVELS (Normal)


@onready var _player_col: VBoxContainer = %PlayerCol
@onready var _enemy_col: VBoxContainer  = %EnemyCol
@onready var _start_btn: Button         = %StartBtn
@onready var _back_btn: Button          = %BackBtn


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_start_btn.pressed.connect(_on_start)

	# Index 0 = empty sentinel; jobs start at 1.
	_job_names.append(&"")
	for job in JobLibrary.all_alpha_jobs():
		_job_names.append(job.job_name)

	# First 3 slots default to the starter trio; remaining slots start empty.
	var player_defaults: Array = [&"rogue", &"squire", &"white_mage", &"", &"", &"", &""]
	var enemy_defaults: Array  = [&"squire", &"rogue", &"white_mage", &"", &"", &"", &""]

	for i in PARTY_SIZE:
		var player_result := _add_slot(_player_col, "Slot %d" % (i + 1), player_defaults[i], true)
		_player_dropdowns.append(player_result[0])
		_player_name_edits.append(player_result[1])
		_player_slot_rows.append(player_result[2])

		var enemy_result := _add_slot(_enemy_col, "Slot %d" % (i + 1), enemy_defaults[i], false)
		_enemy_dropdowns.append(enemy_result[0])
		_enemy_slot_rows.append(enemy_result[2])

	_build_map_row()

	if SceneManager.get_pending_mode() == "endless":
		_configure_for_endless()
	else:
		_add_slot_controls(_player_col, true)
		_add_slot_controls(_enemy_col, false)
		_set_player_slot_count(3)
		_set_enemy_slot_count(3)
		_add_inventory_button()


func _configure_for_endless() -> void:
	get_node("Layout/Title").text = "Assemble Your Party"
	get_node("Layout/TeamsRow/EnemySide").visible = false
	get_node("Layout/TeamsRow/VSep").visible = false


## Returns [OptionButton, LineEdit, HBoxContainer]. LineEdit is null when show_name is false.
func _add_slot(col: VBoxContainer, label_text: String, default_job: StringName, show_name: bool) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(52, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(140, 36)
	opt.add_theme_font_size_override("font_size", 14)
	for idx in _job_names.size():
		var job_name: StringName = _job_names[idx]
		if job_name == &"":
			opt.add_item(EMPTY_LABEL)
		else:
			var job := JobLibrary.get_job(job_name)
			opt.add_item(job.display_name if job != null else String(job_name))
	var default_idx: int = _job_names.find(default_job)
	opt.select(default_idx if default_idx >= 0 else 0)
	row.add_child(opt)

	var name_edit: LineEdit = null
	if show_name:
		name_edit = LineEdit.new()
		name_edit.placeholder_text = "Name…"
		name_edit.custom_minimum_size = Vector2(100, 36)
		name_edit.add_theme_font_size_override("font_size", 13)
		row.add_child(name_edit)

	return [opt, name_edit, row]


func _build_map_row() -> void:
	_map_templates = _MapLibrary.all_templates()

	var layout: VBoxContainer = _player_col.get_parent().get_parent().get_parent()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(row)
	layout.move_child(row, layout.get_child_count() - 3)  # above Buttons

	var lbl := Label.new()
	lbl.text = "Terrain:"
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 1.0))
	row.add_child(lbl)

	_map_dropdown = OptionButton.new()
	_map_dropdown.custom_minimum_size = Vector2(200, 36)
	_map_dropdown.add_theme_font_size_override("font_size", 14)
	for t in _map_templates:
		_map_dropdown.add_item(t.template_name)
	_custom_level_names = LevelLibrary.list_level_names()
	if not _custom_level_names.is_empty():
		_map_dropdown.add_item("─── Custom Levels ───")
		_map_dropdown.set_item_disabled(_map_dropdown.item_count - 1, true)
		for lvl_name in _custom_level_names:
			_map_dropdown.add_item(lvl_name.replace("_", " "))
	row.add_child(_map_dropdown)

	var int_lbl := Label.new()
	int_lbl.text = "Intensity:"
	int_lbl.add_theme_font_size_override("font_size", 15)
	int_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 1.0))
	row.add_child(int_lbl)

	_intensity_dropdown = OptionButton.new()
	_intensity_dropdown.custom_minimum_size = Vector2(110, 36)
	_intensity_dropdown.add_theme_font_size_override("font_size", 14)
	for level in INTENSITY_LEVELS:
		_intensity_dropdown.add_item(level["label"])
	_intensity_dropdown.select(INTENSITY_DEFAULT)
	row.add_child(_intensity_dropdown)

	# Win condition selector — practice mode only; endless uses its own playlist.
	if SceneManager.get_pending_mode() != "endless":
		var sep := VSeparator.new()
		sep.custom_minimum_size = Vector2(12, 0)
		row.add_child(sep)

		var win_lbl := Label.new()
		win_lbl.text = "Win:"
		win_lbl.add_theme_font_size_override("font_size", 15)
		win_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 1.0))
		row.add_child(win_lbl)

		_win_condition_dropdown = OptionButton.new()
		_win_condition_dropdown.custom_minimum_size = Vector2(185, 36)
		_win_condition_dropdown.add_theme_font_size_override("font_size", 14)
		_win_condition_dropdown.add_item("Defeat All Enemies")  # index 0 = DEFEAT_ALL
		_win_condition_dropdown.add_item("Defeat the Boss")     # index 1 = DEFEAT_BOSS
		_win_condition_dropdown.add_item("Loot All Chests")     # index 2 = LOOT_ALL_CHESTS
		row.add_child(_win_condition_dropdown)


func _on_start() -> void:
	var mode := SceneManager.consume_pending_mode()
	var endless: bool = mode == "endless"

	var player_jobs: Array  = []
	var player_names: Array = []

	for i in _player_dropdowns.size():
		if i < _player_slot_rows.size() and not _player_slot_rows[i].visible:
			continue  # slot hidden by −/+ control
		var job: StringName = _job_names[_player_dropdowns[i].selected]
		if job == &"":
			continue
		player_jobs.append(job)
		var edit: LineEdit = _player_name_edits[i]
		var entered: String = edit.text.strip_edges() if edit != null else ""
		player_names.append(entered)

	SceneManager.set_player_jobs(player_jobs)
	SceneManager.set_player_names(player_names)

	if not endless:
		var enemy_jobs: Array = []
		for i in _enemy_dropdowns.size():
			if i < _enemy_slot_rows.size() and not _enemy_slot_rows[i].visible:
				continue  # slot hidden by −/+ control
			var job: StringName = _job_names[_enemy_dropdowns[i].selected]
			if job != &"":
				enemy_jobs.append(job)
		SceneManager.set_enemy_jobs(enemy_jobs)

	if endless:
		SceneManager.start_endless_run(player_jobs, player_names)
	else:
		# Pass the selected win condition to the battle scene.
		var wc: int = _win_condition_dropdown.selected if _win_condition_dropdown != null else 0
		SceneManager.set_win_condition(wc)

	var sel: int = _map_dropdown.selected if _map_dropdown != null else 0
	var template_count: int = _map_templates.size()
	# custom levels are offset by template_count + 1 separator item (when any exist)
	var custom_offset: int = template_count + (1 if not _custom_level_names.is_empty() else 0)
	if not _custom_level_names.is_empty() and sel >= custom_offset:
		var lvl_name: String = _custom_level_names[sel - custom_offset]
		var level: LevelData = LevelLibrary.load_level(lvl_name)
		if level != null:
			SceneManager.set_level_data(level)
	else:
		var selected_template: String = ""
		if _map_templates.size() > 0 and sel < template_count:
			selected_template = _map_templates[sel].template_name
		SceneManager.set_map_template(selected_template)
		var intensity: float = 1.0
		if _intensity_dropdown != null:
			intensity = float(INTENSITY_LEVELS[_intensity_dropdown.selected]["value"])
		SceneManager.set_terrain_intensity(intensity)

	var story_file: String = SceneManager.consume_pending_story()
	if not story_file.is_empty():
		var story: Dictionary = StoryLibrary.load_story(story_file)
		var story_acts: Array = story.get("acts", [])
		if not story_acts.is_empty():
			StoryManager.start_story(story_acts, story.get("story_name", ""))
			return

	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _add_inventory_button() -> void:
	var inv_btn := Button.new()
	inv_btn.text = "Set Inventory"
	inv_btn.custom_minimum_size = Vector2(160, 44)
	inv_btn.add_theme_font_size_override("font_size", 15)
	inv_btn.pressed.connect(_on_set_inventory)
	var btn_row: HBoxContainer = _start_btn.get_parent() as HBoxContainer
	if btn_row != null:
		btn_row.add_child(inv_btn)
		btn_row.move_child(inv_btn, _start_btn.get_index())


func _on_set_inventory() -> void:
	var screen := InventoryScreen.new()
	screen.init(InventoryScreen.Mode.FREE_CATALOG)
	get_tree().current_scene.add_child(screen)


## Adds a "− [count] +" control row to the bottom of a slot column.
func _add_slot_controls(col: VBoxContainer, is_player: bool) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)

	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(34, 34)
	minus_btn.add_theme_font_size_override("font_size", 18)
	row.add_child(minus_btn)

	var count_lbl := Label.new()
	count_lbl.custom_minimum_size = Vector2(72, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	row.add_child(count_lbl)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(34, 34)
	plus_btn.add_theme_font_size_override("font_size", 18)
	row.add_child(plus_btn)

	if is_player:
		_player_count_label = count_lbl
		minus_btn.pressed.connect(func(): _set_player_slot_count(_active_player_slots - 1))
		plus_btn.pressed.connect(func(): _set_player_slot_count(_active_player_slots + 1))
	else:
		_enemy_count_label = count_lbl
		minus_btn.pressed.connect(func(): _set_enemy_slot_count(_active_enemy_slots - 1))
		plus_btn.pressed.connect(func(): _set_enemy_slot_count(_active_enemy_slots + 1))


func _set_player_slot_count(count: int) -> void:
	_active_player_slots = clampi(count, 1, PARTY_SIZE)
	for i in _player_slot_rows.size():
		_player_slot_rows[i].visible = (i < _active_player_slots)
	if _player_count_label != null:
		_player_count_label.text = "%d / %d units" % [_active_player_slots, PARTY_SIZE]


func _set_enemy_slot_count(count: int) -> void:
	_active_enemy_slots = clampi(count, 1, PARTY_SIZE)
	for i in _enemy_slot_rows.size():
		_enemy_slot_rows[i].visible = (i < _active_enemy_slots)
	if _enemy_count_label != null:
		_enemy_count_label.text = "%d / %d units" % [_active_enemy_slots, PARTY_SIZE]


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
