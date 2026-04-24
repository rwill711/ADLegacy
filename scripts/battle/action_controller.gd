class_name ActionController extends Node
## Orchestrates the ACT phase and the turn-choice menu.
##
## Player turn flow (new):
##   turn_started  → ability bar shows Move + skills (no auto-move-preview)
##   Move clicked  → show move-range tiles; ability bar hidden
##   right-click while in move mode → cancel, restore ability bar
##   skill clicked → show full ATTACK_RANGE (all in-range tiles) + valid targets
##   tile clicked  → execute only if tile has a valid target (any alive unit)
##   move done     → ability bar shows skills + Undo Move + Wait
##   act done (no move yet) → ability bar shows Move + Wait only
##   undo move     → move_controller teleports back, ability bar restores Move button


## --- Config -----------------------------------------------------------------
@export var enemy_auto_target: bool = true
@export var log_actions: bool = true
@export var damage_text_color: Color = Color(1, 0.45, 0.45)
@export var heal_text_color: Color = Color(0.55, 1, 0.55)
@export var kill_text_color: Color = Color(1, 0.9, 0.4)
@export var buff_text_color: Color = Color(0.7, 0.85, 1)


## --- State ------------------------------------------------------------------
enum ActionState { IDLE, SELECTING_SKILL, SELECTING_TARGET, EXECUTING }

var _state: ActionState = ActionState.IDLE
var _active_unit: Unit = null
var _selected_skill: SkillData = null
var _valid_targets: Array = []   # Array[Vector2i] — tiles with alive units
var _range_tiles: Array = []     # Array[Vector2i] — all tiles in skill range
var _move_mode: bool = false     # true while move-preview is showing

## Refs set via bind()
var _grid: BattleGrid = null
var _visualizer: GridVisualizer = null
var _turn_manager: TurnManager = null
var _unit_spawner: UnitSpawner = null
var _move_controller: MoveController = null
var _ability_bar: AbilityBar = null
var _world_root: Node3D = null


# =============================================================================
# WIRING
# =============================================================================

func bind(
	grid: BattleGrid,
	visualizer: GridVisualizer,
	turn_manager: TurnManager,
	unit_spawner: UnitSpawner,
	move_controller: MoveController,
	ability_bar: AbilityBar,
	world_root: Node3D
) -> void:
	_grid = grid
	_visualizer = visualizer
	_turn_manager = turn_manager
	_unit_spawner = unit_spawner
	_move_controller = move_controller
	_ability_bar = ability_bar
	_world_root = world_root

	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.turn_ended.connect(_on_turn_ended)
	_turn_manager.battle_ended.connect(_on_battle_ended)
	_visualizer.tile_clicked.connect(_on_tile_clicked)
	_ability_bar.skill_selected.connect(_on_skill_selected)
	_ability_bar.move_requested.connect(_on_move_requested)
	_ability_bar.undo_move_requested.connect(_on_undo_move_requested)
	_move_controller.move_completed.connect(_on_move_completed)


# =============================================================================
# PUBLIC QUERIES
# =============================================================================

func is_selecting_target() -> bool:
	return _state == ActionState.SELECTING_TARGET


func is_executing() -> bool:
	return _state == ActionState.EXECUTING


func is_idle() -> bool:
	return _state == ActionState.IDLE


func is_in_move_mode() -> bool:
	return _move_mode


## True if `coord` is a tile the player can click to execute the current skill.
func is_target_tile(coord: Vector2i) -> bool:
	return _state == ActionState.SELECTING_TARGET and _valid_targets.has(coord)


## True if `coord` is within the current skill's attack range (may or may not
## have a target). Used by main.gd to restore the ATTACK_RANGE highlight on
## unhover so empty range tiles don't go dark.
func is_range_tile(coord: Vector2i) -> bool:
	return _state == ActionState.SELECTING_TARGET and _range_tiles.has(coord)


## Cancel the current skill selection back to the ability bar. Called by
## right-click in targeting mode.
func cancel_targeting() -> void:
	if _state != ActionState.SELECTING_TARGET:
		return
	_clear_target_highlights()
	_state = ActionState.SELECTING_SKILL
	if _active_unit != null and _active_unit.team == UnitEnums.Team.PLAYER:
		var can_move: bool = not _turn_manager.has_moved()
		var can_undo: bool = _turn_manager.has_moved() and not _turn_manager.has_acted()
		_ability_bar.show_for_unit(_active_unit, can_move, can_undo)


# =============================================================================
# TURN SIGNALS
# =============================================================================

func _on_turn_started(unit: Unit) -> void:
	_active_unit = unit
	_selected_skill = null
	_valid_targets.clear()
	_range_tiles.clear()
	_move_mode = false

	if unit == null or not unit.is_alive():
		_state = ActionState.IDLE
		_ability_bar.hide_bar()
		return

	if unit.team == UnitEnums.Team.PLAYER:
		_state = ActionState.SELECTING_SKILL
		# No auto-move-preview — player chooses Move or a skill from the bar.
		_ability_bar.show_for_unit(unit, true, false, true)
		_ensure_foil_battle_started(unit)
	else:
		_state = ActionState.IDLE
		_ability_bar.hide_bar()


func _on_turn_ended(_unit: Unit) -> void:
	_clear_target_highlights()
	_ability_bar.hide_bar()
	_move_mode = false
	_state = ActionState.IDLE


func _on_battle_ended(_outcome: int) -> void:
	_clear_target_highlights()
	_ability_bar.hide_bar()
	_move_mode = false
	_state = ActionState.IDLE


# =============================================================================
# MOVE MODE
# =============================================================================

func _on_move_requested() -> void:
	if _active_unit == null or _turn_manager.has_moved():
		return
	_move_mode = true
	_ability_bar.hide_bar()
	_move_controller.show_move_preview_for(_active_unit)


func _on_move_completed() -> void:
	_move_mode = false
	if _active_unit == null or _active_unit.team != UnitEnums.Team.PLAYER:
		return
	if not _active_unit.is_alive():
		return
	# Unit just moved. Show skill buttons + Undo Move (if they haven't acted).
	var can_undo: bool = not _turn_manager.has_acted()
	_ability_bar.show_for_unit(_active_unit, false, can_undo, not _turn_manager.has_acted())
	_state = ActionState.SELECTING_SKILL


func _on_undo_move_requested() -> void:
	if _active_unit == null:
		return
	_move_controller.undo_move()
	# After undo, restore the full turn-start layout (can move, no undo).
	_ability_bar.show_for_unit(_active_unit, true, false, not _turn_manager.has_acted())
	_state = ActionState.SELECTING_SKILL


# =============================================================================
# SKILL SELECTION / TARGETING
# =============================================================================

func _on_skill_selected(skill: SkillData) -> void:
	if _state != ActionState.SELECTING_SKILL:
		return
	if _active_unit == null:
		return

	_selected_skill = skill
	var all_units: Array = _unit_spawner.get_all_units()

	# Full attack range (all in-range tiles) — shown even if empty.
	_range_tiles = Targeting.tiles_in_range(_grid, _active_unit, skill)
	# Valid targets: any alive unit (enemy OR ally) in range.
	_valid_targets = Targeting.valid_anchors(_grid, _active_unit, skill, all_units, true)

	if _range_tiles.is_empty():
		if log_actions:
			print("[action] skill %s has zero range tiles" % skill.skill_name)
		_selected_skill = null
		return

	_move_controller.hide_preview()

	for coord in _range_tiles:
		_grid.set_highlight(coord, GridEnums.HighlightState.ATTACK_RANGE)
	_state = ActionState.SELECTING_TARGET
	_ability_bar.show_targeting(skill)
	if _valid_targets.is_empty() and log_actions:
		print("[action] %s — range shown, no valid targets yet" % skill.skill_name)


func _on_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_RIGHT:
		if _state == ActionState.SELECTING_TARGET:
			cancel_targeting()
		elif _move_mode:
			# Cancel move selection → restore ability bar.
			_move_mode = false
			_move_controller.hide_preview()
			_state = ActionState.SELECTING_SKILL
			if _active_unit != null and _active_unit.team == UnitEnums.Team.PLAYER:
				var can_undo: bool = _turn_manager.has_moved() and not _turn_manager.has_acted()
				_ability_bar.show_for_unit(_active_unit, not _turn_manager.has_moved(), can_undo)
		return
	if button_index != MOUSE_BUTTON_LEFT:
		return
	if _state != ActionState.SELECTING_TARGET:
		return
	if not _valid_targets.has(coord):
		return
	_execute_skill(coord)


# =============================================================================
# EXECUTION
# =============================================================================

func _execute_skill(anchor: Vector2i) -> void:
	_state = ActionState.EXECUTING
	_clear_target_highlights()
	_ability_bar.hide_bar()

	var caster: Unit = _active_unit
	var skill: SkillData = _selected_skill
	var all_units: Array = _unit_spawner.get_all_units()
	var turn_number: int = _turn_manager.get_turn_number()

	caster.face_toward(anchor)
	caster.set_state(UnitEnums.UnitState.ACTING)

	var result := AbilityResolver.resolve(caster, skill, anchor, _grid, all_units, turn_number)

	if log_actions:
		_log_result(caster, skill, result)
	_push_to_debug_log(caster, skill, result)
	_spawn_effect_visuals(caster, skill, result)
	if skill.skill_type == SkillEnums.SkillType.TERRAIN_MODIFY:
		_apply_terrain_skill(caster, skill, anchor)
	_record_caster_stats(caster, skill, result)

	if caster.team == UnitEnums.Team.PLAYER:
		_record_foil_actions(caster, skill, result, turn_number)

	caster.set_state(UnitEnums.UnitState.IDLE)
	_state = ActionState.IDLE

	var outcome := _turn_manager.check_outcome()
	if outcome != TurnEnums.BattleOutcome.ONGOING:
		_turn_manager.end_battle(outcome)
		return

	if _turn_manager.get_active_unit() == caster:
		_turn_manager.declare_acted()

	# If unit acted but still hasn't moved, give them the Move button only.
	if caster.team == UnitEnums.Team.PLAYER \
	and not _turn_manager.has_moved() \
	and caster.is_alive() \
	and _turn_manager.get_active_unit() == caster:
		_ability_bar.show_for_unit(caster, true, false, false)
		_state = ActionState.SELECTING_SKILL


# =============================================================================
# AI ENTRY — called from main.gd for enemy turns
# =============================================================================

func enemy_act_if_possible(unit: Unit) -> bool:
	if unit == null or not unit.is_alive():
		return false

	var all_units: Array = _unit_spawner.get_all_units()
	var best_plan: Dictionary = _pick_enemy_action(unit, all_units)
	if best_plan.is_empty():
		return false

	_selected_skill = best_plan["skill"]
	_active_unit = unit
	_valid_targets = [best_plan["anchor"]]
	_execute_skill(best_plan["anchor"])
	return true


func _pick_enemy_action(unit: Unit, all_units: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -1

	for skill in unit.get_castable_skills():
		# AI uses team-restricted targeting (friendly_fire=false).
		var anchors: Array = Targeting.valid_anchors(_grid, unit, skill, all_units, false)
		for anchor in anchors:
			var score: int = _score_enemy_target(unit, skill, anchor, all_units)
			if score > best_score:
				best_score = score
				best = {"skill": skill, "anchor": anchor}
	return best


static func _score_enemy_target(
	unit: Unit,
	skill: SkillData,
	anchor: Vector2i,
	all_units: Array
) -> int:
	var target: Unit = _find_unit_at(all_units, anchor)
	if target == null:
		return -1

	var base_score: int
	if skill.is_offensive():
		if not UnitEnums.teams_are_hostile(unit.team, target.team):
			return -1
		var missing: int = target.stats.max_hp - target.stats.hp
		base_score = 100 + missing
	elif skill.skill_type == SkillEnums.SkillType.HEALING:
		if UnitEnums.teams_are_hostile(unit.team, target.team):
			return -1
		base_score = 60 + (target.stats.max_hp - target.stats.hp)
	elif skill.skill_type == SkillEnums.SkillType.BUFF:
		base_score = 20
	else:
		base_score = 5

	return base_score + _ai_hint_bonus(unit, skill, target)


static func _ai_hint_bonus(unit: Unit, skill: SkillData, target: Unit) -> int:
	var hints: Dictionary = unit.ai_hints
	if hints.is_empty():
		return 0
	var bonus: int = 0
	if hints.get("target_priority", "") == "focus_healer" \
	and skill.is_offensive() \
	and _looks_like_healer(target):
		bonus += 60
	return bonus


static func _looks_like_healer(target: Unit) -> bool:
	if target == null or target.job == null:
		return false
	if String(target.job.job_name) == "white_mage":
		return true
	for skill in target.skills:
		if skill.skill_type == SkillEnums.SkillType.HEALING:
			return true
	return false


static func _find_unit_at(all_units: Array, coord: Vector2i) -> Unit:
	for u in all_units:
		if u != null and u.coord == coord:
			return u
	return null


# =============================================================================
# TERRAIN SKILLS (Chop, Push Rock)
# =============================================================================

func _apply_terrain_skill(caster: Unit, skill: SkillData, anchor: Vector2i) -> void:
	var tile: GridTile = _grid.get_tile(anchor)
	if tile == null:
		return

	match skill.skill_name:
		SkillLibrary.CHOP:
			if tile.terrain == GridEnums.TerrainType.FOREST:
				_grid.set_terrain(anchor, GridEnums.TerrainType.GRASS)
				FloatingText.spawn(_world_root, "Chop!", Color(0.6, 1.0, 0.4),
					caster.global_position + Vector3(0, 1.4, 0))

		SkillLibrary.PUSH_ROCK:
			if tile.terrain != GridEnums.TerrainType.MOUNTAIN:
				return
			var dir: Vector2i = anchor - caster.coord
			var push_to: Vector2i = anchor + dir
			var dest: GridTile = _grid.get_tile(push_to)
			if dest != null \
			and GridEnums.is_terrain_walkable(dest.terrain) \
			and dest.occupant_id == &"" \
			and dest.object_id == &"":
				_grid.set_terrain(anchor, GridEnums.TerrainType.GRASS)
				_grid.set_terrain(push_to, GridEnums.TerrainType.MOUNTAIN)
				FloatingText.spawn(_world_root, "Push!", Color(0.9, 0.8, 0.4),
					caster.global_position + Vector3(0, 1.4, 0))
			else:
				FloatingText.spawn(_world_root, "Blocked!", Color(0.8, 0.4, 0.4),
					caster.global_position + Vector3(0, 1.4, 0))


# =============================================================================
# VISUALS
# =============================================================================

func _spawn_effect_visuals(_caster: Unit, skill: SkillData, result: Dictionary) -> void:
	if _world_root == null:
		return
	for effect in result["effects"]:
		var unit := _unit_spawner.get_unit(effect["target_id"])
		if unit == null:
			continue
		var anchor_pos: Vector3 = unit.global_position + Vector3(0, 1.4, 0)
		var text: String = ""
		var color: Color = damage_text_color

		if effect["damage"] > 0:
			text = str(effect["damage"])
			color = damage_text_color
			if effect["was_kill"]:
				text += "!"
				color = kill_text_color
			if effect["side"] == 2:
				text = "✦ " + text
		elif effect["heal"] > 0:
			text = "+%d" % effect["heal"]
			color = heal_text_color
		elif effect["buff_label"] != "":
			text = effect["buff_label"]
			color = buff_text_color
		else:
			continue

		FloatingText.spawn(_world_root, text, color, anchor_pos)


# =============================================================================
# DEBUG LOG
# =============================================================================

func _push_to_debug_log(caster: Unit, skill: SkillData, result: Dictionary) -> void:
	var mgr: Node = get_tree().root.get_node_or_null("DebugManager")
	if mgr == null:
		return
	var summary_parts: Array = []
	summary_parts.append("%s cast %s" % [caster.unit_id, skill.skill_name])
	for effect in result["effects"]:
		var fragment: String = ""
		if effect["damage"] > 0:
			fragment = "%s -%d%s" % [effect["target_id"], effect["damage"],
				" KILL" if effect["was_kill"] else ""]
		elif effect["heal"] > 0:
			fragment = "%s +%d heal" % [effect["target_id"], effect["heal"]]
		elif effect["buff_label"] != "":
			fragment = "%s buff=%s" % [effect["target_id"], effect["buff_label"]]
		if fragment != "":
			summary_parts.append(fragment)
	mgr.log(DebugEnums.CATEGORY_COMBAT, " | ".join(summary_parts))


# =============================================================================
# BATTLE STATS AGGREGATION
# =============================================================================

static func _record_caster_stats(caster: Unit, skill: SkillData, result: Dictionary) -> void:
	if caster == null or skill == null:
		return
	var total_damage: int = 0
	var any_kill: bool = false
	for effect in result["effects"]:
		total_damage += int(effect["damage"])
		if effect["was_kill"]:
			any_kill = true
	caster.record_action_stats(skill.skill_name, total_damage, any_kill)


# =============================================================================
# FOIL INTEGRATION
# =============================================================================

func _ensure_foil_battle_started(unit: Unit) -> void:
	if unit == null or unit.team != UnitEnums.Team.PLAYER:
		return
	var foil := _get_foil()
	if foil == null:
		return
	if foil.has_character_battle(unit.display_name):
		return
	var job_name: String = ""
	if unit.job != null:
		job_name = String(unit.job.job_name)
	foil.begin_battle(unit.display_name, job_name, 0)


func _record_foil_actions(
	caster: Unit,
	skill: SkillData,
	result: Dictionary,
	turn_number: int
) -> void:
	var foil := _get_foil()
	if foil == null:
		return

	for effect in result["effects"]:
		var target := _unit_spawner.get_unit(effect["target_id"])
		var target_name: String = ""
		var target_job: String = ""
		var targeted_ally: bool = false
		if target != null:
			target_name = target.display_name
			if target.job != null:
				target_job = String(target.job.job_name)
			targeted_ally = not UnitEnums.teams_are_hostile(caster.team, target.team)

		var engagement: int = BattleGrid.manhattan(caster.coord, effect["target_coord"])

		foil.record_action(
			caster.display_name,
			String(skill.skill_name),
			skill.foil_category(),
			skill.is_area(),
			target_name,
			target_job,
			targeted_ally,
			effect["damage"],
			effect["was_kill"],
			effect["was_hit"],
			engagement,
			caster.coord,
			effect["target_coord"],
			turn_number,
		)


func _get_foil() -> Node:
	var root := get_tree().root
	return root.get_node_or_null("FOILTracker")


# =============================================================================
# HELPERS
# =============================================================================

func _clear_target_highlights() -> void:
	for coord in _range_tiles:
		var tile := _grid.get_tile(coord)
		if tile == null:
			continue
		if tile.highlight_state == GridEnums.HighlightState.ATTACK_RANGE \
		or tile.highlight_state == GridEnums.HighlightState.TARGET:
			_grid.set_highlight(coord, GridEnums.HighlightState.NONE)
	_range_tiles.clear()
	_valid_targets.clear()


func _log_result(caster: Unit, skill: SkillData, result: Dictionary) -> void:
	var lines: Array = []
	lines.append("[action] %s casts %s (mp_paid=%s)" % [
		caster.unit_id, skill.skill_name, result["mp_paid"]
	])
	for effect in result["effects"]:
		var side_label: String = ["front", "flank", "REAR"][effect["side"]]
		var outcome := ""
		if effect["damage"] > 0:
			outcome = "dmg=%d%s" % [
				effect["damage"],
				"  KILL" if effect["was_kill"] else ""
			]
		elif effect["heal"] > 0:
			outcome = "heal=%d" % effect["heal"]
		elif effect["buff_label"] != "":
			outcome = "buff=%s" % effect["buff_label"]
		lines.append("  → %s  side=%s  %s" % [effect["target_id"], side_label, outcome])
	print("\n".join(lines))
