class_name CharacterSelect extends Control
## Party configuration screen — dropdown per slot for both sides.
## Eventually becomes the Practice Arena setup screen.
## SceneManager carries selections into main.gd.

const _MapLibrary  = preload("res://scripts/grid/map_library.gd")
const _MapTemplate = preload("res://scripts/grid/map_template.gd")

const PARTY_SIZE: int = 3
const EMPTY_LABEL: String = "— Empty —"

## Ordered list of all selectable jobs — drives every OptionButton.
## Index 0 is always the EMPTY sentinel; actual jobs start at index 1.
var _job_names: Array = []   # Array[StringName]
var _player_dropdowns: Array  = []  # Array[OptionButton]
var _enemy_dropdowns: Array   = []  # Array[OptionButton]
var _player_name_edits: Array = []  # Array[LineEdit]
var _map_dropdown: OptionButton = null
var _map_templates: Array = []  # Array[MapTemplate]


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

	# Default player roster
	var player_defaults: Array = [&"rogue", &"squire", &"white_mage"]
	# Default enemy roster mirrors player
	var enemy_defaults: Array  = [&"squire", &"rogue", &"white_mage"]

	for i in PARTY_SIZE:
		var player_result := _add_slot(_player_col, "Slot %d" % (i + 1), player_defaults[i], true)
		_player_dropdowns.append(player_result[0])
		_player_name_edits.append(player_result[1])
		_enemy_dropdowns.append(_add_slot(_enemy_col, "Slot %d" % (i + 1), enemy_defaults[i], false)[0])

	_build_map_row()


## Returns [OptionButton, LineEdit]. LineEdit is null when show_name is false.
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

	return [opt, name_edit]


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
	row.add_child(_map_dropdown)


func _on_start() -> void:
	var player_jobs: Array  = []
	var player_names: Array = []
	var enemy_jobs: Array   = []

	for i in _player_dropdowns.size():
		var job: StringName = _job_names[_player_dropdowns[i].selected]
		if job == &"":
			continue
		player_jobs.append(job)
		var edit: LineEdit = _player_name_edits[i]
		var entered: String = edit.text.strip_edges() if edit != null else ""
		player_names.append(entered)  # blank = spawner keeps job name

	for opt in _enemy_dropdowns:
		var job: StringName = _job_names[opt.selected]
		if job != &"":
			enemy_jobs.append(job)

	SceneManager.set_player_jobs(player_jobs)
	SceneManager.set_player_names(player_names)
	SceneManager.set_enemy_jobs(enemy_jobs)

	var selected_template: String = ""
	if _map_dropdown != null and _map_templates.size() > 0:
		selected_template = _map_templates[_map_dropdown.selected].template_name
	SceneManager.set_map_template(selected_template)

	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
