class_name AttackConfirmPanel extends CanvasLayer
## Pre-attack confirmation popup.
## Displays hit chance and estimated damage before the player commits.
## Pure widget — emits confirmed or cancelled; caller drives execution.

signal confirmed
signal cancelled

var _skill_label: Label
var _target_label: Label
var _hit_label: Label
var _dmg_label: Label


func _ready() -> void:
	layer = 10

	# CenterContainer fills the screen and centers the panel automatically.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_skill_label = Label.new()
	_skill_label.add_theme_font_size_override("font_size", 15)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_skill_label)

	vbox.add_child(HSeparator.new())

	_target_label = Label.new()
	vbox.add_child(_target_label)

	_hit_label = Label.new()
	vbox.add_child(_hit_label)

	_dmg_label = Label.new()
	vbox.add_child(_dmg_label)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(90, 32)
	cancel_btn.pressed.connect(func(): cancelled.emit())
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(90, 32)
	confirm_btn.pressed.connect(func(): confirmed.emit())
	btn_row.add_child(confirm_btn)

	visible = false


## Populate and display the panel for the given attack.
func show_confirm(skill: SkillData, target: Unit, caster: Unit) -> void:
	var side: int = UnitEnums.attack_side(caster.coord, target.coord, target.facing)
	var hit_chance: int = AbilityResolver.calc_hit_chance(skill, target, side)

	_skill_label.text = skill.display_name

	var target_str: String = "Target:      %s" % target.display_name
	if skill.is_area():
		target_str += "  (AoE)"
	_target_label.text = target_str

	_hit_label.text = "Hit chance:  %d%%" % hit_chance
	_dmg_label.text = _estimate_label(skill, caster, target, side)

	visible = true


func hide_confirm() -> void:
	visible = false


static func _estimate_label(skill: SkillData, caster: Unit, target: Unit, side: int) -> String:
	var is_physical: bool = skill.skill_type == SkillEnums.SkillType.PHYSICAL_DAMAGE
	var is_magic: bool    = skill.skill_type == SkillEnums.SkillType.MAGIC_DAMAGE
	if not (is_physical or is_magic):
		return ""

	var attack_stat: int  = caster.stats.attack  if is_physical else caster.stats.magic
	var defense_stat: int = target.stats.defense if is_physical else target.stats.resistance

	var facing_mod: float
	match side:
		0: facing_mod = AbilityResolver.FRONT_MOD
		1: facing_mod = AbilityResolver.FLANK_MOD
		2: facing_mod = AbilityResolver.REAR_MOD
		_: facing_mod = AbilityResolver.FLANK_MOD

	var base: float = float(attack_stat) * skill.power
	if side == 2 and skill.requires_rear_for_bonus:
		base *= skill.rear_bonus_multiplier

	var est_dmg: int = maxi(1, int(base * facing_mod) - defense_stat)
	return "Est. damage: ~%d" % est_dmg
