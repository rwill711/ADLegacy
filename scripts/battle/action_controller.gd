class_name ActionController extends Node
## Orchestrates the ACT phase. Mirrors MoveController in shape:
##   turn_started (player, haven't acted) → ability bar shows skills
##   skill_selected                       → show ATTACK_RANGE tiles
##   tile_clicked on valid target         → resolve, apply effects, floating numbers
##   completed                            → declare_acted, hide bar
##
## Also fires FOIL.record_action for every player-unit effect.


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
var _valid_targets: Array = []  # Array[Vector2i]

## Refs set via bind()
var _grid: GridMap = null
var _visualizer: GridVisualizer = null
var _turn_manager: TurnManager = null
var _unit_spawner: UnitSpawner = null
var _move_controller: MoveController = null
var _ability_bar: AbilityBar = null
## Node that hosts floating-text children (typically the Main node).
var _world_root: Node3D = null


# =============================================================================
# WIRING
# =============================================================================

func bind(
	grid: GridMap,
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


# =============================================================================
# PUBLIC QUERIES
# =============================================================================

func is_selecting_target() -> bool:
	return _state == ActionState.SELECTING_TARGET


func is_executing() -> bool:
	return _state == ActionState.EXECUTING


func is_target_tile(coord: Vector2i) -> bool:
	return _state == ActionState.SELECTING_TARGET and _valid_targets.has(coord)


## Cancel the current skill selection (back to SELECTING_SKILL). Bound to
## ESC / right-click from main.gd.
func cancel_targeting() -> void:
	if _state != ActionState.SELECTING_TARGET:
		return
	_clear_target_highlights()
	_state = ActionState.SELECTING_SKILL
	if _active_unit != null and _active_unit.team == UnitEnums.Team.PLAYER:
		_ability_bar.show_for_unit(_active_unit)
		# Bring the move preview back if the unit still has their move available.
		if not _turn_manager.has_moved():
			_move_controller.refresh_preview()


# =============================================================================
# TURN SIGNALS
# =============================================================================

func _on_turn_started(unit: Unit) -> void:
	_active_unit = unit
	_selected_skill = null
	_valid_targets.clear()

	if unit == null or not unit.is_alive():
		_state = ActionState.IDLE
		_ability_bar.hide_bar()
		return

	if unit.team == UnitEnums.Team.PLAYER:
		_state = ActionState.SELECTING_SKILL
		_ability_bar.show_for_unit(unit)

		# Kick off FOIL tracking for this player unit's turn on the first
		# time we see them this battle. begin_battle is idempotent per key,
		# but we want one record per character per battle. Phase 4's battle
		# lifecycle owner will handle begin_battle at BATTLE start instead;
		# for now, initialize lazily so actions don't drop.
		_ensure_foil_battle_started(unit)
	else:
		_state = ActionState.IDLE
		_ability_bar.hide_bar()
		# Enemy AI runs in a separate controller — we hand off via
		# enemy_act_if_possible which main.gd calls for enemy turns.


func _on_turn_ended(_unit: Unit) -> void:
	_clear_target_highlights()
	_ability_bar.hide_bar()
	_state = ActionState.IDLE


func _on_battle_ended(_outcome: int) -> void:
	_clear_target_highlights()
	_ability_bar.hide_bar()
	_state = ActionState.IDLE


# =============================================================================
# SKILL SELECTION / TARGETING
# =============================================================================

func _on_skill_selected(skill: SkillData) -> void:
	if _state != ActionState.SELECTING_SKILL:
		return
	if _active_unit == null:
		return

	_selected_skill = skill

	# Compute legal anchors for THIS skill from THIS caster right now.
	var all_units: Array = _unit_spawner.get_all_units()
	_valid_targets = Targeting.valid_anchors(_grid, _active_unit, skill, all_units)

	if _valid_targets.is_empty():
		# No legal targets — skill becomes a noop. Bounce back to skill select.
		if log_actions:
			print("[action] no valid targets for %s" % skill.skill_name)
		_selected_skill = null
		return

	# Hide move preview so clicks during targeting don't also trigger moves.
	# refresh_preview() puts it back if the player cancels (see cancel_targeting).
	_move_controller.hide_preview()

	for coord in _valid_targets:
		_grid.set_highlight(coord, GridEnums.HighlightState.ATTACK_RANGE)
	_state = ActionState.SELECTING_TARGET
	_ability_bar.show_targeting(skill)


func _on_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_RIGHT:
		cancel_targeting()
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

	# Face the caster toward the anchor before the swing — reads clearly and
	# also makes sense if the anchor is behind their current facing.
	caster.face_toward(anchor)
	caster.set_state(UnitEnums.UnitState.ACTING)

	var result := AbilityResolver.resolve(caster, skill, anchor, _grid, all_units, turn_number)

	if log_actions:
		_log_result(caster, skill, result)

	_spawn_effect_visuals(caster, skill, result)

	# Aggregate per-caster battle stats for the end-of-battle summary.
	_record_caster_stats(caster, skill, result)

	# Route each effect through FOIL for player-side casters.
	if caster.team == UnitEnums.Team.PLAYER:
		_record_foil_actions(caster, skill, result, turn_number)

	caster.set_state(UnitEnums.UnitState.IDLE)
	_state = ActionState.IDLE

	# Check for a killing-blow battle end before progressing the turn.
	# Without this, the win banner waits until the player presses SPACE.
	var outcome := _turn_manager.check_outcome()
	if outcome != TurnEnums.BattleOutcome.ONGOING:
		_turn_manager.end_battle(outcome)
		return

	# Defensive — if the turn rotated mid-resolve (shouldn't happen without
	# async work in the resolver, but we mirror MoveController's guard),
	# only declare if the active unit is still us.
	if _turn_manager.get_active_unit() == caster:
		_turn_manager.declare_acted()

	# After acting, re-show the move preview if the unit still hasn't moved.
	if caster.team == UnitEnums.Team.PLAYER \
	and not _turn_manager.has_moved() \
	and caster.is_alive() \
	and _turn_manager.get_active_unit() == caster:
		_move_controller.refresh_preview()
		# Re-open the ability bar only if the unit has unspent actions
		# AND is still alive. Acting again in one turn isn't allowed in
		# Alpha, so we leave the bar hidden once acted.


# =============================================================================
# AI ENTRY — called from main.gd for enemy turns
# =============================================================================

## Pick and execute a simple action for an enemy unit.
## Logic:
##   1. For each skill the unit can afford, find valid targets.
##   2. If any offensive skill has a target, attack highest-HP enemy tile.
##   3. Else if a support skill has a target, use it.
##   4. Else return false — caller should fall back to moving.
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
		var anchors: Array = Targeting.valid_anchors(_grid, unit, skill, all_units)
		for anchor in anchors:
			var score: int = _score_enemy_target(unit, skill, anchor, all_units)
			if score > best_score:
				best_score = score
				best = {"skill": skill, "anchor": anchor}
	return best


## Simple heuristic: offensive skills score higher on low-HP enemies
## (finish-the-kill preference). Healing scores low-HP allies. Buffs score
## something minimal so the AI sometimes uses them.
static func _score_enemy_target(
	unit: Unit,
	skill: SkillData,
	anchor: Vector2i,
	all_units: Array
) -> int:
	var target: Unit = _find_unit_at(all_units, anchor)
	if target == null:
		return -1

	if skill.is_offensive():
		if not UnitEnums.teams_are_hostile(unit.team, target.team):
			return -1
		# Prefer finishing enemies — low HP scores higher.
		var missing: int = target.stats.max_hp - target.stats.hp
		return 100 + missing
	if skill.skill_type == SkillEnums.SkillType.HEALING:
		if UnitEnums.teams_are_hostile(unit.team, target.team):
			return -1
		return 60 + (target.stats.max_hp - target.stats.hp)
	if skill.skill_type == SkillEnums.SkillType.BUFF:
		return 20
	return 5


static func _find_unit_at(all_units: Array, coord: Vector2i) -> Unit:
	for u in all_units:
		if u != null and u.coord == coord:
			return u
	return null


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
			if effect["side"] == 2:  # rear
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
		# Skill-level context for buff/debuff labels so the player sees what
		# landed. Not strictly necessary with the skill's own label, but a
		# future polish pass can add a small caster-side toast.
		var _ = skill  # reserved for future caster-side feedback


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
	# FOILTracker autoload is registered as "FOILTracker" in project.godot.
	if unit == null or unit.team != UnitEnums.Team.PLAYER:
		return
	var foil := _get_foil()
	if foil == null:
		return
	# begin_battle is idempotent per key in our v2 tracker — calling again
	# with the same name blows away the in-flight record. Guard by checking
	# if the unit already has an active record.
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

		var engagement: int = GridMap.manhattan(caster.coord, effect["target_coord"])

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
	# Autoloads live under the scene tree root as named nodes. No need to
	# check Engine.has_singleton — that's for C++ singletons.
	var root := get_tree().root
	return root.get_node_or_null("FOILTracker")


# =============================================================================
# HELPERS
# =============================================================================

func _clear_target_highlights() -> void:
	for coord in _valid_targets:
		var tile := _grid.get_tile(coord)
		if tile == null:
			continue
		if tile.highlight_state == GridEnums.HighlightState.ATTACK_RANGE:
			_grid.set_highlight(coord, GridEnums.HighlightState.NONE)
	_valid_targets.clear()


func _log_result(caster: Unit, skill: SkillData, result: Dictionary) -> void:
	var lines: Array = []
	lines.append("[action] %s casts %s (mp_paid=%s)" % [
		caster.unit_id, skill.skill_name, result["mp_paid"]
	])
	for effect in result["effects"]:
		var side_label := ["front", "flank", "REAR"][effect["side"]]
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
