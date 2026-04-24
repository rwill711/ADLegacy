class_name AbilityBar extends CanvasLayer
## Bottom-of-screen ability bar. Populated per player turn with Move, skill
## buttons, and optionally Undo Move / Wait. Hidden during enemy turns.
##
## Pure widget — emits signals for all actions, knows nothing about game state.


signal skill_selected(skill: SkillData)
signal move_requested
signal undo_move_requested
signal wait_pressed


@onready var _buttons_row: HBoxContainer = %ButtonsRow
@onready var _unit_label: Label = %UnitLabel
@onready var _hint_label: Label = %HintLabel
@onready var _root: Control = %Root


var _current_unit: Unit = null
var _selected_skill: SkillData = null


# =============================================================================
# VISIBILITY
# =============================================================================

func _ready() -> void:
	_root.visible = false


## Show the bar for `unit`. Flags control which action buttons are present:
##   can_move      — show the Move button (unit hasn't moved yet)
##   can_undo_move — show Undo Move (unit moved but hasn't acted yet)
##   can_act       — show skill buttons (unit hasn't used their action yet)
func show_for_unit(
	unit: Unit,
	can_move: bool = true,
	can_undo_move: bool = false,
	can_act: bool = true
) -> void:
	_current_unit = unit
	_selected_skill = null
	_clear_buttons()

	if unit == null:
		_root.visible = false
		return

	_unit_label.text = "%s — Choose Action" % unit.display_name
	_hint_label.text = "Select Move or a skill. Right-click to go back."

	if can_move:
		var move_btn := Button.new()
		move_btn.text = "Move"
		move_btn.custom_minimum_size = Vector2(110, 40)
		move_btn.set_meta("skill_name", &"__move__")
		move_btn.pressed.connect(func(): move_requested.emit())
		_buttons_row.add_child(move_btn)

	if can_act:
		if can_move:
			var sep := VSeparator.new()
			sep.custom_minimum_size = Vector2(8, 0)
			_buttons_row.add_child(sep)

		for skill in unit.skills:
			_buttons_row.add_child(_build_button(skill, unit))

	var sep2 := VSeparator.new()
	sep2.custom_minimum_size = Vector2(8, 0)
	_buttons_row.add_child(sep2)

	if can_undo_move:
		var undo_btn := Button.new()
		undo_btn.text = "Undo Move"
		undo_btn.custom_minimum_size = Vector2(110, 40)
		undo_btn.set_meta("skill_name", &"__undo__")
		undo_btn.pressed.connect(func(): undo_move_requested.emit())
		_buttons_row.add_child(undo_btn)

	var wait_btn := Button.new()
	wait_btn.text = "Wait"
	wait_btn.custom_minimum_size = Vector2(110, 40)
	wait_btn.set_meta("skill_name", &"__wait__")
	wait_btn.pressed.connect(func(): wait_pressed.emit())
	_buttons_row.add_child(wait_btn)

	_root.visible = true


func hide_bar() -> void:
	_root.visible = false
	_current_unit = null
	_selected_skill = null


## Swap to "selected" state after a skill was picked.
func show_targeting(skill: SkillData) -> void:
	_selected_skill = skill
	_hint_label.text = "Targeting %s. Click a highlighted tile. Right-click to cancel." % skill.display_name
	for button in _buttons_row.get_children():
		if not button is Button:
			continue
		var b: Button = button
		if b.get_meta("skill_name") == skill.skill_name:
			b.modulate = Color.WHITE
		else:
			b.modulate = Color(1, 1, 1, 0.35)


# =============================================================================
# BUTTON CONSTRUCTION
# =============================================================================

func _build_button(skill: SkillData, unit: Unit) -> Button:
	var button := Button.new()
	var affordable: bool = unit.stats.mp >= skill.mp_cost

	var mp_suffix := ""
	if skill.mp_cost > 0:
		mp_suffix = "  MP %d" % skill.mp_cost

	button.text = "%s%s" % [skill.display_name, mp_suffix]
	button.disabled = not affordable
	button.custom_minimum_size = Vector2(140, 40)
	button.tooltip_text = skill.description
	button.set_meta("skill_name", skill.skill_name)
	button.pressed.connect(func(): _on_button_pressed(skill))
	return button


func _on_button_pressed(skill: SkillData) -> void:
	skill_selected.emit(skill)


func _clear_buttons() -> void:
	for child in _buttons_row.get_children():
		child.queue_free()
