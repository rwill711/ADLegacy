class_name BattleSummary extends CanvasLayer
## End-of-battle modal. Shows Victory / Defeat / Draw, a per-unit stat
## breakdown (damage dealt, damage taken, actions, kills, top skill),
## and Retry / Quit buttons.
##
## Pulls data from Unit instances directly — the ActionController already
## aggregates stats there via record_action_stats().

const _LootLibrary = preload("res://scripts/items/loot_library.gd")


signal retry_pressed()
signal quit_pressed()
signal continue_pressed()


@onready var _root: Control = %Root
@onready var _outcome_label: Label = %OutcomeLabel
@onready var _turns_label: Label = %TurnsLabel
@onready var _player_stats_box: VBoxContainer = %PlayerStatsBox
@onready var _enemy_stats_box: VBoxContainer = %EnemyStatsBox
@onready var _retry_button: Button = %RetryButton
@onready var _quit_button: Button = %QuitButton

var _round_label: Label = null    # injected lazily for endless mode
var _continue_button: Button = null  # injected lazily for endless mode


func _ready() -> void:
	_root.visible = false
	_retry_button.pressed.connect(func(): retry_pressed.emit())
	_quit_button.pressed.connect(func(): quit_pressed.emit())


## Populate and show the summary for a finished battle.
## `units` is every unit that participated (alive or dead).
## `rewards` is optional — shown only on victory.
## `endless_round` > 0 shows the round counter and a Next Battle button on victory.
func show_summary(
	outcome: TurnEnums.BattleOutcome,
	turn_count: int,
	units: Array,
	rewards: BattleRewards = null,
	endless_round: int = 0
) -> void:
	_outcome_label.text = _outcome_text(outcome)
	_outcome_label.modulate = _outcome_color(outcome)
	_turns_label.text = "Battle length: %d turns" % turn_count

	_clear_box(_player_stats_box)
	_clear_box(_enemy_stats_box)

	for unit in units:
		if unit == null:
			continue
		var row := _build_unit_row(unit)
		if unit.team == UnitEnums.Team.PLAYER:
			_player_stats_box.add_child(row)
		elif unit.team == UnitEnums.Team.ENEMY:
			_enemy_stats_box.add_child(row)

	_build_rewards_section(outcome, rewards)
	_update_endless_ui(outcome, endless_round)

	_root.visible = true


func hide_summary() -> void:
	_root.visible = false


# =============================================================================
# ROW BUILDING
# =============================================================================

func _build_unit_row(unit: Unit) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var header := Label.new()
	var alive_tag: String = "" if unit.is_alive() else "  †"
	header.text = "%s — %s%s  |  HP %d/%d" % [
		unit.display_name,
		unit.job.display_name if unit.job != null else "?",
		alive_tag,
		unit.stats.hp, unit.stats.max_hp,
	]
	header.modulate = UnitEnums.team_color(unit.team)
	header.add_theme_font_size_override("font_size", 16)
	vbox.add_child(header)

	var stats_line := Label.new()
	stats_line.text = "Dmg dealt %d  |  Dmg taken %d  |  Actions %d  |  Kills %d" % [
		unit.total_damage_dealt,
		unit.total_damage_taken,
		unit.actions_taken,
		unit.kills_scored,
	]
	stats_line.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stats_line)

	var top_skill_name: String = _top_skill_label(unit.skill_usage_counts)
	if top_skill_name != "":
		var skill_line := Label.new()
		skill_line.text = "Most used: " + top_skill_name
		skill_line.add_theme_font_size_override("font_size", 11)
		skill_line.modulate = Color(1, 1, 1, 0.7)
		vbox.add_child(skill_line)

	return panel


static func _top_skill_label(usage: Dictionary) -> String:
	var best_name: String = ""
	var best_count: int = 0
	for name in usage:
		var count: int = usage[name]
		if count > best_count:
			best_count = count
			best_name = String(name)
	if best_count == 0:
		return ""
	return "%s × %d" % [best_name, best_count]


# =============================================================================
# HELPERS
# =============================================================================

static func _outcome_text(outcome: TurnEnums.BattleOutcome) -> String:
	match outcome:
		TurnEnums.BattleOutcome.PLAYER_VICTORY: return "VICTORY"
		TurnEnums.BattleOutcome.PLAYER_DEFEAT:  return "DEFEAT"
		TurnEnums.BattleOutcome.DRAW:           return "DRAW"
	return "BATTLE OVER"


static func _outcome_color(outcome: TurnEnums.BattleOutcome) -> Color:
	match outcome:
		TurnEnums.BattleOutcome.PLAYER_VICTORY: return Color(0.7, 1.0, 0.7)
		TurnEnums.BattleOutcome.PLAYER_DEFEAT:  return Color(1.0, 0.55, 0.55)
		TurnEnums.BattleOutcome.DRAW:           return Color(1.0, 1.0, 0.75)
	return Color.WHITE


func _build_rewards_section(outcome: TurnEnums.BattleOutcome, rewards: BattleRewards) -> void:
	# Remove any previous rewards section.
	var existing := _root.find_child("RewardsSection", true, false)
	if existing != null:
		existing.queue_free()

	if outcome != TurnEnums.BattleOutcome.PLAYER_VICTORY:
		return
	if rewards == null or rewards.is_empty():
		return

	var section := VBoxContainer.new()
	section.name = "RewardsSection"
	section.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "— Loot —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 15)
	header.modulate = Color(1.0, 0.85, 0.4)
	section.add_child(header)

	var summary: Dictionary = rewards.get_summary()
	for tag in summary:
		var count: int = summary[tag]
		var lbl := Label.new()
		lbl.text = "  %s × %d" % [_LootLibrary.display_name(tag), count]
		lbl.add_theme_font_size_override("font_size", 13)
		section.add_child(lbl)

	# Insert above the buttons (last child).
	_root.add_child(section)
	_root.move_child(section, _root.get_child_count() - 2)


func _update_endless_ui(outcome: TurnEnums.BattleOutcome, endless_round: int) -> void:
	var victory: bool = outcome == TurnEnums.BattleOutcome.PLAYER_VICTORY

	# Round label — sits just below the turn count.
	if endless_round > 0:
		if _round_label == null:
			_round_label = Label.new()
			_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_round_label.add_theme_font_size_override("font_size", 16)
			_round_label.modulate = Color(0.75, 0.9, 1.0)
			var box: VBoxContainer = _turns_label.get_parent()
			box.add_child(_round_label)
			box.move_child(_round_label, _turns_label.get_index() + 1)
		_round_label.text = "Endless Run  ·  Round %d" % endless_round
		_round_label.visible = true
	elif _round_label != null:
		_round_label.visible = false

	# Next Battle button — prepended to the buttons row, visible on endless victory only.
	if _continue_button == null:
		_continue_button = Button.new()
		_continue_button.custom_minimum_size = Vector2(160, 44)
		_continue_button.add_theme_font_size_override("font_size", 18)
		_continue_button.text = "Next Battle →"
		_continue_button.pressed.connect(func(): continue_pressed.emit())
		var buttons_row: HBoxContainer = _retry_button.get_parent()
		buttons_row.add_child(_continue_button)
		buttons_row.move_child(_continue_button, 0)
	_continue_button.visible = endless_round > 0 and victory


func _clear_box(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()
