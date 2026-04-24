class_name FacingPicker extends CanvasLayer
## Modal overlay that appears when the active unit enters CHOOSING_FACING.
## Highlights only the 4 cardinal (N/S/E/W) neighbour tiles. Player clicks one
## to set facing. ESC cancels back to AWAITING_ACTION.


@onready var _root: Control = %Root
@onready var _unit_label: Label = %UnitLabel
@onready var _hint_label: Label = %HintLabel


var _turn_manager: TurnManager = null
var _visualizer: GridVisualizer = null
var _grid: BattleGrid = null
var _current_unit: Unit = null
var _listening: bool = false
var _cardinal_coords: Array = []


func _ready() -> void:
	_root.visible = false


# =============================================================================
# BINDING
# =============================================================================

func bind_turn_manager(manager: TurnManager) -> void:
	if _turn_manager == manager:
		return
	if _turn_manager != null:
		_turn_manager.phase_changed.disconnect(_on_phase_changed)
	_turn_manager = manager
	if _turn_manager != null:
		_turn_manager.phase_changed.connect(_on_phase_changed)


func bind_visualizer(visualizer: GridVisualizer) -> void:
	_visualizer = visualizer


func bind_grid(grid: BattleGrid) -> void:
	_grid = grid


# =============================================================================
# PHASE HANDLING
# =============================================================================

func _on_phase_changed(phase: int) -> void:
	if phase == TurnEnums.TurnPhase.CHOOSING_FACING:
		var unit := _turn_manager.get_active_unit()
		if unit != null and unit.team == UnitEnums.Team.PLAYER:
			_show(unit)
	else:
		_hide()


# =============================================================================
# INPUT (ESC cancels)
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("cancel_action") \
	or event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


# =============================================================================
# SHOW / HIDE
# =============================================================================

func _show(unit: Unit) -> void:
	_current_unit = unit
	_unit_label.text = "%s — Choose Facing" % unit.display_name
	_hint_label.text = "Click a cardinal tile (N/S/E/W) to face it. ESC to cancel."
	_root.visible = true
	_highlight_cardinals(unit.coord)
	if _visualizer != null and not _listening:
		_visualizer.tile_clicked.connect(_on_tile_clicked)
		_listening = true


func _hide() -> void:
	_root.visible = false
	_clear_cardinal_highlights()
	_current_unit = null
	_cardinal_coords.clear()
	if _visualizer != null and _listening:
		_visualizer.tile_clicked.disconnect(_on_tile_clicked)
		_listening = false


# =============================================================================
# CARDINAL HIGHLIGHT
# =============================================================================

func _highlight_cardinals(origin: Vector2i) -> void:
	_cardinal_coords.clear()
	if _grid == null:
		return
	var offsets: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for off in offsets:
		var c: Vector2i = origin + off
		if _grid.is_in_bounds(c):
			_cardinal_coords.append(c)
			_grid.set_highlight(c, GridEnums.HighlightState.HOVER)


func _clear_cardinal_highlights() -> void:
	if _grid == null:
		return
	for c in _cardinal_coords:
		_grid.set_highlight(c, GridEnums.HighlightState.NONE)


# =============================================================================
# TILE CLICK → FACING
# =============================================================================

func _on_tile_clicked(coord: Vector2i, _button_index: int) -> void:
	if _current_unit == null:
		return
	if not coord in _cardinal_coords:
		return
	_current_unit.face_toward(coord)
	_hide()
	if _turn_manager != null:
		_turn_manager.confirm_end_turn()


func _cancel() -> void:
	_hide()
	if _turn_manager != null:
		_turn_manager.cancel_end_turn()
