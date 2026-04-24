class_name MoveController extends Node
## Orchestrates the MOVE phase of a unit's turn.
##
## Flow (new):
##   Player clicks "Move" in ability bar → show_move_preview_for(unit)
##   tile_clicked on a reachable tile   → execute path, animate unit
##   move completes                     → clear highlights, update grid, emit move_completed
##   turn_ended                         → clear highlights defensively
##
## Undo move is supported while the unit has not yet acted (only_if_not_acted
## is enforced by the caller — ability bar won't show the button after acting).


signal move_completed
signal move_undone


## --- Config -----------------------------------------------------------------
@export var step_duration_seconds: float = 0.14
@export var face_toward_step: bool = true
@export var log_moves: bool = true


## --- Wired refs (set via bind() from main.gd) -------------------------------
var _grid: BattleGrid = null
var _visualizer: GridVisualizer = null
var _turn_manager: TurnManager = null


## --- State ------------------------------------------------------------------
var _active_unit: Unit = null
var _reachable: Dictionary = {}
var _preview_active: bool = false
var _executing: bool = false

## Stored before a move executes so undo_move() can teleport back.
var _pre_move_coord: Vector2i = Vector2i(-1, -1)


# =============================================================================
# WIRING
# =============================================================================

func bind(grid: BattleGrid, visualizer: GridVisualizer, turn_manager: TurnManager) -> void:
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
	_pre_move_coord = Vector2i(-1, -1)
	_clear_preview()
	# Move preview is no longer auto-shown at turn start.
	# The player picks "Move" from the ability bar first.


func _on_turn_ended(_unit: Unit) -> void:
	_clear_preview()
	_active_unit = null
	_pre_move_coord = Vector2i(-1, -1)


func _on_battle_ended(_outcome: int) -> void:
	_clear_preview()


# =============================================================================
# MOVE PREVIEW — public entry points
# =============================================================================

## Show the move preview for the active unit. Called when the player clicks
## the "Move" button in the ability bar.
func show_move_preview_for(unit: Unit) -> void:
	if unit == null or unit.team != UnitEnums.Team.PLAYER:
		return
	_active_unit = unit
	_clear_preview()
	_show_move_preview(unit)


## Re-show the move preview for the current active unit without a button press.
## Used after cancel-targeting to restore move option when unit hasn't moved.
func refresh_preview() -> void:
	if _executing:
		return
	if _turn_manager == null or _turn_manager.has_moved():
		return
	var active := _turn_manager.get_active_unit()
	if active == null or active.team != UnitEnums.Team.PLAYER or not active.is_alive():
		return
	_active_unit = active
	_clear_preview()
	_show_move_preview(active)


## Suppress the move preview without marking the unit as moved (used when
## the player cancels the move selection or enters targeting mode).
func hide_preview() -> void:
	_clear_preview()


func _show_move_preview(unit: Unit) -> void:
	_reachable = Pathfinder.reachable_tiles(_grid, unit)
	for coord in _reachable:
		_grid.set_highlight(coord, GridEnums.HighlightState.MOVE_RANGE)
	_preview_active = true


func _clear_preview() -> void:
	if not _preview_active:
		_reachable.clear()
		return
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
# PREVIEW QUERIES
# =============================================================================

func is_preview_tile(coord: Vector2i) -> bool:
	return _preview_active and _reachable.has(coord)


func is_previewing() -> bool:
	return _preview_active


func is_executing() -> bool:
	return _executing


# =============================================================================
# UNDO MOVE
# =============================================================================

## Teleport the unit back to where they were before their last move. Only
## valid while _pre_move_coord is set (i.e., the unit moved this turn).
## Caller must also call turn_manager.undeclare_moved().
func undo_move() -> void:
	if _pre_move_coord == Vector2i(-1, -1) or _active_unit == null:
		return
	var pre_tile: GridTile = _grid.get_tile(_pre_move_coord)
	if pre_tile == null:
		return

	_grid.clear_occupant(_active_unit.coord)
	_active_unit.coord = _pre_move_coord
	_active_unit.global_position = pre_tile.top_world_position()
	_grid.set_occupant(_pre_move_coord, _active_unit.unit_id)

	_pre_move_coord = Vector2i(-1, -1)

	if _turn_manager != null:
		_turn_manager.undeclare_moved()

	move_undone.emit()


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

	var path: Array = Pathfinder.find_path(_grid, _active_unit, coord)
	if path.size() < 2:
		return
	_execute_path(_active_unit, path)


## Public AI entry. Awaitable — caller can `await execute_move(unit, goal)`.
func execute_move(unit: Unit, goal: Vector2i) -> void:
	if _executing or unit == null:
		return
	var path: Array = Pathfinder.find_path(_grid, unit, goal)
	if path.size() < 2:
		return
	await _execute_path(unit, path)


# =============================================================================
# PATH EXECUTION
# =============================================================================

func _execute_path(unit: Unit, path: Array) -> void:
	_executing = true
	_pre_move_coord = unit.coord  # save for undo
	_clear_preview()
	unit.set_state(UnitEnums.UnitState.MOVING)

	_grid.clear_occupant(unit.coord)

	var move_msg: String = "%s: %s → %s (%d steps)" % [
		unit.unit_id, path[0], path[path.size() - 1], path.size() - 1
	]
	if log_moves:
		print("[move] " + move_msg)
	var debug_mgr: Node = get_tree().root.get_node_or_null("DebugManager")
	if debug_mgr != null:
		debug_mgr.log(DebugEnums.CATEGORY_MOVEMENT, move_msg)

	await _animate_along_path(unit, path)

	var final_coord: Vector2i = path[path.size() - 1]
	unit.coord = final_coord
	_grid.set_occupant(final_coord, unit.unit_id)

	unit.set_state(UnitEnums.UnitState.IDLE)
	_executing = false

	if _turn_manager != null and _turn_manager.get_active_unit() == unit:
		_turn_manager.declare_moved()
		move_completed.emit()


func _animate_along_path(unit: Unit, path: Array) -> void:
	for i in range(1, path.size()):
		var next_coord: Vector2i = path[i]
		var next_tile := _grid.get_tile(next_coord)
		if next_tile == null:
			continue

		if face_toward_step:
			unit.face_toward(next_coord)
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
