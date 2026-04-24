class_name TurnManager extends Node
## FFTA-style CTR-countdown turn manager.
##
## Every tick, each alive unit's CT counter gains their SPEED stat. First unit
## to cross CT_ACTION_THRESHOLD gets the turn; ties break on higher SPD, then
## on spawn order. On turn end, CT is deducted based on what the unit did
## (Wait < Moved-only / Acted-only < Full turn).
##
## Not a Node3D — turn logic has no world position. Lives in the scene tree
## so signals and _process work, but renders nothing.
##
## Phase 3A scope: CT ticking, phase state machine, active-unit pointer, queue
## prediction. Movement/ability EXECUTION is stubbed — declare_moved() and
## declare_acted() just flip flags. Phase 3B and 3C plug in the real logic.


## --- Signals ----------------------------------------------------------------
signal battle_started(units: Array)
signal battle_ended(outcome: int)
signal turn_started(unit: Unit)
signal turn_ended(unit: Unit)
signal phase_changed(phase: int)
signal queue_updated(predicted_units: Array)  # next N turns, in order


## --- State ------------------------------------------------------------------
var _units: Array = []
var _ct_table: Dictionary = {}   # StringName unit_id → int

var _active_unit: Unit = null
var _phase: TurnEnums.TurnPhase = TurnEnums.TurnPhase.TICKING
var _outcome: TurnEnums.BattleOutcome = TurnEnums.BattleOutcome.ONGOING

## Turn-scoped flags that reset on TURN_START.
var _moved_this_turn: bool = false
var _acted_this_turn: bool = false

## Monotonic turn counter. Increments each time _advance_to_next_turn hands
## control to a new unit. Used by FOIL and the debug log to sequence events
## that share wall-clock time. Resets to 0 on begin_battle.
var _turn_number: int = 0


## --- Config -----------------------------------------------------------------
## How many upcoming turns to predict for the HUD queue display.
@export var queue_preview_count: int = 6


# =============================================================================
# BATTLE LIFECYCLE
# =============================================================================

## Kick off the battle with the given unit list. Initializes CT to 0 and
## immediately advances to the first turn.
func begin_battle(units: Array) -> void:
	_units = units.duplicate()
	_ct_table.clear()
	for unit in _units:
		_ct_table[unit.unit_id] = 0

	_outcome = TurnEnums.BattleOutcome.ONGOING
	_active_unit = null
	_moved_this_turn = false
	_acted_this_turn = false
	_turn_number = 0

	battle_started.emit(_units)
	_advance_to_next_turn()


## Ends the battle immediately with the given outcome. Debug commands call this
## directly; normally it's triggered by win/lose condition checks.
func end_battle(outcome: TurnEnums.BattleOutcome) -> void:
	_outcome = outcome
	_set_phase(TurnEnums.TurnPhase.BATTLE_OVER)
	_log("battle ended: outcome=%d (%d turns)" % [int(outcome), _turn_number])
	battle_ended.emit(outcome)


func _log(text: String) -> void:
	var mgr: Node = get_tree().root.get_node_or_null("DebugManager")
	if mgr != null:
		mgr.log(DebugEnums.CATEGORY_TURN, text)


# =============================================================================
# TURN ACTIONS (called by input / AI)
# =============================================================================

## Mark that the active unit has used their movement action this turn.
## Phase 3B will replace this with actual path execution.
func declare_moved() -> void:
	if _phase != TurnEnums.TurnPhase.AWAITING_ACTION:
		return
	_moved_this_turn = true
	if _acted_this_turn:
		end_turn()


## Mark that the active unit has used their action this turn.
## Phase 3C will replace this with ability resolution.
func declare_acted() -> void:
	if _phase != TurnEnums.TurnPhase.AWAITING_ACTION:
		return
	_acted_this_turn = true
	if _moved_this_turn:
		end_turn()


## End the current unit's turn. Transitions to CHOOSING_FACING and waits
## for confirm_end_turn() — the facing-picker UI drives that call. If the
## caller wants to bypass the picker (enemy AI, debug cheats, or test code),
## they can call end_turn_immediate() instead.
##
## Per Creative Director: facing-at-end-of-turn is non-negotiable for Alpha,
## so the default path is the picker flow.
func end_turn() -> void:
	if _phase == TurnEnums.TurnPhase.BATTLE_OVER:
		return
	if _active_unit == null:
		return
	_set_phase(TurnEnums.TurnPhase.CHOOSING_FACING)


## Skip remaining actions and transition to CHOOSING_FACING with Wait CT cost.
## Clears move/act flags so _ct_cost_for_turn returns CT_COST_WAIT.
func wait_and_end_turn() -> void:
	if _phase != TurnEnums.TurnPhase.AWAITING_ACTION:
		return
	_moved_this_turn = false
	_acted_this_turn = false
	_set_phase(TurnEnums.TurnPhase.CHOOSING_FACING)


## Confirm the facing pick and commit the turn end. Called by the facing
## picker UI after the player chooses a direction. Caller is responsible
## for calling active_unit.set_facing(f) before this.
func confirm_end_turn() -> void:
	if _phase != TurnEnums.TurnPhase.CHOOSING_FACING:
		return
	if _active_unit == null:
		return
	_commit_turn_end()


## Cancel a pending end-turn. Returns the unit to AWAITING_ACTION so they
## can still move/act. Useful for ESC on the facing picker — player changed
## their mind.
func cancel_end_turn() -> void:
	if _phase != TurnEnums.TurnPhase.CHOOSING_FACING:
		return
	_set_phase(TurnEnums.TurnPhase.AWAITING_ACTION)


## Immediately end the turn without a facing pick — facing stays wherever
## the caller set it. Used by enemy AI (which auto-faces before ending) and
## by debug / end-of-battle cleanup paths.
func end_turn_immediate() -> void:
	if _phase == TurnEnums.TurnPhase.BATTLE_OVER:
		return
	if _active_unit == null:
		return
	_commit_turn_end()


# Private: the actual CT-deduction + outcome-check + advance pipeline.
# All public end-turn paths funnel here.
func _commit_turn_end() -> void:
	_set_phase(TurnEnums.TurnPhase.TURN_ENDING)

	var cost: int = _ct_cost_for_turn()
	var new_ct: int = maxi(0, _ct_table.get(_active_unit.unit_id, 0) - cost)
	_ct_table[_active_unit.unit_id] = new_ct

	_log("turn end: %s (moved=%s, acted=%s, cost=%d, CT now %d)" % [
		_active_unit.unit_id, _moved_this_turn, _acted_this_turn, cost, new_ct
	])
	turn_ended.emit(_active_unit)

	var outcome := _evaluate_outcome()
	if outcome != TurnEnums.BattleOutcome.ONGOING:
		end_battle(outcome)
		return

	_advance_to_next_turn()


# =============================================================================
# QUERIES
# =============================================================================

func get_active_unit() -> Unit:
	return _active_unit


func get_phase() -> TurnEnums.TurnPhase:
	return _phase


func get_outcome() -> TurnEnums.BattleOutcome:
	return _outcome


func has_moved() -> bool:
	return _moved_this_turn


func has_acted() -> bool:
	return _acted_this_turn


## Current CT value for a given unit. Mostly for the HUD / debug overlay.
func get_ct(unit_id: StringName) -> int:
	return _ct_table.get(unit_id, 0)


## Monotonic turn number (1 = first turn of the battle).
func get_turn_number() -> int:
	return _turn_number


## Re-evaluate win/lose right now. The action controller calls this after
## damage lands so the battle can end on the killing blow rather than on
## the next end_turn().
func check_outcome() -> TurnEnums.BattleOutcome:
	return _evaluate_outcome()


## Predict the next N turns without mutating real state. Each returned Unit
## is the one whose CT would cross the threshold next in simulation.
func predict_turn_queue(count: int = -1) -> Array:
	if count < 0:
		count = queue_preview_count
	var alive: Array = _alive_units()
	if alive.is_empty():
		return []

	var sim_ct: Dictionary = _ct_table.duplicate()
	var result: Array = []
	var safety_ticks: int = 0
	var max_safety: int = 10000

	while result.size() < count and safety_ticks < max_safety:
		safety_ticks += 1
		# Tick once.
		for unit in alive:
			sim_ct[unit.unit_id] = mini(
				TurnEnums.CT_MAX,
				sim_ct[unit.unit_id] + unit.stats.speed
			)

		var winner: Unit = _select_next_turn_taker(alive, sim_ct)
		if winner == null:
			continue

		result.append(winner)
		# Assume full-turn cost for prediction; a lightweight heuristic since
		# we can't know ahead whether they'll Wait.
		sim_ct[winner.unit_id] = maxi(
			0,
			sim_ct[winner.unit_id] - TurnEnums.CT_COST_FULL_TURN
		)

	return result


# =============================================================================
# INTERNALS — ADVANCE / SELECTION
# =============================================================================

func _advance_to_next_turn() -> void:
	_set_phase(TurnEnums.TurnPhase.TICKING)
	_emit_queue_update()

	var next_unit: Unit = _tick_until_turn()
	if next_unit == null:
		# No one alive to act. Shouldn't happen if _evaluate_outcome is
		# called before advancing — treat as draw defensively.
		end_battle(TurnEnums.BattleOutcome.DRAW)
		return

	_active_unit = next_unit
	_moved_this_turn = false
	_acted_this_turn = false
	_turn_number += 1

	_set_phase(TurnEnums.TurnPhase.TURN_START)
	_log("turn %d start: %s (CT=%d, SPD=%d)" % [
		_turn_number, _active_unit.unit_id,
		_ct_table.get(_active_unit.unit_id, 0),
		_active_unit.stats.speed if _active_unit.stats != null else 0,
	])
	turn_started.emit(_active_unit)

	_set_phase(TurnEnums.TurnPhase.AWAITING_ACTION)
	_emit_queue_update()


## Advance CT tick-by-tick until at least one unit crosses threshold, then
## return the winner.
func _tick_until_turn() -> Unit:
	var alive: Array = _alive_units()
	if alive.is_empty():
		return null

	var safety: int = 0
	while safety < 10000:
		safety += 1
		for unit in alive:
			_ct_table[unit.unit_id] = mini(
				TurnEnums.CT_MAX,
				_ct_table[unit.unit_id] + unit.stats.speed
			)
		var winner := _select_next_turn_taker(alive, _ct_table)
		if winner != null:
			return winner
	push_error("TurnManager: tick loop ran past safety limit")
	return null


## Pick the unit with the highest CT above threshold. Ties go to higher SPD,
## then to spawn order (stable via the _units list).
static func _select_next_turn_taker(alive: Array, ct_source: Dictionary) -> Unit:
	var best: Unit = null
	var best_ct: int = TurnEnums.CT_ACTION_THRESHOLD - 1
	for unit in alive:
		var ct: int = ct_source.get(unit.unit_id, 0)
		if ct < TurnEnums.CT_ACTION_THRESHOLD:
			continue
		if best == null \
		or ct > best_ct \
		or (ct == best_ct and unit.stats.speed > best.stats.speed):
			best = unit
			best_ct = ct
	return best


# =============================================================================
# INTERNALS — COST / OUTCOME
# =============================================================================

func _ct_cost_for_turn() -> int:
	if _moved_this_turn and _acted_this_turn:
		return TurnEnums.CT_COST_FULL_TURN
	if _moved_this_turn:
		return TurnEnums.CT_COST_MOVED_ONLY
	if _acted_this_turn:
		return TurnEnums.CT_COST_ACTED_ONLY
	return TurnEnums.CT_COST_WAIT


func _alive_units() -> Array:
	var out: Array = []
	for unit in _units:
		if unit != null and unit.is_alive():
			out.append(unit)
	return out


## Check each team for at least one alive unit. Victory/defeat based on that.
func _evaluate_outcome() -> TurnEnums.BattleOutcome:
	var player_alive := false
	var enemy_alive := false
	for unit in _units:
		if unit == null or not unit.is_alive():
			continue
		if unit.team == UnitEnums.Team.PLAYER:
			player_alive = true
		elif unit.team == UnitEnums.Team.ENEMY:
			enemy_alive = true
	if player_alive and not enemy_alive:
		return TurnEnums.BattleOutcome.PLAYER_VICTORY
	if enemy_alive and not player_alive:
		return TurnEnums.BattleOutcome.PLAYER_DEFEAT
	if not player_alive and not enemy_alive:
		return TurnEnums.BattleOutcome.DRAW
	return TurnEnums.BattleOutcome.ONGOING


# =============================================================================
# INTERNALS — PHASE / QUEUE
# =============================================================================

func _set_phase(new_phase: TurnEnums.TurnPhase) -> void:
	if _phase == new_phase:
		return
	_phase = new_phase
	phase_changed.emit(new_phase)


func _emit_queue_update() -> void:
	queue_updated.emit(predict_turn_queue(queue_preview_count))
