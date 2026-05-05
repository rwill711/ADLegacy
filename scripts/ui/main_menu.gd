class_name MainMenu extends Control
## Opening screen. Launches the single available battle for now.
## Phase 9 will replace New Game with a character select flow.
## Phase 10 will add a level select map between here and the battle.

const _MapLibrary = preload("res://scripts/grid/map_library.gd")


func _ready() -> void:
	# Show "Continue" at the top if an endless save file exists.
	if GameManager.has_save():
		var continue_btn := Button.new()
		continue_btn.text = "Continue"
		$VBox.add_child(continue_btn)
		$VBox.move_child(continue_btn, 0)
		continue_btn.pressed.connect(_on_continue_save)

	$VBox/NewGameBtn.pressed.connect(_on_new_game)
	$VBox/EndlessModeBtn.pressed.connect(_on_endless_mode)
	$VBox/ExitBtn.pressed.connect(_on_exit)


func _on_new_game() -> void:
	SceneManager.set_pending_mode("single")
	get_tree().change_scene_to_file("res://scenes/main_menu/character_select.tscn")


func _on_endless_mode() -> void:
	SceneManager.set_pending_mode("endless")
	get_tree().change_scene_to_file("res://scenes/main_menu/character_select.tscn")


func _on_exit() -> void:
	get_tree().quit()


## Resume an endless run from the save file.
func _on_continue_save() -> void:
	var data: Dictionary = GameManager.load_game()
	if data.is_empty():
		return
	var round: int   = int(data.get("endless_round", 1))
	var jobs: Array  = data.get("endless_player_jobs", [])
	var names: Array = data.get("endless_player_names", [])

	SceneManager.restore_endless_run(jobs, names, round)
	# Advance to the next round (save always holds the last completed one).
	SceneManager.advance_endless_round()
	SceneManager.set_player_jobs(jobs)
	SceneManager.set_player_names(names)

	var templates: Array = _MapLibrary.all_templates()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var next_template = templates[rng.randi_range(0, templates.size() - 1)]
	SceneManager.set_map_template(next_template.template_name)
	SceneManager.set_terrain_intensity(randf_range(0.8, 1.4))

	get_tree().change_scene_to_file("res://scenes/main.tscn")
