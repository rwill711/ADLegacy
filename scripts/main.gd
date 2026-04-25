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


var _grid: BattleGrid = null
var _inspect_panel: PanelContainer = null
var _inspect_label: Label = null

## Cached encounter config from FOILBattleSetup at battle start. Consumed by
## the HUD status line and the FOIL debug panel.
var _current_encounter: Dictionary = {}


func _ready() -> void:
	_register_battle_input_actions()

	_grid = AlphaTestMap.build()
	_visualizer.set_grid(_grid)

	_visualizer.tile_hovered.connect(_on_tile_hovered)
	_visualizer.tile_unhovered.connect(_on_tile_unhovered)
	_visualizer.tile_clicked.connect(_on_tile_clicked)

	# Phase 6: run FOIL setup BEFORE spawning enemies so the loadout builder
	# can influence which jobs / consumables / AI hints the spawner uses.
	# The player character list comes from PLAYER_JOB_ORDER (parallel with
	# the display names the spawner will assign). We derive display names
	# from JobLibrary the same way the spawner does, so FOIL keys match.
	var player_names: Array = _predict_player_character_names()
	var encounter: Dictionary = FOILBattleSetup.build_encounter(
		player_names,
		UnitSpawner.default_base_enemy_pool(),
		3,
	)
	var units: Array = _unit_spawner.spawn_alpha_roster(
		_grid, _units_root, encounter["loadout"]
	)
	_current_encounter = encounter

	_camera_rig.set_focus(_grid_center_world(_grid), true)

	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.battle_ended.connect(_on_battle_ended)

	_turn_hud.bind_turn_manager(_turn_manager)
	_move_controller.bind(_grid, _visualizer, _turn_manager, _unit_spawner)
	_action_controller.bind(
		_grid, _visualizer, _turn_manager, _unit_spawner,
		_move_controller, _ability_bar, self
	)
	_facing_picker.bind_turn_manager(_turn_manager)
	_facing_picker.bind_visualizer(_visualizer)
	_facing_picker.bind_grid(_grid)

	_ability_bar.wait_pressed.connect(_turn_manager.wait_and_end_turn)
	_ability_bar.status_pressed.connect(_show_unit_inspect)

	_battle_summary.retry_pressed.connect(_on_retry_pressed)
	_battle_summary.quit_pressed.connect(_on_quit_pressed)

	_build_inspect_panel()

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

	# Surface the end-of-battle summary modal.
	_battle_summary.show_summary(
		outcome as TurnEnums.BattleOutcome,
		turn_count,
		_unit_spawner.get_all_units(),
	)


func _on_retry_pressed() -> void:
	_battle_summary.hide_summary()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


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
	if _action_controller.is_target_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.TARGET)
	elif _action_controller.is_range_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.HOVER)
	elif _move_controller.is_preview_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.PATH)
	else:
		_grid.set_highlight(coord, GridEnums.HighlightState.HOVER)


func _on_tile_unhovered(coord: Vector2i) -> void:
	if _grid == null:
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
func _predict_player_character_names() -> Array:
	var names: Array = []
	for job_name in UnitSpawner.PLAYER_JOB_ORDER:
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
			ItemEnums.EquipSlot.TRINKET,
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

	_inspect_label.text = (
		"%s  [%s]  %s\n" % [unit.display_name, team_str, job_name]
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
