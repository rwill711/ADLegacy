class_name AbilityBar extends CanvasLayer
## Cascading vertical action menu (FFT-style).
##
## Main column: Move, Act, Wait, Status.
## Clicking Act opens a secondary column to the right with skills grouped:
##   - "Attack" (basic attack / staff bonk) always first
##   - Job skill header + remaining skills
##
## Pure widget — emits signals; knows nothing about game state.


signal skill_selected(skill: SkillData)
signal move_requested
signal undo_move_requested
signal wait_pressed
signal status_pressed(unit: Unit)


## Skill names treated as the basic attack — shown as "Attack" and placed first.
const ATTACK_SKILL_NAMES: Array = [&"basic_attack", &"staff_bonk"]

## Job → skill section header label shown in the Act submenu.
const JOB_SKILL_HEADERS: Dictionary = {
	&"rogue":      "Thief Skills",
	&"squire":     "Squire Skills",
	&"white_mage": "White Magic",
}


@onready var _root: Control      = %Root
@onready var _unit_label: Label  = %UnitLabel
@onready var _hint_label: Label  = %HintLabel
@onready var _main_list: VBoxContainer = %MainList
@onready var _sub_panel: PanelContainer = %SubPanel
@onready var _sub_list: VBoxContainer  = %SubList


var _current_unit: Unit = null
var _selected_skill: SkillData = null
var _act_btn: Button = null
var _sub_open: bool = false


# =============================================================================
# VISIBILITY
# =============================================================================

func _ready() -> void:
	if _root == null or _main_list == null or _sub_panel == null or _sub_list == null:
		push_error("AbilityBar: @onready nodes not found — check unique_name_in_owner on Root, MainList, SubPanel, SubList in ability_bar.tscn")
		return
	_root.visible = false


## Show the menu for `unit`. Same signature as before so ActionController works
## without changes.
##   can_move      — Move button is shown (unit hasn't moved yet)
##   can_undo_move — "Undo Move" appears below Move
##   can_act       — Act button is enabled
func show_for_unit(
	unit: Unit,
	can_move: bool = true,
	can_undo_move: bool = false,
	can_act: bool = true
) -> void:
	if _root == null or _main_list == null or _sub_panel == null or _sub_list == null:
		push_error("AbilityBar.show_for_unit: nodes not ready")
		return
	_current_unit = unit
	_selected_skill = null
	_close_sub()
	_clear_main()

	if unit == null:
		_root.visible = false
		return

	_unit_label.text = unit.display_name
	_hint_label.text = "Choose action.  Right-click to cancel."

	if can_move:
		_add_main_btn("Move", func(): _on_move_pressed())

	if can_undo_move:
		_add_main_btn("Undo Move", func(): undo_move_requested.emit())

	_act_btn = _add_main_btn("Act", func(): _on_act_pressed(unit, can_act))
	_act_btn.disabled = not can_act

	_add_main_btn("Wait", func(): wait_pressed.emit())
	_add_main_btn("Status", func(): _on_status_pressed())

	_root.visible = true


func hide_bar() -> void:
	if _root == null:
		return
	_root.visible = false
	_current_unit = null
	_selected_skill = null
	_close_sub()


func is_bar_visible() -> bool:
	return _root != null and _root.visible


## Called by ActionController after a skill is chosen to show targeting hint.
## Dims all sub-buttons except the active skill.
func show_targeting(skill: SkillData) -> void:
	if _hint_label == null or _sub_list == null:
		return
	_selected_skill = skill
	_hint_label.text = "Targeting %s.  Click highlighted tile.  Right-click to cancel." \
		% skill.display_name
	for btn in _sub_list.get_children():
		if not btn is Button:
			continue
		var b: Button = btn as Button
		if b.has_meta("skill_name") and b.get_meta("skill_name") == skill.skill_name:
			b.modulate = Color.WHITE
		else:
			b.modulate = Color(1, 1, 1, 0.35)


# =============================================================================
# MAIN COLUMN — BUTTON HANDLERS
# =============================================================================

func _on_move_pressed() -> void:
	_close_sub()
	move_requested.emit()


func _on_act_pressed(unit: Unit, can_act: bool) -> void:
	if not can_act:
		return
	if _sub_open:
		_close_sub()
	else:
		_open_act_submenu(unit)


func _on_status_pressed() -> void:
	status_pressed.emit(_current_unit)


# =============================================================================
# ACT SUBMENU
# =============================================================================

func _open_act_submenu(unit: Unit) -> void:
	_clear_sub()
	_sub_open = true
	_sub_panel.visible = true
	_hint_label.text = "Select a skill.  Right-click to go back."

	# Separate the attack skill from job-specific skills.
	var attack_skill: SkillData = null
	var job_skills: Array = []
	for skill in unit.skills:
		if ATTACK_SKILL_NAMES.has(skill.skill_name):
			attack_skill = skill
		else:
			job_skills.append(skill)

	if attack_skill != null:
		_add_sub_skill_btn(attack_skill, unit, "Attack")

	if not job_skills.is_empty():
		var job_name: StringName = unit.job.job_name if unit.job != null else &""
		_add_sub_header(JOB_SKILL_HEADERS.get(job_name, "Skills"))
		for skill in job_skills:
			_add_sub_skill_btn(skill, unit)


func _close_sub() -> void:
	_sub_open = false
	if _sub_panel != null:
		_sub_panel.visible = false
	_clear_sub()


# =============================================================================
# BUTTON CONSTRUCTION
# =============================================================================

func _add_main_btn(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(130, 38)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(callback)
	_main_list.add_child(btn)
	return btn


func _add_sub_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(1.0, 0.88, 0.45, 0.95)
	lbl.custom_minimum_size = Vector2(170, 0)
	_sub_list.add_child(lbl)


func _add_sub_skill_btn(skill: SkillData, unit: Unit, label_override: String = "") -> Button:
	var btn := Button.new()
	var affordable: bool = unit.stats.mp >= skill.mp_cost
	var label: String = label_override if label_override != "" else skill.display_name
	if skill.mp_cost > 0:
		label += "  MP %d" % skill.mp_cost
	btn.text = label
	btn.disabled = not affordable
	btn.custom_minimum_size = Vector2(170, 38)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = skill.description
	btn.set_meta("skill_name", skill.skill_name)
	btn.pressed.connect(func(): skill_selected.emit(skill))
	_sub_list.add_child(btn)
	return btn


func _clear_main() -> void:
	if _main_list == null:
		return
	for c in _main_list.get_children():
		c.queue_free()


func _clear_sub() -> void:
	if _sub_list == null:
		return
	for c in _sub_list.get_children():
		c.queue_free()
