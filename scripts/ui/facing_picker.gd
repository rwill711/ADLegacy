class_name FacingPicker extends CanvasLayer
## Modal overlay that appears when the active unit enters CHOOSING_FACING.
## Four compass buttons (N/E/S/W) + ESC cancels back to AWAITING_ACTION.
##
## Per Creative Director: choosing facing before ending the turn is
## non-negotiable core tactics feel — this UI enforces it.


signal facing_chosen(facing: UnitEnums.Facing)
signal cancelled()


@onready var _root: Control = %Root
@onready var _unit_label: Label = %UnitLabel
@onready var _hint_label: Label = %HintLabel
@onready var _button_n: Button = %ButtonN
@onready var _button_e: Button = %ButtonE
@onready var _button_s: Button = %ButtonS
@onready var _button_w: Button = %ButtonW


var _turn_manager: TurnManager = null
var _current_unit: Unit = null


func _ready() -> void:
	_root.visible = false
	_button_n.pressed.connect(func(): _emit_and_close(UnitEnums.Facing.NORTH))
	_button_e.pressed.connect(func(): _emit_and_close(UnitEnums.Facing.EAST))
	_button_s.pressed.connect(func(): _emit_and_close(UnitEnums.Facing.SOUTH))
	_button_w.pressed.connect(func(): _emit_and_close(UnitEnums.Facing.WEST))


# =============================================================================
# BINDING
# =============================================================================

## Attach to a turn manager. The picker listens to phase_changed and shows
## itself when CHOOSING_FACING is entered for a player unit.
func bind_turn_manager(manager: TurnManager) -> void:
	if _turn_manager == manager:
		return
	if _turn_manager != null:
		_turn_manager.phase_changed.disconnect(_on_phase_changed)
	_turn_manager = manager
	if _turn_manager != null:
		_turn_manager.phase_changed.connect(_on_phase_changed)


# =============================================================================
# PHASE HANDLING
# =============================================================================

func _on_phase_changed(phase: int) -> void:
	if phase == TurnEnums.TurnPhase.CHOOSING_FACING:
		var unit := _turn_manager.get_active_unit()
		if unit != null and unit.team == UnitEnums.Team.PLAYER:
			_show(unit)
	else:
		# Any other phase → hide. Covers cancel, commit, battle end.
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
	_hint_label.text = "Pick a direction. ESC to cancel and keep acting."
	_highlight_current_facing(unit.facing)
	_root.visible = true


func _hide() -> void:
	_root.visible = false
	_current_unit = null


func _highlight_current_facing(facing: UnitEnums.Facing) -> void:
	# Dim all then brighten the current direction so the player sees where
	# they're already facing — common case of "keep this" becomes a single
	# click.
	for b in [_button_n, _button_e, _button_s, _button_w]:
		b.modulate = Color(1, 1, 1, 0.65)
	var current_button: Button = _button_for_facing(facing)
	if current_button != null:
		current_button.modulate = Color.WHITE


func _button_for_facing(facing: UnitEnums.Facing) -> Button:
	match facing:
		UnitEnums.Facing.NORTH: return _button_n
		UnitEnums.Facing.EAST:  return _button_e
		UnitEnums.Facing.SOUTH: return _button_s
		UnitEnums.Facing.WEST:  return _button_w
	return null


# =============================================================================
# CHOICE COMMIT
# =============================================================================

func _emit_and_close(facing: UnitEnums.Facing) -> void:
	if _current_unit == null:
		return
	_current_unit.set_facing(facing)
	facing_chosen.emit(facing)
	_hide()
	if _turn_manager != null:
		_turn_manager.confirm_end_turn()


func _cancel() -> void:
	cancelled.emit()
	_hide()
	if _turn_manager != null:
		_turn_manager.cancel_end_turn()
