class_name MoveController extends Node
## Orchestrates the MOVE phase of a unit's turn.
##
## Flow:
##   turn_started (player unit, haven't moved) → show move-range highlights
##   tile_clicked on a reachable tile          → execute path, animate unit
##   move completes                            → clear highlights, update grid
##                                               occupancy, call turn_manager.declare_moved()
##   turn_ended                                → clear highlights defensively
##
## This Node does NOT touch the turn manager's phase directly. It only calls
## declare_moved() on completion; turn_manager stays in AWAITING_ACTION until
## the player explicitly ends the turn. That mirrors FFTA's flow where you
## move, then decide what to act on (or skip act entirely).


## --- Config -----------------------------------------------------------------
@export var step_duration_seconds: float = 0.14
@export var face_toward_step: bool = true  # rotate unit as it walks each step
@export var log_moves: bool = true


## --- Wired refs (set via bind() from main.gd) -------------------------------
var _grid: GridMap = null
var _visualizer: GridVisualizer = null
var _turn_manager: TurnManager = null


## --- State ------------------------------------------------------------------
var _active_unit: Unit = null
var _reachable: Dictionary = {}  # Vector2i → float cost (from pathfinder)
var _preview_active: bool = false
var _executing: bool = false


# =============================================================================
# WIRING
# =============================================================================

func bind(grid: GridMap, visualizer: GridVisualizer, turn_manager: TurnManager) -> void:
	_grid = grid
	_visualizer = visualizer
	_turn_manager = turn_manager

	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.turn_ended.connect(_on_turn_ended)
	_turn_manager.battle_ended.connect(_on_battle_ended)
	_visualizer.tile_clicked.connect(_on_tile_clicked)


# =============================================================================
# TURN SIGNAL HANDLERS
# =============================================================================

func _on_turn_started(unit: Unit) -> void:
	_active_unit = unit
	_clear_preview()

	# Only player units get the move preview UI. Enemies move via AI
	# (Phase 3C) — they'll call execute_path directly without highlighting.
	if unit == null or unit.team != UnitEnums.Team.PLAYER:
		return

	# If the unit has already moved this turn (shouldn't happen on fresh
	# turn_started, but defensive), don't re-show preview.
	if _turn_manager.has_moved():
		return

	_show_move_preview(unit)


func _on_turn_ended(_unit: Unit) -> void:
	_clear_preview()
	_active_unit = null


func _on_battle_ended(_outcome: int) -> void:
	_clear_preview()


# =============================================================================
# MOVE PREVIEW
# =============================================================================

func _show_move_preview(unit: Unit) -> void:
	_reachable = Pathfinder.reachable_tiles(_grid, unit)
	for coord in _reachable:
		_grid.set_highlight(coord, GridEnums.HighlightState.MOVE_RANGE)
	_preview_active = true


func _clear_preview() -> void:
	if not _preview_active:
		_reachable.clear()
		return
	# Only clear MOVE_RANGE / PATH highlights, not HOVER (main.gd owns that).
	for coord in _reachable:
		var tile := _grid.get_tile(coord)
		if tile == null:
			continue
		if tile.highlight_state == GridEnums.HighlightState.MOVE_RANGE \
		or tile.highlight_state == GridEnums.HighlightState.PATH:
			_grid.set_highlight(coord, GridEnums.HighlightState.NONE)
	_reachable.clear()
	_preview_active = false


# =============================================================================
# PREVIEW QUERIES (used by main.gd's hover logic)
# =============================================================================

## True if a preview is active AND the given coord is a valid move destination.
func is_preview_tile(coord: Vector2i) -> bool:
	return _preview_active and _reachable.has(coord)


func is_previewing() -> bool:
	return _preview_active


## True while a move tween is in progress. Used by input handlers to lock
## out end_turn / other actions mid-animation.
func is_executing() -> bool:
	return _executing


# =============================================================================
# CLICK → EXECUTE
# =============================================================================

func _on_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	if _executing or not _preview_active or _active_unit == null:
		return
	if not _reachable.has(coord):
		return

	# Player clicked a reachable tile — commit the move.
	var path: Array = Pathfinder.find_path(_grid, _active_unit, coord)
	if path.size() < 2:
		return
	_execute_path(_active_unit, path)


## Public entry for AI movement in Phase 3C. Skips the preview UI.
func execute_move(unit: Unit, goal: Vector2i) -> void:
	if _executing or unit == null:
		return
	var path: Array = Pathfinder.find_path(_grid, unit, goal)
	if path.size() < 2:
		return
	_execute_path(unit, path)


# =============================================================================
# PATH EXECUTION
# =============================================================================

func _execute_path(unit: Unit, path: Array) -> void:
	_executing = true
	_clear_preview()
	unit.set_state(UnitEnums.UnitState.MOVING)

	# Clear current occupancy at move start so reachable checks for other
	# units (not relevant mid-turn, but defensive) see the tile as free.
	_grid.clear_occupant(unit.coord)

	if log_moves:
		print("[move] %s: %s → %s (%d steps)" % [
			unit.unit_id, path[0], path[path.size() - 1], path.size() - 1
		])

	await _animate_along_path(unit, path)

	# Commit new occupancy at the destination.
	var final_coord: Vector2i = path[path.size() - 1]
	unit.coord = final_coord
	_grid.set_occupant(final_coord, unit.unit_id)

	unit.set_state(UnitEnums.UnitState.IDLE)

	_executing = false

	# Defensive: if the turn ended or rotated during the animation (shouldn't
	# be possible given main.gd's input lockout, but cheap to check), skip
	# the declare_moved — it would otherwise mis-credit the next unit's turn.
	if _turn_manager != null and _turn_manager.get_active_unit() == unit:
		_turn_manager.declare_moved()


func _animate_along_path(unit: Unit, path: Array) -> void:
	# path[0] is the start tile — unit is already there. Walk each next hop.
	for i in range(1, path.size()):
		var next_coord: Vector2i = path[i]
		var next_tile := _grid.get_tile(next_coord)
		if next_tile == null:
			continue

		if face_toward_step:
			unit.face_toward(next_coord)
		# Update the unit's logical coord as it arrives on each tile.
		# Useful if a future hook (traps, terrain-damage-per-tile) wants
		# per-step callbacks. Intermediate occupancy isn't updated — the grid
		# sees one clear→set transition.
		unit.coord = next_coord

		var t := create_tween()
		t.set_ease(Tween.EASE_IN_OUT)
		t.set_trans(Tween.TRANS_SINE)
		t.tween_property(
			unit, "global_position",
			next_tile.top_world_position(),
			step_duration_seconds,
		)
		await t.finished
