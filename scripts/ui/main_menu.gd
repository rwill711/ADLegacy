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

	# Level Editor button — injected at runtime so it sits above Exit.
	var editor_btn := Button.new()
	editor_btn.text = "Level Editor"
	$VBox.add_child(editor_btn)
	$VBox.move_child(editor_btn, $VBox/ExitBtn.get_index())
	editor_btn.pressed.connect(_on_level_editor)

	# Scene Planner button — sits above Exit alongside Level Editor.
	var planner_btn := Button.new()
	planner_btn.text = "Scene Planner"
	$VBox.add_child(planner_btn)
	$VBox.move_child(planner_btn, $VBox/ExitBtn.get_index())
	planner_btn.pressed.connect(_on_scene_planner)

	# Story Planner button.
	var story_planner_btn := Button.new()
	story_planner_btn.text = "Story Planner"
	$VBox.add_child(story_planner_btn)
	$VBox.move_child(story_planner_btn, $VBox/ExitBtn.get_index())
	story_planner_btn.pressed.connect(_on_story_planner)

	# Story Mode row — story picker + play button.
	_build_story_mode_row()


func _on_new_game() -> void:
	SceneManager.set_pending_mode("single")
	get_tree().change_scene_to_file("res://scenes/main_menu/character_select.tscn")


func _on_endless_mode() -> void:
	GameManager.delete_save()
	SceneManager.set_pending_mode("endless")
	get_tree().change_scene_to_file("res://scenes/main_menu/character_select.tscn")


func _on_exit() -> void:
	get_tree().quit()


func _on_level_editor() -> void:
	const EDITOR_SCENE: String = "res://scenes/tools/level_editor.tscn"
	if ResourceLoader.exists(EDITOR_SCENE):
		get_tree().change_scene_to_file(EDITOR_SCENE)
	else:
		push_warning("MainMenu: Level Editor scene not yet built — coming in LE-2")


func _on_scene_planner() -> void:
	const PLANNER_SCENE: String = "res://scenes/tools/scene_planner.tscn"
	if ResourceLoader.exists(PLANNER_SCENE):
		get_tree().change_scene_to_file(PLANNER_SCENE)
	else:
		push_warning("MainMenu: Scene Planner scene not yet built")


func _on_story_planner() -> void:
	const STORY_PLANNER_SCENE: String = "res://scenes/tools/story_planner.tscn"
	if ResourceLoader.exists(STORY_PLANNER_SCENE):
		get_tree().change_scene_to_file(STORY_PLANNER_SCENE)
	else:
		push_warning("MainMenu: Story Planner scene not yet built")


var _story_dropdown: OptionButton = null
var _story_names: Array = []  # bare filenames (no extension)


func _build_story_mode_row() -> void:
	_story_names = StoryLibrary.list_story_names()
	if _story_names.is_empty():
		return

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	$VBox.add_child(row)
	$VBox.move_child(row, $VBox/ExitBtn.get_index())

	var lbl := Label.new()
	lbl.text = "Story:"
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	_story_dropdown = OptionButton.new()
	_story_dropdown.custom_minimum_size = Vector2(200, 36)
	_story_dropdown.add_theme_font_size_override("font_size", 14)
	for sname in _story_names:
		_story_dropdown.add_item(sname.replace("_", " "))
	row.add_child(_story_dropdown)

	var play_btn := Button.new()
	play_btn.text = "▶ Play Story"
	play_btn.custom_minimum_size = Vector2(130, 36)
	play_btn.add_theme_font_size_override("font_size", 14)
	play_btn.pressed.connect(_on_play_story)
	row.add_child(play_btn)


func _on_play_story() -> void:
	if _story_dropdown == null or _story_names.is_empty():
		return
	var story_file: String = _story_names[_story_dropdown.selected]
	var story: Dictionary  = StoryLibrary.load_story(story_file)
	var story_acts: Array  = story.get("acts", [])
	if story_acts.is_empty():
		return
	# Story already contains level/job configuration — skip character_select.
	StoryManager.start_story(story_acts, story.get("story_name", ""))


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

	# Restore party inventory, equipment stash, and gold from the save file.
	var inv_data: Dictionary = data.get("party_inventory", {})
	SceneManager.set_party_inventory(Inventory.from_dict(inv_data))
	SceneManager.set_gold(int(data.get("gold", 0)))
	SceneManager.set_recruit_count(int(data.get("recruit_count", 0)))

	var stash_names: Array = data.get("equipment_stash", [])
	var stash_items: Array = []
	for name_str in stash_names:
		var item: ItemData = ItemLibrary.get_item(StringName(name_str))
		if item != null:
			stash_items.append(item)
	SceneManager.set_equipment_stash(stash_items)

	var templates: Array = _MapLibrary.all_templates()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var next_template = templates[rng.randi_range(0, templates.size() - 1)]
	SceneManager.set_map_template(next_template.template_name)
	SceneManager.set_terrain_intensity(randf_range(0.8, 1.4))

	get_tree().change_scene_to_file("res://scenes/main.tscn")
