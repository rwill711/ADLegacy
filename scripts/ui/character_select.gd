class_name CharacterSelect extends Control
## Phase 9 character select screen.
## Player picks 3 jobs (duplicates allowed) for their party before battle.
## Confirms when exactly 3 are chosen; Back returns to the main menu.


const PARTY_SIZE: int = 3

var _selected: Array = []  # Array[StringName] — job_names in pick order


@onready var _party_label: Label     = %PartyLabel
@onready var _confirm_btn: Button    = %ConfirmBtn
@onready var _back_btn: Button       = %BackBtn
@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _party_row: HBoxContainer = %PartyRow


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_confirm_btn.pressed.connect(_on_confirm)
	_confirm_btn.disabled = true

	for job in JobLibrary.all_alpha_jobs():
		_cards_row.add_child(_build_job_card(job))

	_refresh_party_display()


# =============================================================================
# INTERACTION
# =============================================================================

func _on_job_picked(job_name: StringName) -> void:
	if _selected.size() >= PARTY_SIZE:
		return
	_selected.append(job_name)
	_refresh_party_display()


func _on_party_slot_removed(index: int) -> void:
	if index < 0 or index >= _selected.size():
		return
	_selected.remove_at(index)
	_refresh_party_display()


func _on_confirm() -> void:
	SceneManager.set_player_jobs(_selected)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


# =============================================================================
# DISPLAY
# =============================================================================

func _refresh_party_display() -> void:
	_confirm_btn.disabled = _selected.size() != PARTY_SIZE
	_party_label.text = "Party  %d / %d" % [_selected.size(), PARTY_SIZE]

	for child in _party_row.get_children():
		child.queue_free()

	for i in PARTY_SIZE:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(120, 56)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		slot.add_child(margin)

		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		margin.add_child(lbl)

		if i < _selected.size():
			var job := JobLibrary.get_job(_selected[i])
			lbl.text = job.display_name if job != null else "?"
			lbl.modulate = job.job_color if job != null else Color.WHITE
			# Click to remove
			slot.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_LEFT:
					_on_party_slot_removed(i)
			)
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			lbl.text = "Empty"
			lbl.modulate = Color(1, 1, 1, 0.35)

		_party_row.add_child(slot)


# =============================================================================
# JOB CARDS
# =============================================================================

func _build_job_card(job: JobData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 260)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.theme_override_constants/separation = 6
	margin.add_child(box)

	# Job name
	var name_lbl := Label.new()
	name_lbl.text = job.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = job.job_color
	box.add_child(name_lbl)

	# Flavor
	var flavor := Label.new()
	flavor.text = job.description
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.add_theme_font_size_override("font_size", 11)
	flavor.modulate = Color(1, 1, 1, 0.7)
	flavor.custom_minimum_size = Vector2(176, 0)
	box.add_child(flavor)

	box.add_child(_divider())

	# Derived stats preview
	var stats: UnitStats = StatFormulas.derive(
		job.base_attributes, job.base_move_range, job.base_jump
	)
	var stat_lines: Array = [
		["HP",  str(stats.max_hp)],
		["MP",  str(stats.max_mp)],
		["ATK", str(stats.attack)],
		["DEF", str(stats.defense)],
		["MAG", str(stats.magic)],
		["RES", str(stats.resistance)],
		["SPD", str(stats.speed)],
		["MOV", str(stats.move_range)],
	]
	for pair in stat_lines:
		box.add_child(_stat_row(pair[0], pair[1]))

	box.add_child(_divider())

	# Skills preview
	var skill_names: Array = []
	for s in job.get_starting_skills():
		skill_names.append(s.display_name)
	var skills_lbl := Label.new()
	skills_lbl.text = "\n".join(skill_names)
	skills_lbl.add_theme_font_size_override("font_size", 11)
	skills_lbl.modulate = Color(1, 1, 1, 0.8)
	box.add_child(skills_lbl)

	# Pick button
	var btn := Button.new()
	btn.text = "Add to Party"
	btn.size_flags_vertical = Control.SIZE_SHRINK_END
	btn.pressed.connect(func(): _on_job_picked(job.job_name))
	box.add_child(btn)

	return card


func _stat_row(label: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(1, 1, 1, 0.6)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 12)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lbl)
	row.add_child(val)
	return row


func _divider() -> HSeparator:
	var sep := HSeparator.new()
	sep.modulate = Color(1, 1, 1, 0.2)
	return sep
