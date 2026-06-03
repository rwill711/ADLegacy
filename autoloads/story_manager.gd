extends Node
## Persistent sequencer for story-mode runs.
## Survives scene transitions (autoload). Walks an ordered array of acts:
##   scene   — plays a SceneData file via a temporary SceneDirector child
##   mission — configures SceneManager and loads main.tscn for a battle
##
## main.gd calls StoryManager.advance() after each battle ends (on victory).
## The planner calls StoryManager.start_story() to begin playback.

var _acts:         Array  = []
var _index:        int    = 0
var _active:       bool   = false
var _story_name:   String = ""
## Scene acts encountered before any battle scene has loaded are queued here
## and flushed as the pre-battle scene of the first mission act.
var _queued_pre_scenes: Array = []


# =============================================================================
# PUBLIC API
# =============================================================================

## Begin executing the story from act 0.
func start_story(acts: Array, story_name: String = "") -> void:
	_acts       = acts.duplicate(true)
	_index      = 0
	_active     = true
	_story_name = story_name
	_queued_pre_scenes.clear()
	advance()


## Advance to the next act. Called by main.gd on battle victory, or
## automatically by scene acts when their SceneDirector finishes.
func advance() -> void:
	if not _active:
		return
	if _index >= _acts.size():
		_finish()
		return
	var act: Dictionary = _acts[_index]
	_index += 1
	_execute_act(act)


func is_story_active() -> bool:
	return _active


## Abandon the current story and return to the main menu.
func abandon() -> void:
	_active = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


# =============================================================================
# EXECUTION
# =============================================================================

func _execute_act(act: Dictionary) -> void:
	match act.get("type", ""):
		"scene":   _run_scene_act(act)
		"mission": _run_mission_act(act)
		_:
			push_warning("StoryManager: unknown act type '%s', skipping" % act.get("type", ""))
			advance()


func _run_scene_act(act: Dictionary) -> void:
	var file: String = act.get("file", "")
	if file.is_empty():
		advance()
		return

	# Only run the scene inline if we're already inside the battle scene (main.tscn).
	# Otherwise queue it so it plays as a pre-battle scene of the next mission act,
	# rather than overlapping the main menu or story planner UI.
	var current_path: String = ""
	if get_tree().current_scene != null:
		current_path = get_tree().current_scene.scene_file_path
	if not current_path.ends_with("main.tscn"):
		_queued_pre_scenes.append({
			"file":        file,
			"actor_slots": act.get("actor_slots", {}).duplicate(true),
		})
		advance()
		return

	var data: SceneData = SceneLibrary.load_scene(file)
	if data == null:
		push_warning("StoryManager: scene not found — '%s'" % file)
		advance()
		return
	var director := SceneDirector.new()
	add_child(director)
	director.finished.connect(func():
		director.queue_free()
		advance()
	, CONNECT_ONE_SHOT)
	director.start(data, {}, null)


func _run_mission_act(act: Dictionary) -> void:
	# Pre / post / mid scenes.
	# Any scene acts that were encountered before this mission (while outside main.tscn)
	# are flushed here so they play as the pre-battle scene.
	var pre: String            = act.get("pre_scene", "")
	var pre_actor_slots: Dictionary = {}
	if pre.is_empty() and not _queued_pre_scenes.is_empty():
		var queued: Dictionary = _queued_pre_scenes[0]
		pre             = queued.get("file", "")
		pre_actor_slots = queued.get("actor_slots", {})
	_queued_pre_scenes.clear()
	var post: String = act.get("post_scene", "")
	if not pre.is_empty():
		SceneManager.set_pre_battle_scene(pre)
	if not pre_actor_slots.is_empty():
		SceneManager.set_pre_battle_actor_slots(pre_actor_slots)
	if not post.is_empty():
		SceneManager.set_post_battle_scene(post)
	SceneManager.set_triggered_scenes(act.get("mid_scenes", []))

	# Map / level — respect the map_type flag set in the story planner.
	var map_type: String   = act.get("map_type", "template")
	var level_name: String = act.get("level_name", "")
	if map_type == "level":
		# If level_name is empty (e.g. never opened in the editor), pick the first
		# available level so the authored map_type choice is still honoured.
		if level_name.is_empty():
			var available: Array = LevelLibrary.list_level_names()
			if not available.is_empty():
				level_name = available[0]
				push_warning("StoryManager: level_name was empty, defaulting to '%s'" % level_name)
		if not level_name.is_empty():
			var level: LevelData = LevelLibrary.load_level(level_name)
			if level != null:
				SceneManager.set_level_data(level)
			else:
				push_warning("StoryManager: level '%s' not found, falling back to template" % level_name)
	if not SceneManager.has_level_data():
		# Either map_type=="template", or level loading failed — use template.
		var tmpl: String = act.get("map_template", "")
		if not tmpl.is_empty():
			SceneManager.set_map_template(tmpl)
		SceneManager.set_terrain_intensity(float(act.get("intensity", 1.0)))

	# Battle config
	SceneManager.set_win_condition(int(act.get("win_condition", 0)))
	var enemy_jobs: Array = act.get("enemy_jobs", [])
	# Strip empty sentinel strings before passing
	enemy_jobs = enemy_jobs.filter(func(j): return String(j) != "")
	if not enemy_jobs.is_empty():
		SceneManager.set_enemy_jobs(enemy_jobs)
	var player_jobs: Array = act.get("player_jobs", [])
	player_jobs = player_jobs.filter(func(j): return String(j) != "")
	if not player_jobs.is_empty():
		SceneManager.set_player_jobs(player_jobs)
		SceneManager.set_player_names(act.get("player_names", []))

	SceneManager.set_pending_mode("single")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _finish() -> void:
	_active = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
