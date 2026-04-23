extends Node3D
## Alpha entry scene. Builds the grid, spawns the roster, starts the battle,
## and orchestrates the player vs enemy turn loop via the subsystem
## controllers. Keeps the scene root thin — each concern (grid, camera,
## units, turns, moves, actions) owns its own module.


@export var log_tile_events: bool = true
@export var enemy_think_delay: float = 0.4  # "thinking" pause before enemy acts


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


var _grid: GridMap = null


func _ready() -> void:
	_register_battle_input_actions()

	_grid = AlphaTestMap.build()
	_visualizer.set_grid(_grid)

	_visualizer.tile_hovered.connect(_on_tile_hovered)
	_visualizer.tile_unhovered.connect(_on_tile_unhovered)
	_visualizer.tile_clicked.connect(_on_tile_clicked)

	var units: Array = _unit_spawner.spawn_alpha_roster(_grid, _units_root)

	_camera_rig.set_focus(_grid_center_world(_grid), true)

	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.battle_ended.connect(_on_battle_ended)

	_turn_hud.bind_turn_manager(_turn_manager)
	_move_controller.bind(_grid, _visualizer, _turn_manager)
	_action_controller.bind(
		_grid, _visualizer, _turn_manager, _unit_spawner,
		_move_controller, _ability_bar, self
	)
	_facing_picker.bind_turn_manager(_turn_manager)

	_battle_summary.retry_pressed.connect(_on_retry_pressed)
	_battle_summary.quit_pressed.connect(_on_quit_pressed)

	# Kick off FOIL battle records for every player unit up front, so even
	# actions on the first turn land in the rolling window.
	var foil: Node = get_tree().root.get_node_or_null("FOILTracker")
	if foil != null:
		for unit in units:
			if unit.team == UnitEnums.Team.PLAYER:
				var job_name: String = String(unit.job.job_name) if unit.job != null else ""
				foil.begin_battle(unit.display_name, job_name, 0)

	_turn_manager.begin_battle(units)


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

	var reachable: Dictionary = Pathfinder.reachable_tiles(_grid, unit)
	if reachable.is_empty():
		return unit.coord

	var best_coord: Vector2i = unit.coord
	var best_dist: int = GridMap.manhattan(unit.coord, nearest_enemy.coord)
	for coord in reachable:
		var dist: int = GridMap.manhattan(coord, nearest_enemy.coord)
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
		var d: int = GridMap.manhattan(unit.coord, other.coord)
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

	# Surface the end-of-battle summary modal.
	_battle_summary.show_summary(
		outcome as TurnEnums.BattleOutcome,
		turn_count,
		_unit_spawner.get_all_units(),
	)


func _on_retry_pressed() -> void:
	# Reload the whole battle scene. Units, stats, turn order — all rebuilt.
	# The FOIL rolling window persists across reloads because FOILTracker is
	# an autoload; that's exactly the "3 consecutive battles show FOIL
	# adaptation" success criterion from the roadmap.
	_battle_summary.hide_summary()
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().quit()


# =============================================================================
# TILE INPUT FEEDBACK
# =============================================================================

func _grid_center_world(map: GridMap) -> Vector3:
	return Vector3(
		(float(map.width) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
		0.0,
		(float(map.height) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
	)


func _on_tile_hovered(coord: Vector2i) -> void:
	if _grid == null:
		return
	# Hover highlight priority: move preview beats base, act preview beats
	# move preview.
	if _action_controller.is_target_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.TARGET)
	elif _move_controller.is_preview_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.PATH)
	else:
		_grid.set_highlight(coord, GridEnums.HighlightState.HOVER)


func _on_tile_unhovered(coord: Vector2i) -> void:
	if _grid == null:
		return
	# Restore the underlying preview color, or NONE if no preview applies.
	if _action_controller.is_target_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.ATTACK_RANGE)
	elif _move_controller.is_preview_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.MOVE_RANGE)
	else:
		_grid.set_highlight(coord, GridEnums.HighlightState.NONE)


func _on_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if not log_tile_events or _grid == null:
		return
	var tile := _grid.get_tile(coord)
	if tile == null:
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
