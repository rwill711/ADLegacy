class_name AbilityBar extends CanvasLayer
## Bottom-of-screen ability bar. Populated with one button per castable skill
## for whichever player unit currently has the turn. Hidden during enemy
## turns and between turns.
##
## Emits `skill_selected(skill)` when the player clicks a button. The action
## controller listens and enters target-selection mode. Does not know about
## targeting, resolution, or the grid — pure widget.


signal skill_selected(skill: SkillData)
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


## Show the bar populated for `unit`. Called when a player unit's ACT phase
## becomes available (turn start, or after a move if they haven't acted yet).
func show_for_unit(unit: Unit) -> void:
	_current_unit = unit
	_selected_skill = null
	_clear_buttons()

	if unit == null:
		_root.visible = false
		return

	_unit_label.text = "%s — Abilities" % unit.display_name
	_hint_label.text = "Click a skill to target. ESC / right-click cancels."

	for skill in unit.skills:
		_buttons_row.add_child(_build_button(skill, unit))

	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(8, 0)
	_buttons_row.add_child(sep)

	var wait_btn := Button.new()
	wait_btn.text = "Wait"
	wait_btn.custom_minimum_size = Vector2(110, 40)
	wait_btn.pressed.connect(func(): wait_pressed.emit())
	_buttons_row.add_child(wait_btn)

	_root.visible = true


func hide_bar() -> void:
	_root.visible = false
	_current_unit = null
	_selected_skill = null


## Swap to "selected" state after a skill was picked — show which skill is
## being targeted, reduce visual clutter.
func show_targeting(skill: SkillData) -> void:
	_selected_skill = skill
	_hint_label.text = "Targeting %s. Click a highlighted tile. ESC to cancel." % skill.display_name
	# Dim unselected buttons.
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
