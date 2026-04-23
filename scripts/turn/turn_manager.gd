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

	battle_started.emit(_units)
	_advance_to_next_turn()


## Ends the battle immediately with the given outcome. Debug commands call this
## directly; normally it's triggered by win/lose condition checks.
func end_battle(outcome: TurnEnums.BattleOutcome) -> void:
	_outcome = outcome
	_set_phase(TurnEnums.TurnPhase.BATTLE_OVER)
	battle_ended.emit(outcome)


# =============================================================================
# TURN ACTIONS (called by input / AI)
# =============================================================================

## Mark that the active unit has used their movement action this turn.
## Phase 3B will replace this with actual path execution.
func declare_moved() -> void:
	if _phase != TurnEnums.TurnPhase.AWAITING_ACTION:
		return
	_moved_this_turn = true


## Mark that the active unit has used their action this turn.
## Phase 3C will replace this with ability resolution.
func declare_acted() -> void:
	if _phase != TurnEnums.TurnPhase.AWAITING_ACTION:
		return
	_acted_this_turn = true


## End the current unit's turn. If facing wasn't explicitly chosen, keeps
## the existing facing. Handles CT cost + outcome check + next-turn advance.
func end_turn() -> void:
	if _phase == TurnEnums.TurnPhase.BATTLE_OVER:
		return
	if _active_unit == null:
		return

	# Facing phase is a transient beat for Alpha — the turn UI will later
	# gate this on an actual facing pick. For now, just pass through.
	_set_phase(TurnEnums.TurnPhase.CHOOSING_FACING)
	_set_phase(TurnEnums.TurnPhase.TURN_ENDING)

	# Deduct CT based on what was done.
	var cost: int = _ct_cost_for_turn()
	var new_ct: int = maxi(0, _ct_table.get(_active_unit.unit_id, 0) - cost)
	_ct_table[_active_unit.unit_id] = new_ct

	turn_ended.emit(_active_unit)

	# Check win/lose before advancing to avoid giving a turn to a dead unit.
	var outcome := _evaluate_outcome()
	if outcome != TurnEnums.BattleOutcome.ONGOING:
		end_battle(outcome)
		return

	_advance_to_next_turn()


## Skip remaining actions and end the turn immediately. Costs less CT so
## "passing" isn't always worse than acting — tactical stall becomes viable.
## (Creative-approved: Wait is a first-class option on the roadmap.)
func wait_and_end_turn() -> void:
	if _phase != TurnEnums.TurnPhase.AWAITING_ACTION:
		return
	# Clear action flags so the CT cost is CT_COST_WAIT regardless of what
	# would have been selected mid-phase.
	_moved_this_turn = false
	_acted_this_turn = false
	end_turn()


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

	_set_phase(TurnEnums.TurnPhase.TURN_START)
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
