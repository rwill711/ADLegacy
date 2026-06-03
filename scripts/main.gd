extends Node3D
## Alpha entry scene. Builds the grid, spawns the roster, starts the battle,
## and orchestrates the player vs enemy turn loop via the subsystem
## controllers. Keeps the scene root thin — each concern (grid, camera,
## units, turns, moves, actions) owns its own module.

const _MapLibrary      = preload("res://scripts/grid/map_library.gd")
const _MapBuilder      = preload("res://scripts/grid/map_builder.gd")
const _LootLibrary     = preload("res://scripts/items/loot_library.gd")
const _StructureLibrary = preload("res://scripts/world/structure_library.gd")


@export var log_tile_events: bool = true
@export var enemy_think_delay: float = 0.4  # "thinking" pause before enemy acts

## Set in the Godot editor to test a specific win condition without going
## through a menu. SceneManager.set_win_condition() takes precedence at runtime.
@export var win_condition_override: TurnEnums.WinCondition = TurnEnums.WinCondition.DEFEAT_ALL


@onready var _visualizer: GridVisualizer = $GridVisualizer
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _unit_spawner: UnitSpawner = $UnitSpawner
@onready var _units_root: Node3D = $Units
@onready var _turn_manager: TurnManager = $TurnManager
@onready var _turn_hud: TurnHUD = $TurnHUD
@onready var _move_controller: MoveController = $MoveController
@onready var _action_controller: ActionController = $ActionController
@onready var _ability_bar: AbilityBar = $AbilityBar
@onready var _facing_picker: FacingPicker = $FacingPicker
@onready var _battle_summary: BattleSummary = $BattleSummary
@onready var _battle_rewards: BattleRewards = $BattleRewards
@onready var _structure_manager = $StructureManager
@onready var _combat_log: CombatLog = $CombatLog


var _grid: BattleGrid = null
var _inspect_panel: PanelContainer = null
var _inspect_label: Label = null

## Cached encounter config from FOILBattleSetup at battle start. Consumed by
## the HUD status line and the FOIL debug panel.
var _current_encounter: Dictionary = {}

## Active win condition and boss tracking (DEFEAT_BOSS mode).
var _win_condition: TurnEnums.WinCondition = TurnEnums.WinCondition.DEFEAT_ALL
var _boss_unit_id: StringName = &""

## Chest tracking for LOOT_ALL_CHESTS mode.
var _chests_total: int = 0
var _chests_looted: int = 0
var _objective_label: Label = null

## Reinforcement wave state. Schedule is computed once in _setup_reinforcements().
var _reinf_schedule: Dictionary = {}   # wave_interval, wave_size, waves_total, job_pool
var _reinf_waves_sent: int = 0
var _reinf_turn_counter: int = 0

## Deployment phase state (before battle starts).
var _deploying: bool = false
var _deploy_zone: Array = []         # Array[Vector2i]
var _deploy_selected: Unit = null
var _deploy_panel: CanvasLayer = null

## Story scene state.
var _scene_director: SceneDirector = null
var _triggered_scenes: Array       = []
var _turn_triggers_fired: Dictionary = {}


func _ready() -> void:
	_register_battle_input_actions()

	# Hand-crafted level takes priority; falls back to procedural MapTemplate.
	var level_data: LevelData = SceneManager.consume_level_data()
	var level_player_spawns: Array = []
	var level_enemy_spawns:  Array = []

	if level_data != null:
		_grid = LevelLoader.build(level_data)
		level_player_spawns = LevelLoader.player_spawn_points(level_data)
		level_enemy_spawns  = LevelLoader.enemy_spawn_points(level_data)
	else:
		var map_template_name: String = SceneManager.consume_map_template()
		var map_template = _MapLibrary.get_template(map_template_name) \
			if not map_template_name.is_empty() else _MapLibrary.open_field()
		var terrain_intensity: float = SceneManager.consume_terrain_intensity()
		_grid = _MapBuilder.build(map_template, terrain_intensity)

	_visualizer.set_grid(_grid)

	# Scene preview launched from Story Planner "▶ Test Scene on Map".
	# Spawns actors at authored positions, runs director with camera, then
	# returns to the planner — skips all battle setup.
	if SceneManager.is_scene_preview():
		_run_scene_preview()
		return

	_visualizer.tile_hovered.connect(_on_tile_hovered)
	_visualizer.tile_unhovered.connect(_on_tile_unhovered)
	_visualizer.tile_clicked.connect(_on_tile_clicked)

	# Phase 6: run FOIL setup BEFORE spawning enemies so the loadout builder
	# can influence which jobs / consumables / AI hints the spawner uses.
	# The player character list comes from PLAYER_JOB_ORDER (parallel with
	# the display names the spawner will assign). We derive display names
	# from JobLibrary the same way the spawner does, so FOIL keys match.
	# Read player job selection passed from CharacterSelect via SceneManager.
	# Falls back to the default hardcoded order if launching directly.
	var player_jobs: Array  = SceneManager.consume_player_jobs()
	var enemy_jobs: Array   = SceneManager.consume_enemy_jobs()
	var player_names: Array = SceneManager.consume_player_names()
	var enemy_names: Array  = SceneManager.consume_enemy_names()

	# Resolve win condition: SceneManager takes priority; editor export is
	# the fallback so individual scenes can be tested without a menu.
	var sm_condition: int = SceneManager.consume_win_condition()
	_win_condition = (sm_condition as TurnEnums.WinCondition) \
		if sm_condition != 0 else win_condition_override
	var foil_names: Array   = _predict_player_character_names(player_jobs)
	var enemy_pool: Array = UnitSpawner.default_base_enemy_pool()
	if SceneManager.is_endless_mode():
		enemy_pool = _random_enemy_pool()
	var encounter: Dictionary = FOILBattleSetup.build_encounter(
		foil_names,
		enemy_pool,
		maxi(1, player_jobs.size()),
	)
	var extra_enemies := 2 if _win_condition == TurnEnums.WinCondition.DEFEAT_BOSS else 0
	var units: Array = _unit_spawner.spawn_alpha_roster(
		_grid, _units_root, encounter["loadout"], player_jobs, enemy_jobs,
		player_names, enemy_names, extra_enemies,
		level_player_spawns, level_enemy_spawns
	)

	# Designate the first enemy as the boss in DEFEAT_BOSS mode.
	if _win_condition == TurnEnums.WinCondition.DEFEAT_BOSS:
		var enemies := _unit_spawner.get_units_on_team(UnitEnums.Team.ENEMY)
		if not enemies.is_empty():
			_boss_unit_id = enemies[0].unit_id
			enemies[0].display_name = "[BOSS] " + enemies[0].display_name

	# Overlay saved equipment / inventory / AP progression on player units when
	# resuming an endless run (round 2+ or continuing after a relaunch).
	if SceneManager.is_endless_mode() and GameManager.has_save():
		var save_data: Dictionary = GameManager.load_game()
		var saved_units: Array = save_data.get("units", [])
		var player_units: Array = _unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER)
		for i in mini(player_units.size(), saved_units.size()):
			player_units[i].restore_from_save(saved_units[i])

	_current_encounter = encounter

	_camera_rig.set_focus(_grid_center_world(_grid), true)

	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.turn_ended.connect(_on_turn_ended_check_reinf)
	_turn_manager.battle_ended.connect(_on_battle_ended)

	_turn_hud.bind_turn_manager(_turn_manager)
	_battle_rewards.clear()
	_structure_manager.clear()
	_move_controller.bind(_grid, _visualizer, _turn_manager, _unit_spawner, _battle_rewards)
	_move_controller.chest_collected.connect(_on_chest_collected)
	_move_controller.move_completed.connect(_check_loot_win_condition)
	_action_controller.bind(
		_grid, _visualizer, _turn_manager, _unit_spawner,
		_move_controller, _ability_bar, self, _battle_rewards
	)
	_action_controller.set_structure_manager(_structure_manager)
	_action_controller.set_combat_log(_combat_log)
	_facing_picker.bind_turn_manager(_turn_manager)
	_facing_picker.bind_visualizer(_visualizer)
	_facing_picker.bind_grid(_grid)

	_ability_bar.wait_pressed.connect(_turn_manager.wait_and_end_turn)
	_ability_bar.status_pressed.connect(_show_unit_inspect)
	_ability_bar.enter_pressed.connect(_on_enter_structure)

	_battle_summary.retry_pressed.connect(_on_retry_pressed)
	_battle_summary.quit_pressed.connect(_on_quit_pressed)
	_battle_summary.continue_pressed.connect(_on_continue_pressed)

	_build_inspect_panel()

	# Configure win condition and set up mode-specific map changes.
	_turn_manager.set_win_condition(_win_condition, _boss_unit_id)
	if _win_condition == TurnEnums.WinCondition.LOOT_ALL_CHESTS:
		_setup_loot_mode_chests()
	_build_objective_hud()
	_setup_reinforcements()
	_triggered_scenes = SceneManager.consume_triggered_scenes()

	# Bind the debug autoload to this scene so console commands can reach
	# the grid / units / controllers. Safe to re-bind on every scene reload
	# (Retry) — DebugManager.bind_scene is idempotent.
	var debug_mgr: Node = get_tree().root.get_node_or_null("DebugManager")
	if debug_mgr != null:
		debug_mgr.bind_scene(
			_grid, _unit_spawner, _turn_manager,
			_move_controller, _action_controller,
			_camera_rig, self,
		)
		# Register the FOIL debug tab via the extensibility contract. Runs
		# after bind_scene so the panel can already see live scene refs.
		# Always register a fresh instance — on Retry the previous panel was
		# queue_freed along with the old overlay, but DebugManager's dict
		# still holds the stale ref; register_panel overwrites it so the new
		# overlay picks up a valid node.
		debug_mgr.register_panel("FOIL", FOILDebugPanel.new())

	# Update the HUD's FOIL status line so the player can see the current
	# level + who's being countered.
	_turn_hud.set_foil_status(
		encounter["level"],
		_archetype_name(encounter["profile"].dominant_archetype)
	)
	_log_encounter_summary(encounter)

	# Log win condition objective to combat log so it's visible at battle start.
	if _combat_log != null:
		match _win_condition:
			TurnEnums.WinCondition.DEFEAT_BOSS:
				var boss := _unit_spawner.get_unit(_boss_unit_id)
				var boss_name := boss.display_name if boss != null else "the Boss"
				_combat_log.push("OBJECTIVE: Defeat %s!" % boss_name, Color(1.0, 0.35, 0.35))
			TurnEnums.WinCondition.DEFEAT_ALL:
				_combat_log.push("OBJECTIVE: Defeat all enemies", Color(0.9, 0.9, 0.9))

	# Kick off FOIL battle records for every player unit up front, so even
	# actions on the first turn land in the rolling window.
	var foil: Node = get_tree().root.get_node_or_null("FOILTracker")
	if foil != null:
		for unit in units:
			if unit.team == UnitEnums.Team.PLAYER:
				var job_name: String = String(unit.job.job_name) if unit.job != null else ""
				foil.begin_battle(unit.display_name, job_name, 0)

	_start_deployment(units)


# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# Block turn input while any controller is mid-animation.
	if _move_controller.is_executing() or _action_controller.is_executing():
		return
	# While the facing picker is driving CHOOSING_FACING, it owns ESC and
	# the board — everything else is a no-op until the player confirms or
	# cancels the end-turn.
	if _turn_manager.get_phase() == TurnEnums.TurnPhase.CHOOSING_FACING:
		return
	if event.is_action_pressed("cancel_action"):
		_action_controller.cancel_targeting()
		return
	if event.is_action_pressed("end_turn"):
		_turn_manager.end_turn()
	elif event.is_action_pressed("wait_turn"):
		_turn_manager.wait_and_end_turn()


func _register_battle_input_actions() -> void:
	_ensure_action("end_turn", KEY_SPACE)
	_ensure_action("wait_turn", KEY_W)
	_ensure_action("cancel_action", KEY_ESCAPE)


static func _ensure_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)


# =============================================================================
# TURN-DRIVEN CAMERA + ENEMY AI
# =============================================================================

func _on_turn_started(unit: Unit) -> void:
	_camera_rig.set_focus(unit.global_position)
	await _check_turn_triggers()

	if unit.team != UnitEnums.Team.PLAYER:
		# Run the enemy brain. Async so we can sequence think-delay → act →
		# move → act again → end.
		_run_enemy_turn(unit)


func _run_enemy_turn(unit: Unit) -> void:
	await get_tree().create_timer(enemy_think_delay).timeout

	if not _still_this_unit_turn(unit):
		return

	# First pass: can we already hit someone?
	var acted: bool = _action_controller.enemy_act_if_possible(unit)
	if acted:
		await get_tree().create_timer(enemy_think_delay).timeout

	# Move toward the nearest enemy if we still have the move.
	if _still_this_unit_turn(unit) and not _turn_manager.has_moved():
		var goal: Vector2i = _closest_reachable_toward_enemy(unit)
		if goal != unit.coord:
			await _move_controller.execute_move(unit, goal)

			if not _still_this_unit_turn(unit):
				return

			# Second pass: now that we moved, maybe we can hit.
			if not _turn_manager.has_acted():
				acted = _action_controller.enemy_act_if_possible(unit)
				if acted:
					await get_tree().create_timer(enemy_think_delay).timeout

	if _still_this_unit_turn(unit):
		# Auto-face toward the nearest remaining hostile so the enemy's back
		# isn't comically exposed. Then end immediately — no picker for AI.
		var threat: Unit = _nearest_hostile(unit)
		if threat != null:
			unit.face_toward(threat.coord)
		_turn_manager.end_turn_immediate()


## Pick the reachable tile closest (manhattan) to the nearest hostile unit.
## If already in attack range, stays put. If no hostile alive, no movement.
func _closest_reachable_toward_enemy(unit: Unit) -> Vector2i:
	var nearest_enemy: Unit = _nearest_hostile(unit)
	if nearest_enemy == null:
		return unit.coord

	var ally_ids: Dictionary = {}
	for ally in _unit_spawner.get_units_on_team(unit.team):
		if ally.unit_id != unit.unit_id and ally.is_alive():
			ally_ids[ally.unit_id] = true
	var reachable: Dictionary = Pathfinder.reachable_tiles(_grid, unit, ally_ids)
	if reachable.is_empty():
		return unit.coord

	var best_coord: Vector2i = unit.coord
	var best_dist: int = BattleGrid.manhattan(unit.coord, nearest_enemy.coord)
	for coord in reachable:
		var dist: int = BattleGrid.manhattan(coord, nearest_enemy.coord)
		if dist < best_dist:
			best_dist = dist
			best_coord = coord
	return best_coord


func _nearest_hostile(unit: Unit) -> Unit:
	var best: Unit = null
	var best_dist: int = 999999
	for other in _unit_spawner.get_all_units():
		if other == null or not other.is_alive():
			continue
		if not UnitEnums.teams_are_hostile(unit.team, other.team):
			continue
		var d: int = BattleGrid.manhattan(unit.coord, other.coord)
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _still_this_unit_turn(unit: Unit) -> bool:
	return _turn_manager.get_active_unit() == unit \
		and _turn_manager.get_outcome() == TurnEnums.BattleOutcome.ONGOING


func _on_battle_ended(outcome: int) -> void:
	print("[battle] ended with outcome=%d" % outcome)

	var turn_count: int = _turn_manager.get_turn_number()

	# Commit every player-unit FOIL record. Dead units commit too — their
	# action trail still informs the rolling-window profile even if the
	# character perished. Full "death resets window" handling is a legacy
	# system concern for later.
	var foil: Node = get_tree().root.get_node_or_null("FOILTracker")
	if foil != null:
		var was_victory: bool = outcome == TurnEnums.BattleOutcome.PLAYER_VICTORY
		foil.commit_all_battles(turn_count, was_victory)

	var post_scene: String = SceneManager.consume_post_battle_scene()
	if not post_scene.is_empty():
		await _play_scene(post_scene)

	# Surface the end-of-battle summary modal.
	_battle_summary.show_summary(
		outcome as TurnEnums.BattleOutcome,
		turn_count,
		_unit_spawner.get_all_units(),
		_battle_rewards,
		SceneManager.get_endless_round(),
		StoryManager.is_story_active(),
	)


func _on_retry_pressed() -> void:
	if StoryManager.is_story_active():
		StoryManager.abandon()
		return
	SceneManager.end_endless_run()
	GameManager.delete_save()
	_battle_summary.hide_summary()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_quit_pressed() -> void:
	SceneManager.end_endless_run()
	get_tree().quit()


## Endless mode win condition playlist: 4× Defeat All → Defeat Boss →
## Loot All Chests → repeat. round_number is 1-indexed.
static func _win_condition_for_endless_round(round_number: int) -> TurnEnums.WinCondition:
	var idx: int = (round_number - 1) % 6
	if idx == 4:
		return TurnEnums.WinCondition.DEFEAT_BOSS
	if idx == 5:
		return TurnEnums.WinCondition.LOOT_ALL_CHESTS
	return TurnEnums.WinCondition.DEFEAT_ALL


static func _random_enemy_pool() -> Array:
	var all_jobs: Array = JobLibrary.all_alpha_jobs()
	all_jobs.shuffle()
	var pool: Array = []
	for i in mini(3, all_jobs.size()):
		pool.append({"job": String(all_jobs[i].job_name), "role": "default"})
	return pool


func _on_continue_pressed() -> void:
	if StoryManager.is_story_active():
		_battle_summary.hide_summary()
		StoryManager.advance()
		return
	# Save before advancing so the file always holds the last completed round.
	GameManager.save_game(_unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER))
	var completed_round: int = SceneManager.get_endless_round()
	SceneManager.advance_endless_round()
	var next_round: int = SceneManager.get_endless_round()
	SceneManager.set_win_condition(_win_condition_for_endless_round(next_round))
	SceneManager.set_player_jobs(SceneManager.get_endless_player_jobs())
	SceneManager.set_player_names(SceneManager.get_endless_player_names())
	var templates: Array = _MapLibrary.all_templates()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var next_template: MapTemplate = templates[rng.randi_range(0, templates.size() - 1)]
	SceneManager.set_map_template(next_template.template_name)
	SceneManager.set_terrain_intensity(randf_range(0.8, 1.4))

	_battle_summary.hide_summary()
	var player_units: Array = _unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER)
	var shop := ShopScreen.new()
	shop.init(completed_round, _avg_player_level(), player_units)
	add_child(shop)
	shop.closed.connect(func():
		# Re-save so shop purchases + recruits are captured.
		GameManager.save_game(_unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER))
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)


func _avg_player_level() -> int:
	var units: Array = _unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER)
	if units.is_empty():
		return 1
	var sum: int = 0
	for u in units:
		sum += u.character_level
	return roundi(float(sum) / units.size())


# =============================================================================
# SCENE DIRECTOR
# =============================================================================

func _play_scene(filename: String) -> void:
	var data: SceneData = SceneLibrary.load_scene(filename)
	if data == null:
		push_warning("main: scene file not found — '%s'" % filename)
		return
	_scene_director = SceneDirector.new()
	add_child(_scene_director)
	_scene_director.camera_pan.connect(func(pos): _camera_rig.set_focus(pos))
	_scene_director.start(data, _build_role_map(data), _grid)
	await _scene_director.finished
	_scene_director = null


func _build_role_map(scene: SceneData) -> Dictionary:
	var map: Dictionary = {}
	# Story-planner overrides take priority over the scene file's own slot assignments.
	# consume_pre_battle_actor_slots clears after first call so mid/post scenes use
	# the scene's own slots.
	var slot_overrides: Dictionary = SceneManager.consume_pre_battle_actor_slots()
	var player_units: Array = _unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER)
	var enemy_units:  Array = _unit_spawner.get_units_on_team(UnitEnums.Team.ENEMY)
	for role in scene.get_actor_roles():
		var slot: String = slot_overrides.get(role, scene.get_actor_unit_slot(role))
		if slot.begins_with("player_"):
			var idx: int = int(slot.substr(7)) - 1
			if idx >= 0 and idx < player_units.size():
				map[role] = player_units[idx]
		elif slot.begins_with("enemy_"):
			var idx: int = int(slot.substr(6)) - 1
			if idx >= 0 and idx < enemy_units.size():
				map[role] = enemy_units[idx]
		else:
			for unit in _unit_spawner.get_all_units():
				if unit != null and unit.display_name == role:
					map[role] = unit
					break
	return map


## Fire any turn-triggered scenes whose turn threshold has been reached.
## Each trigger fires at most once per battle.
func _check_turn_triggers() -> void:
	var turn_num: int = _turn_manager.get_turn_number()
	for entry in _triggered_scenes:
		if entry.get("trigger") != "turn":
			continue
		var at_turn: int = int(entry.get("turn", -1))
		if at_turn < 0 or _turn_triggers_fired.has(at_turn):
			continue
		if turn_num >= at_turn:
			_turn_triggers_fired[at_turn] = true
			var fname: String = entry.get("filename", "")
			if not fname.is_empty():
				await _play_scene(fname)


# =============================================================================
# REINFORCEMENTS
# =============================================================================

## Build the wave schedule based on the current endless round.
## Rounds 1-2: no waves (too early). Round 3+: increasingly large/frequent waves.
## Practice mode: no reinforcements.
func _setup_reinforcements() -> void:
	if not SceneManager.is_endless_mode():
		return
	var round: int = SceneManager.get_endless_round()
	if round < 3:
		return
	var jobs: Array = JobLibrary.all_alpha_jobs().map(func(j): return j.job_name)
	if jobs.is_empty():
		return
	_reinf_schedule = {
		"wave_interval": maxi(4, 8 - round),           # turns between waves (min 4)
		"wave_size":     mini(4, 1 + (round / 3)),     # units per wave (grows with round)
		"waves_total":   mini(4, round - 2),            # total wave cap
		"job_pool":      jobs,
	}


## Called on every turn_ended. Increments the counter and spawns a wave when
## the interval fires and there are still waves remaining.
func _on_turn_ended_check_reinf(_unit: Unit) -> void:
	if _reinf_schedule.is_empty():
		return
	if _reinf_waves_sent >= _reinf_schedule["waves_total"]:
		return
	if _turn_manager.get_outcome() != TurnEnums.BattleOutcome.ONGOING:
		return
	_reinf_turn_counter += 1
	if _reinf_turn_counter % _reinf_schedule["wave_interval"] != 0:
		return
	# Spawn the wave and register each unit with the turn manager.
	var new_units: Array = _unit_spawner.spawn_enemy_wave(
		_grid, _units_root,
		_reinf_schedule["job_pool"],
		_reinf_schedule["wave_size"],
		_reinf_waves_sent
	)
	for unit in new_units:
		_turn_manager.register_unit(unit)
	_reinf_waves_sent += 1
	if not new_units.is_empty():
		_show_reinf_notification(_reinf_waves_sent, _reinf_schedule["waves_total"])


## Brief red banner at the top of the screen so the player knows a wave arrived.
func _show_reinf_notification(wave_num: int, wave_total: int) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var lbl := Label.new()
	lbl.text = "! Enemy Reinforcements  (%d / %d) !" % [wave_num, wave_total]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.position = Vector2(0, 72)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	canvas.add_child(lbl)
	var tween := canvas.create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tween.tween_callback(canvas.queue_free)


# =============================================================================
# STRUCTURE ENTER
# =============================================================================

func _on_enter_structure(unit: Unit) -> void:
	var entry: Dictionary = _structure_manager.entry_at_approach(unit.coord)
	if entry.is_empty():
		return
	var data = entry["data"]
	_ability_bar.hide_bar()
	_show_interior_panel(unit, data, entry)


func _show_interior_panel(unit: Unit, data: StructureData, entry: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(340, 240)

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = data.label
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	vbox.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	if entry["looted"]:
		desc.text = "The interior has already been searched."
	else:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var loot_tag: String = data.interior_loot
		var table = LootLibrary.elite_chest() if loot_tag == "elite" else LootLibrary.standard_chest()
		var drops: Array = LootResolver.roll(table, rng)
		SceneManager.add_gold(100)
		if _combat_log != null and unit != null:
			_combat_log.push("  +100 g from chest", Color(1.0, 0.85, 0.4))
		if drops.is_empty():
			desc.text = "You search inside but find nothing of value."
			if _combat_log != null and unit != null:
				_combat_log.push("%s  Search: nothing" % unit.display_name)
		else:
			var lines: Array = ["Inside you find:"]
			var tally: Dictionary = {}
			for tag in drops:
				tally[tag] = tally.get(tag, 0) + 1
			var party_inv: Inventory = SceneManager.get_party_inventory()
			for tag in tally:
				var count: int = tally[tag]
				if _battle_rewards != null:
					for _i in count:
						_battle_rewards.add_drop(tag, data.label)
				var display: String = LootLibrary.display_name(tag)
				lines.append("  %s × %d" % [display, count])
				for _i in count:
					var loot_item := ItemLibrary.get_item(StringName(tag))
					if loot_item == null or not loot_item.is_consumable():
						continue
					if party_inv.is_full():
						if _combat_log != null:
							_combat_log.push("  Chest: %s  (bag full)" % display, Color(1.0, 0.85, 0.4))
					else:
						party_inv.add_item(loot_item)
						if _combat_log != null:
							_combat_log.push("  Chest: %s → bag" % display, Color(1.0, 0.85, 0.4))
			desc.text = "\n".join(lines)
		_structure_manager.mark_looted(entry)
	desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(desc)

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.custom_minimum_size = Vector2(120, 38)
	exit_btn.add_theme_font_size_override("font_size", 15)
	vbox.add_child(exit_btn)

	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	canvas.add_child(panel)

	exit_btn.pressed.connect(func():
		canvas.queue_free()
		# Resume the turn — re-show ability bar without Enter (now looted).
		if unit != null and unit.is_alive() and _turn_manager.get_active_unit() == unit:
			_ability_bar.show_for_unit(unit,
				not _turn_manager.has_moved(),
				_turn_manager.has_moved() and not _turn_manager.has_acted(),
				not _turn_manager.has_acted(),
				false
			)
	)


# =============================================================================
# TILE INPUT FEEDBACK
# =============================================================================

func _grid_center_world(map: BattleGrid) -> Vector3:
	return Vector3(
		(float(map.width) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
		0.0,
		(float(map.height) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
	)


func _on_tile_hovered(coord: Vector2i) -> void:
	if _grid == null:
		return
	var tile := _grid.get_tile(coord)
	if tile != null:
		_camera_rig.set_zoom_target(tile.top_world_position())
	# During deployment or CHOOSING_FACING, those systems own highlights.
	if _deploying:
		return
	if _turn_manager.get_phase() == TurnEnums.TurnPhase.CHOOSING_FACING:
		return
	if _action_controller.is_target_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.TARGET)
	elif _action_controller.is_range_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.HOVER)
	elif _move_controller.is_preview_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.PATH)
	else:
		_grid.set_highlight(coord, GridEnums.HighlightState.HOVER)


func _on_tile_unhovered(coord: Vector2i) -> void:
	_camera_rig.clear_zoom_target()
	if _grid == null:
		return
	# During deployment or CHOOSING_FACING, those systems own highlights.
	if _deploying:
		return
	if _turn_manager.get_phase() == TurnEnums.TurnPhase.CHOOSING_FACING:
		return
	if _action_controller.is_target_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.ATTACK_RANGE)
	elif _action_controller.is_range_tile(coord):
		# Restore full-range highlight for empty in-range tiles.
		_grid.set_highlight(coord, GridEnums.HighlightState.ATTACK_RANGE)
	elif _move_controller.is_preview_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.MOVE_RANGE)
	else:
		_grid.set_highlight(coord, GridEnums.HighlightState.NONE)


# =============================================================================
# FOIL HELPERS
# =============================================================================

## The spawner assigns display_names from JobData.display_name. Predict what
## those will be so we can pull FOIL profiles for those exact keys BEFORE
## the units are instantiated. If JobLibrary.get_job returns null for some
## reason, fall back to a title-cased job-name string.
func _predict_player_character_names(player_jobs: Array = []) -> Array:
	var jobs: Array = player_jobs if not player_jobs.is_empty() else UnitSpawner.PLAYER_JOB_ORDER
	var names: Array = []
	for job_name in jobs:
		var job := JobLibrary.get_job(job_name)
		if job != null and not job.display_name.is_empty():
			names.append(job.display_name)
		else:
			names.append(String(job_name).capitalize())
	return names


func _log_encounter_summary(encounter: Dictionary) -> void:
	var debug_mgr: Node = get_tree().root.get_node_or_null("DebugManager")
	if debug_mgr == null:
		return
	var profile: FOILProfile = encounter["profile"]
	debug_mgr.log(DebugEnums.CATEGORY_FOIL, "encounter: level=%d source=%s primary=%s dominant=%s conf=%.2f" % [
		encounter["level"],
		encounter["level_source"],
		encounter["primary_character"],
		_archetype_name(profile.dominant_archetype),
		profile.confidence,
	])
	for note in encounter["loadout"].get("notes", []):
		debug_mgr.log(DebugEnums.CATEGORY_FOIL, "  loadout note: " + str(note))


static func _archetype_name(a: FOILEnums.Archetype) -> String:
	match a:
		FOILEnums.Archetype.MELEE_AGGRO:    return "MELEE_AGGRO"
		FOILEnums.Archetype.RANGED_KITE:    return "RANGED_KITE"
		FOILEnums.Archetype.MAGIC_OFFENSE:  return "MAGIC_OFFENSE"
		FOILEnums.Archetype.HEALER_SUPPORT: return "HEALER_SUPPORT"
		FOILEnums.Archetype.TANK_WALL:      return "TANK_WALL"
		FOILEnums.Archetype.AOE_BLASTER:    return "AOE_BLASTER"
		FOILEnums.Archetype.DEBUFFER:       return "DEBUFFER"
		FOILEnums.Archetype.HYBRID:         return "HYBRID"
	return "?"


func _on_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if _grid == null:
		return

	if _deploying:
		_on_deploy_tile_clicked(coord, button_index)
		return

	var tile := _grid.get_tile(coord)
	if tile == null:
		return

	# Unit inspect: left-click outside of move/target/ability-bar mode only.
	# During an active player turn the ability bar owns the screen; inspect
	# is accessed via the Status button instead.
	var ability_bar_open: bool = _ability_bar != null and _ability_bar.is_bar_visible()
	if button_index == MOUSE_BUTTON_LEFT \
	and not ability_bar_open \
	and not _move_controller.is_previewing() \
	and not _action_controller.is_selecting_target() \
	and not _action_controller.is_executing() \
	and not _action_controller.is_in_move_mode() \
	and tile.occupant_id != &"":
		var u := _unit_spawner.get_unit(tile.occupant_id)
		if u != null:
			_show_unit_inspect(u)
		else:
			_hide_unit_inspect()
	else:
		_hide_unit_inspect()

	if not log_tile_events:
		return
	var occupant_info: String = ""
	if tile.occupant_id != &"":
		var u := _unit_spawner.get_unit(tile.occupant_id)
		if u != null:
			occupant_info = " occupant=%s(%s hp=%d/%d ct=%d)" % [
				u.unit_id, u.display_name,
				u.stats.hp, u.stats.max_hp,
				_turn_manager.get_ct(u.unit_id),
			]
	print("[tile %s] terrain=%d height=%d walkable=%s button=%d%s" % [
		coord, int(tile.terrain), tile.height, tile.is_walkable(),
		button_index, occupant_info
	])


# =============================================================================
# DEPLOYMENT PHASE
# =============================================================================

## Enter deployment: highlight the zone, show the panel, let the player
## rearrange units before the battle begins.
func _start_deployment(units: Array) -> void:
	_deploying = true
	_deploy_selected = null
	_deploy_zone = _compute_deploy_zone()

	for coord in _deploy_zone:
		var tile := _grid.get_tile(coord)
		if tile != null and tile.is_walkable() and tile.structure_id == &"":
			_grid.set_highlight(coord, GridEnums.HighlightState.DEPLOY_ZONE)

	_build_deploy_panel(units)


## Zone: bottom 4 rows × left 7 columns, covering all 6 player spawn points.
func _compute_deploy_zone() -> Array:
	var zone: Array = []
	var x_max: int = 7
	var y_start: int = maxi(0, _grid.height - 4)
	for y in range(y_start, _grid.height):
		for x in range(0, x_max):
			zone.append(Vector2i(x, y))
	return zone


func _build_deploy_panel(units: Array) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	_deploy_panel = canvas

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(200, 0)
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Deploy Units"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Click a unit, then click\na blue tile to place it."
	hint.add_theme_font_size_override("font_size", 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(hint)

	# Unit buttons — click to select.
	for unit in units:
		if unit.team != UnitEnums.Team.PLAYER:
			continue
		var btn := Button.new()
		btn.text = unit.display_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var u: Unit = unit
		btn.pressed.connect(func(): _deploy_select(u))
		vbox.add_child(btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var player_units: Array = units.filter(func(u): return u.team == UnitEnums.Team.PLAYER)
	var equip_btn := Button.new()
	equip_btn.text = "Set Equipment"
	equip_btn.add_theme_font_size_override("font_size", 13)
	equip_btn.pressed.connect(func():
		var screen := EquipmentScreen.new()
		screen.init(player_units)
		add_child(screen)
	)
	vbox.add_child(equip_btn)

	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.add_theme_font_size_override("font_size", 15)
	confirm.pressed.connect(_confirm_deployment)
	vbox.add_child(confirm)


func _on_deploy_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_RIGHT:
		_deploy_deselect()
		return

	var tile := _grid.get_tile(coord)
	if tile == null:
		return

	# Clicking a tile that has a player unit → select it.
	if tile.occupant_id != &"":
		var unit := _unit_spawner.get_unit(tile.occupant_id)
		if unit != null and unit.team == UnitEnums.Team.PLAYER:
			_deploy_select(unit)
			return

	# Clicking an empty deploy zone tile with a selected unit → move there.
	if _deploy_selected != null \
	and coord in _deploy_zone \
	and tile.is_walkable() \
	and tile.structure_id == &"" \
	and not tile.is_occupied():
		_deploy_move_unit(_deploy_selected, coord)


func _deploy_select(unit: Unit) -> void:
	# Restore previous selection's tile to DEPLOY_ZONE.
	if _deploy_selected != null:
		var prev := _deploy_selected.coord
		if prev in _deploy_zone:
			_grid.set_highlight(prev, GridEnums.HighlightState.DEPLOY_ZONE)
	_deploy_selected = unit
	_grid.set_highlight(unit.coord, GridEnums.HighlightState.HOVER)


func _deploy_deselect() -> void:
	if _deploy_selected != null:
		var prev := _deploy_selected.coord
		if prev in _deploy_zone:
			_grid.set_highlight(prev, GridEnums.HighlightState.DEPLOY_ZONE)
	_deploy_selected = null


func _deploy_move_unit(unit: Unit, to: Vector2i) -> void:
	var from: Vector2i = unit.coord
	_grid.clear_occupant(from)
	unit.place_on_tile(_grid.get_tile(to), true)
	_grid.set_occupant(to, unit.unit_id)
	# Keep the unit selected at its new tile.
	if from in _deploy_zone:
		_grid.set_highlight(from, GridEnums.HighlightState.DEPLOY_ZONE)
	_grid.set_highlight(to, GridEnums.HighlightState.HOVER)


func _confirm_deployment() -> void:
	_deploying = false
	_deploy_selected = null
	for coord in _deploy_zone:
		_grid.set_highlight(coord, GridEnums.HighlightState.NONE)
	_deploy_zone.clear()
	if _deploy_panel != null:
		_deploy_panel.queue_free()
		_deploy_panel = null
	var pre_scene: String = SceneManager.consume_pre_battle_scene()
	if not pre_scene.is_empty():
		await _play_scene(pre_scene)
	_turn_manager.begin_battle(_unit_spawner.get_all_units())


# =============================================================================
# UNIT INSPECT PANEL (dynamic, no .tscn needed)
# =============================================================================

func _build_inspect_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)

	_inspect_panel = PanelContainer.new()
	_inspect_panel.position = Vector2(900, 120)
	_inspect_panel.visible = false
	layer.add_child(_inspect_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_inspect_panel.add_child(margin)

	_inspect_label = Label.new()
	_inspect_label.add_theme_font_size_override("font_size", 13)
	margin.add_child(_inspect_label)


func _show_unit_inspect(unit: Unit) -> void:
	if _inspect_panel == null:
		return

	var job_name: String = unit.job.display_name if unit.job != null else "—"
	var team_str: String = "Player" if unit.team == UnitEnums.Team.PLAYER else "Enemy"

	var skill_names: Array = []
	for s in unit.skills:
		skill_names.append(s.display_name)
	var skills_str: String = ", ".join(skill_names) if not skill_names.is_empty() else "none"

	# Equipment rows — show slot: item name, or dash if empty
	var gear_lines: Array = []
	if unit.equipment != null:
		var slots: Array = [
			ItemEnums.EquipSlot.MAIN_HAND,
			ItemEnums.EquipSlot.OFF_HAND,
			ItemEnums.EquipSlot.HELM,
			ItemEnums.EquipSlot.BODY,
			ItemEnums.EquipSlot.BOOTS,
			ItemEnums.EquipSlot.CLOAK,
			ItemEnums.EquipSlot.NECKLACE,
		]
		for slot in slots:
			var item: ItemData = unit.equipment.get_item(slot)
			var slot_label: String = ItemEnums.slot_display_name(slot)
			var hand_tag: String = ""
			if item != null and item.weapon_hand != ItemEnums.WeaponHand.NONE:
				hand_tag = "  [%s]" % ItemEnums.weapon_hand_display_name(item.weapon_hand)
			gear_lines.append("  %-12s %s%s" % [slot_label + ":", item.display_name if item != null else "—", hand_tag])
		for i in 2:
			var ring: ItemData = unit.equipment.get_item(ItemEnums.EquipSlot.RING, i)
			gear_lines.append("  %-12s %s" % ["Ring %d:" % (i + 1), ring.display_name if ring != null else "—"])
	var gear_str: String = "\n".join(gear_lines) if not gear_lines.is_empty() else "  none"

	var xp_jp_str: String = ""
	if unit.team == UnitEnums.Team.PLAYER:
		var xp_needed: int = unit.get_xp_to_next_level()
		var job_level: int = 1
		var jp: int = 0
		if unit.progression != null and unit.job != null:
			job_level = unit.progression.get_job_level(unit.job.job_name)
			jp = unit.progression.get_ap(unit.job.job_name)
		xp_jp_str = "Lv %d   XP %d / %d   %s Lv %d   JP %d\n" % [
			unit.character_level,
			unit.character_xp,
			xp_needed,
			job_name,
			job_level,
			jp,
		]

	_inspect_label.text = (
		"%s  [%s]  %s\n" % [unit.display_name, team_str, job_name]
		+ xp_jp_str
		+ "HP %d/%d   MP %d/%d\n" % [unit.stats.hp, unit.stats.max_hp, unit.stats.mp, unit.stats.max_mp]
		+ "ATK %d  DEF %d  MAG %d  RES %d  SPD %d\n" % [
			unit.stats.attack, unit.stats.defense,
			unit.stats.magic, unit.stats.resistance, unit.stats.speed]
		+ "Skills: %s\n" % skills_str
		+ "Equipment:\n%s" % gear_str
	)
	_inspect_panel.visible = true


func _hide_unit_inspect() -> void:
	if _inspect_panel != null:
		_inspect_panel.visible = false


# =============================================================================
# WIN CONDITION — SETUP & CHECKS
# =============================================================================

## Clear builder-placed chests and scatter 5-7 fresh ones across the map for
## LOOT_ALL_CHESTS mode. Called after visualizer and units are both ready.
func _setup_loot_mode_chests() -> void:
	# Clear any chests the map builder placed so the count is exact.
	for tile in _grid.iter_tiles():
		if not tile.chest_loot_tag.is_empty():
			_grid.clear_chest(tile.coord)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var target_count: int = rng.randi_range(5, 7)

	# Build a reserved set: unit spawn zones + map border (the escape edge).
	var reserved: Dictionary = {}
	for unit in _unit_spawner.get_all_units():
		if unit != null:
			reserved[unit.coord] = true
	# Buffer the bottom-left player spawn quadrant (matches deploy zone).
	var y_start: int = maxi(0, _grid.height - 4)
	for y in range(y_start, _grid.height):
		for x in range(0, 7):
			reserved[Vector2i(x, y)] = true
	# Exclude the map border itself (that's the escape zone).
	for x in _grid.width:
		reserved[Vector2i(x, 0)] = true
		reserved[Vector2i(x, _grid.height - 1)] = true
	for y in _grid.height:
		reserved[Vector2i(0, y)] = true
		reserved[Vector2i(_grid.width - 1, y)] = true

	var candidates: Array = []
	for tile in _grid.iter_tiles():
		if reserved.has(tile.coord):
			continue
		if tile.is_terrain_walkable() and tile.structure_id == &"" \
		and tile.occupant_id == &"" and tile.chest_loot_tag.is_empty():
			candidates.append(tile.coord)

	candidates.shuffle()
	var placed := 0
	for coord in candidates:
		if placed >= target_count:
			break
		var tile := _grid.get_tile(coord)
		if tile != null:
			tile.chest_loot_tag = "standard"
			_grid.tile_changed.emit(coord)
			placed += 1

	_chests_total = placed
	_chests_looted = 0
	if _combat_log != null:
		_combat_log.push(
			"OBJECTIVE: Loot all %d chests, then reach the map edge!" % placed,
			Color(0.4, 0.9, 0.4)
		)


## Called by MoveController.chest_collected whenever a unit walks over a chest.
func _on_chest_collected(_coord: Vector2i) -> void:
	if _win_condition != TurnEnums.WinCondition.LOOT_ALL_CHESTS:
		return
	_chests_looted += 1
	_update_objective_hud()
	if _combat_log != null:
		var remaining := _chests_total - _chests_looted
		if remaining > 0:
			_combat_log.push("Chests remaining: %d" % remaining, Color(0.4, 0.9, 0.4))
		else:
			_combat_log.push("All chests looted! Reach the map edge to escape!", Color(0.4, 1.0, 0.4))
	_check_loot_win_condition()


## Check whether the loot-all-chests victory condition is now met.
## Fires after every move and after every chest collection.
func _check_loot_win_condition() -> void:
	if _win_condition != TurnEnums.WinCondition.LOOT_ALL_CHESTS:
		return
	if _chests_looted < _chests_total:
		return
	if _turn_manager.get_outcome() != TurnEnums.BattleOutcome.ONGOING:
		return
	for unit in _unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER):
		if unit.is_alive() and _is_map_edge(unit.coord):
			_turn_manager.end_battle(TurnEnums.BattleOutcome.PLAYER_VICTORY)
			return


func _is_map_edge(coord: Vector2i) -> bool:
	if _grid == null:
		return false
	return coord.x == 0 or coord.y == 0 \
		or coord.x == _grid.width - 1 or coord.y == _grid.height - 1


## Builds a small objective panel in the top-right corner.
func _build_objective_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 3
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-310, 16)
	panel.custom_minimum_size = Vector2(280, 0)
	canvas.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 14)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	margin.add_child(_objective_label)
	_update_objective_hud()


func _update_objective_hud() -> void:
	if _objective_label == null:
		return
	match _win_condition:
		TurnEnums.WinCondition.DEFEAT_ALL:
			_objective_label.text = "Defeat all enemies"
		TurnEnums.WinCondition.DEFEAT_BOSS:
			_objective_label.text = "Defeat the Boss!\n(other enemies may be ignored)"
		TurnEnums.WinCondition.LOOT_ALL_CHESTS:
			if _chests_looted < _chests_total:
				_objective_label.text = "Loot chests: %d / %d\nThen escape to the map edge" \
					% [_chests_looted, _chests_total]
			else:
				_objective_label.text = "All chests looted! Reach the map edge"


# =============================================================================
# SCENE PREVIEW  (Story Planner "▶ Test Scene on Map")
# =============================================================================

func _run_scene_preview() -> void:
	var preview: Dictionary = SceneManager.consume_scene_preview()
	var return_to: String   = preview.get("return_to", "res://scenes/main_menu/main_menu.tscn")

	# Hide all battle-specific UI — only the 3D grid and director dialogue show.
	_turn_hud.visible       = false
	_combat_log.visible     = false
	_battle_summary.visible = false
	_battle_rewards.clear()        # Node, not Control — no visible property; just reset drops
	_ability_bar.visible    = false
	_facing_picker.visible  = false

	# Optionally replace the default flat grid with the scene's authored map.
	var prev_level: String = preview.get("level_name", "")
	var prev_tmpl:  String = preview.get("map_template", "")
	var level_p_spawns: Array = []
	var level_e_spawns: Array = []
	if not prev_level.is_empty():
		var ld: LevelData = LevelLibrary.load_level(prev_level)
		if ld != null:
			_grid = LevelLoader.build(ld)
			_visualizer.set_grid(_grid)
			level_p_spawns = ld.player_spawns.duplicate()
			level_e_spawns = ld.enemy_spawns.duplicate()
	elif not prev_tmpl.is_empty():
		var tmpl = _MapLibrary.get_template(prev_tmpl)
		if tmpl == null:
			tmpl = _MapLibrary.open_field()
		_grid = _MapBuilder.build(tmpl, 1.0)
		_visualizer.set_grid(_grid)

	_camera_rig.set_focus(_grid_center_world(_grid), true)

	var scene_file: String  = preview.get("scene_file", "")
	var scene_data: SceneData = SceneLibrary.load_scene(scene_file)
	if scene_data == null:
		push_warning("main: scene preview — scene not found '%s'" % scene_file)
		get_tree().change_scene_to_file(return_to)
		return

	var role_map: Dictionary = _spawn_scene_preview_actors(scene_data, preview, level_p_spawns, level_e_spawns)

	var director := SceneDirector.new()
	add_child(director)
	director.camera_pan.connect(func(pos): _camera_rig.set_focus(pos))
	director.finished.connect(func():
		director.queue_free()
		get_tree().change_scene_to_file(return_to)
	, CONNECT_ONE_SHOT)
	director.start(scene_data, role_map, _grid)


## Spawn each actor as a visible unit at its authored start position.
## Returns a role_map dict (role → Unit) ready for SceneDirector.start().
func _spawn_scene_preview_actors(scene_data: SceneData, preview: Dictionary,
		level_p_spawns: Array = [], level_e_spawns: Array = []) -> Dictionary:
	var actor_slots:   Dictionary = preview.get("actor_slots", {})
	var player_jobs:   Array      = preview.get("player_jobs", [])
	var actor_facings: Dictionary = preview.get("actor_facings", {})
	var role_map: Dictionary    = {}
	var mid := Vector2i(_grid.width / 2, _grid.height / 2)
	var actor_idx: int = 0

	for role in scene_data.get_actor_roles():
		# Story planner override takes priority over the scene's own slot assignment.
		var slot: String = actor_slots.get(role, scene_data.get_actor_unit_slot(role))
		var job_name: StringName = _preview_job_for_slot(slot, player_jobs)
		if job_name == &"":
			continue

		var start: Vector2i = scene_data.get_actor_start_position(role)
		if start == Vector2i(-1, -1):
			# Use level spawn point for this slot if available.
			if slot.begins_with("player_"):
				var sidx: int = int(slot.substr(7)) - 1
				if sidx >= 0 and sidx < level_p_spawns.size():
					start = level_p_spawns[sidx]
			elif slot.begins_with("enemy_"):
				var sidx: int = int(slot.substr(6)) - 1
				if sidx >= 0 and sidx < level_e_spawns.size():
					start = level_e_spawns[sidx]
		if start == Vector2i(-1, -1):
			# Final fallback: spread around grid centre.
			var offsets: Array = [Vector2i(0,0), Vector2i(2,0), Vector2i(-2,0),
				Vector2i(1,1), Vector2i(-1,1), Vector2i(0,2), Vector2i(2,2)]
			start = mid + offsets[actor_idx % offsets.size()]
		actor_idx += 1

		# Walk up to 4 neighbours if the authored tile is blocked.
		var tile := _grid.get_tile(start)
		if tile == null or not tile.is_walkable() or tile.is_occupied():
			for delta in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nb: Vector2i = start + delta
				var nbt := _grid.get_tile(nb)
				if nbt != null and nbt.is_walkable() and not nbt.is_occupied():
					start = nb
					break

		var team: UnitEnums.Team = UnitEnums.Team.ENEMY \
			if slot.begins_with("enemy") else UnitEnums.Team.PLAYER
		var uid := StringName("preview_%s" % role)
		var unit: Unit = _unit_spawner.spawn_unit(job_name, team, uid, start, _grid, _units_root)
		if unit != null:
			unit.display_name = role
			var facing_str: String = actor_facings.get(role, "S")
			match facing_str.to_upper():
				"N": unit.set_facing(UnitEnums.Facing.NORTH)
				"E": unit.set_facing(UnitEnums.Facing.EAST)
				"W": unit.set_facing(UnitEnums.Facing.WEST)
				_:   unit.set_facing(UnitEnums.Facing.SOUTH)
			role_map[role] = unit

	return role_map


## Resolve which job to spawn for a given slot string.
## Returns a fallback job even when slot is unassigned so previews always show actors.
static func _preview_job_for_slot(slot: String, player_jobs: Array) -> StringName:
	if slot.begins_with("player_"):
		var idx: int = int(slot.substr(7)) - 1
		if idx >= 0 and idx < player_jobs.size():
			return StringName(str(player_jobs[idx]))
		var defaults: Array = UnitSpawner.PLAYER_JOB_ORDER
		if not defaults.is_empty():
			return defaults[idx % defaults.size()]
	elif slot.begins_with("enemy_"):
		return &"squire"
	# No slot assigned — default to first available player job.
	if not player_jobs.is_empty():
		return StringName(str(player_jobs[0]))
	return &"squire"
