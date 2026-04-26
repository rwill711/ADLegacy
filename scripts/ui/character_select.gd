class_name CharacterSelect extends Control
## Party configuration screen — dropdown per slot for both sides.
## Eventually becomes the Practice Arena setup screen.
## SceneManager carries selections into main.gd.


const PARTY_SIZE: int = 3

## Ordered list of all selectable jobs — drives every OptionButton.
var _job_names: Array = []   # Array[StringName]
var _player_dropdowns: Array = []  # Array[OptionButton]
var _enemy_dropdowns: Array  = []  # Array[OptionButton]


@onready var _player_col: VBoxContainer = %PlayerCol
@onready var _enemy_col: VBoxContainer  = %EnemyCol
@onready var _start_btn: Button         = %StartBtn
@onready var _back_btn: Button          = %BackBtn


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_start_btn.pressed.connect(_on_start)

	# Build ordered job list from library
	for job in JobLibrary.all_alpha_jobs():
		_job_names.append(job.job_name)

	# Default player roster
	var player_defaults: Array = [&"rogue", &"squire", &"white_mage"]
	# Default enemy roster mirrors player
	var enemy_defaults: Array  = [&"squire", &"rogue", &"white_mage"]

	for i in PARTY_SIZE:
		_player_dropdowns.append(_add_slot(_player_col, "Slot %d" % (i + 1), player_defaults[i]))
		_enemy_dropdowns.append(_add_slot(_enemy_col,  "Slot %d" % (i + 1), enemy_defaults[i]))


func _add_slot(col: VBoxContainer, label_text: String, default_job: StringName) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(52, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(160, 36)
	opt.add_theme_font_size_override("font_size", 14)
	for job_name in _job_names:
		var job := JobLibrary.get_job(job_name)
		opt.add_item(job.display_name if job != null else String(job_name))
	# Select default
	var default_idx: int = _job_names.find(default_job)
	if default_idx >= 0:
		opt.select(default_idx)
	row.add_child(opt)
	return opt


func _on_start() -> void:
	var player_jobs: Array = []
	var enemy_jobs: Array  = []
	for opt in _player_dropdowns:
		player_jobs.append(_job_names[opt.selected])
	for opt in _enemy_dropdowns:
		enemy_jobs.append(_job_names[opt.selected])

	SceneManager.set_player_jobs(player_jobs)
	SceneManager.set_enemy_jobs(enemy_jobs)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
