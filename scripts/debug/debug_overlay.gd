class_name DebugOverlay extends CanvasLayer
## F1-toggled read-only inspector overlay. Three built-in tabs:
##   Units      — full stat block for every unit (HP, MP, stats, coord, CT, FOIL summary)
##   Turn Order — predicted next 10 turns + current CT table
##   Log        — persistent log buffer (colored by category), filterable
##
## Panels rebuild on a 0.3s timer while visible. The Log tab also listens
## to DebugManager.log_added for live updates.
##
## External systems can register additional tabs via
## DebugManager.register_panel(name, control) — the overlay picks them up
## on panel_registered and appends them.


const TOGGLE_KEYCODE: int = KEY_F1
const REFRESH_SECONDS: float = 0.3


@onready var _root: Control = %Root
@onready var _tabs: TabContainer = %Tabs
@onready var _units_list: VBoxContainer = %UnitsList
@onready var _turn_list: VBoxContainer = %TurnList
@onready var _log_list: RichTextLabel = %LogList
@onready var _log_filter: OptionButton = %LogFilter


var _manager: Node = null
var _refresh_timer: Timer = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_root.visible = false

	_register_toggle_action()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = REFRESH_SECONDS
	_refresh_timer.autostart = false
	_refresh_timer.timeout.connect(_refresh_all)
	add_child(_refresh_timer)

	_populate_log_filter()
	_log_filter.item_selected.connect(func(_i): _refresh_log())

	_manager = get_tree().root.get_node_or_null("DebugManager")
	if _manager != null:
		_manager.log_added.connect(_on_log_added)
		_manager.scene_bound.connect(_on_scene_bound)
		_manager.panel_registered.connect(_on_panel_registered)
		# Pick up any panels registered before we wired up.
		var panels: Dictionary = _manager.get_panels()
		for panel_name in panels.keys():
			var ctrl = panels[panel_name]
			if is_instance_valid(ctrl):
				_add_external_panel(panel_name, ctrl)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay_toggle"):
		_toggle()
		get_viewport().set_input_as_handled()


func _register_toggle_action() -> void:
	if not InputMap.has_action("debug_overlay_toggle"):
		InputMap.add_action("debug_overlay_toggle")
	for existing in InputMap.action_get_events("debug_overlay_toggle"):
		if existing is InputEventKey and (existing as InputEventKey).keycode == TOGGLE_KEYCODE:
			return
	var ev := InputEventKey.new()
	ev.keycode = TOGGLE_KEYCODE
	InputMap.action_add_event("debug_overlay_toggle", ev)


func _toggle() -> void:
	_root.visible = not _root.visible
	if _root.visible:
		_refresh_all()
		_refresh_timer.start()
	else:
		_refresh_timer.stop()


# =============================================================================
# REFRESH
# =============================================================================

func _refresh_all() -> void:
	_refresh_units()
	_refresh_turn_order()
	_refresh_log()


func _refresh_units() -> void:
	for child in _units_list.get_children():
		child.queue_free()
	if _manager == null or _manager.unit_spawner == null:
		_add_label(_units_list, "(no units bound)")
		return

	var foil: Node = get_tree().root.get_node_or_null("FOILTracker")

	for unit in _manager.unit_spawner.get_all_units():
		_add_unit_block(unit, foil)


func _add_unit_block(unit: Unit, foil: Node) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_units_list.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	var header := Label.new()
	var alive: String = "" if unit.is_alive() else "  †"
	header.text = "%s [%s] %s%s  @ %s  facing=%s" % [
		unit.unit_id,
		_team_tag(unit.team),
		unit.job.display_name if unit.job != null else "?",
		alive,
		unit.coord,
		_facing_tag(unit.facing),
	]
	header.modulate = UnitEnums.team_color(unit.team)
	header.add_theme_font_size_override("font_size", 14)
	box.add_child(header)

	var stats := Label.new()
	stats.text = "HP %d/%d  MP %d/%d  ATK %d  DEF %d  MAG %d  RES %d  SPD %d  MOVE %d  JUMP %d  CT %d" % [
		unit.stats.hp, unit.stats.max_hp,
		unit.stats.mp, unit.stats.max_mp,
		unit.stats.attack, unit.stats.defense,
		unit.stats.magic, unit.stats.resistance,
		unit.stats.speed, unit.stats.move_range, unit.stats.jump,
		_manager.turn_manager.get_ct(unit.unit_id) if _manager.turn_manager != null else 0,
	]
	stats.add_theme_font_size_override("font_size", 11)
	box.add_child(stats)

	# FOIL profile summary for player units (enemies don't track via FOIL).
	if foil != null and unit.team == UnitEnums.Team.PLAYER:
		var profile: FOILProfile = FOILAnalyzer.build_profile(foil, unit.display_name)
		if profile != null:
			var foil_label := Label.new()
			foil_label.text = "FOIL: %s  agg=%.2f  aoe=%.2f  sup=%.2f  dist=%.2f  (n=%d, conf=%.2f)" % [
				_archetype_short(profile.dominant_archetype),
				profile.aggression, profile.aoe_tendency,
				profile.support_tendency, profile.avg_engagement_distance,
				profile.battles_in_window, profile.confidence,
			]
			foil_label.add_theme_font_size_override("font_size", 10)
			foil_label.modulate = Color(0.7, 1.0, 0.55)
			box.add_child(foil_label)


func _refresh_turn_order() -> void:
	for child in _turn_list.get_children():
		child.queue_free()
	if _manager == null or _manager.turn_manager == null:
		_add_label(_turn_list, "(no turn manager)")
		return

	var mgr: TurnManager = _manager.turn_manager
	var active := mgr.get_active_unit()
	var header := Label.new()
	header.text = "Turn %d  |  Active: %s  |  Phase: %s" % [
		mgr.get_turn_number(),
		active.display_name if active != null else "—",
		_phase_tag(mgr.get_phase()),
	]
	header.add_theme_font_size_override("font_size", 14)
	_turn_list.add_child(header)

	# Current CT table.
	_add_label(_turn_list, "— Current CT —")
	for unit in _manager.unit_spawner.get_all_units():
		var ct: int = mgr.get_ct(unit.unit_id)
		var line := "  %s: %d %s" % [
			unit.unit_id, ct,
			"(dead)" if not unit.is_alive() else "",
		]
		var lbl := _add_label(_turn_list, line)
		lbl.modulate = UnitEnums.team_color(unit.team)

	# Predicted queue.
	_add_label(_turn_list, "— Predicted next turns —")
	var queue: Array = mgr.predict_turn_queue(10)
	for i in queue.size():
		var u: Unit = queue[i]
		var lbl := _add_label(_turn_list, "  %d. %s (SPD %d)" % [i + 1, u.display_name, u.stats.speed])
		lbl.modulate = UnitEnums.team_color(u.team)


func _refresh_log() -> void:
	_log_list.clear()
	if _manager == null:
		return
	var filter: String = _log_filter.get_item_text(_log_filter.selected)
	if filter == "(all)":
		filter = ""
	var entries: Array = _manager.get_log(filter)
	var start: int = maxi(0, entries.size() - 200)
	for i in range(start, entries.size()):
		_append_log(entries[i])


func _on_log_added(entry: Dictionary) -> void:
	if not _root.visible:
		return
	var filter: String = _log_filter.get_item_text(_log_filter.selected)
	if filter != "(all)" and entry["category"] != filter:
		return
	_append_log(entry)


func _append_log(entry: Dictionary) -> void:
	var color: Color = DebugEnums.category_color(entry["category"])
	_log_list.push_color(color)
	_log_list.append_text("[%s] %s\n" % [entry["category"], entry["text"]])
	_log_list.pop()


func _on_scene_bound() -> void:
	if _root.visible:
		_refresh_all()


func _on_panel_registered(panel_name: String) -> void:
	var panel_ctrl: Control = _manager.get_panels().get(panel_name)
	_add_external_panel(panel_name, panel_ctrl)


func _add_external_panel(panel_name: String, control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	# If the control is already parented (e.g., re-register during a live
	# overlay session), don't try to reparent. Skip silently.
	if control.get_parent() != null:
		return
	# Don't double-add — TabContainer children are keyed by node name.
	for child in _tabs.get_children():
		if child.name == panel_name:
			return
	control.name = panel_name
	_tabs.add_child(control)


# =============================================================================
# HELPERS
# =============================================================================

func _populate_log_filter() -> void:
	_log_filter.clear()
	_log_filter.add_item("(all)")
	_log_filter.add_item(DebugEnums.CATEGORY_SYSTEM)
	_log_filter.add_item(DebugEnums.CATEGORY_COMBAT)
	_log_filter.add_item(DebugEnums.CATEGORY_MOVEMENT)
	_log_filter.add_item(DebugEnums.CATEGORY_TURN)
	_log_filter.add_item(DebugEnums.CATEGORY_FOIL)
	_log_filter.add_item(DebugEnums.CATEGORY_AI)
	_log_filter.add_item(DebugEnums.CATEGORY_CONSOLE)


static func _add_label(parent: Node, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)
	return lbl


static func _team_tag(team: UnitEnums.Team) -> String:
	match team:
		UnitEnums.Team.PLAYER:  return "PLY"
		UnitEnums.Team.ENEMY:   return "ENM"
		UnitEnums.Team.NEUTRAL: return "NTL"
	return "?"


static func _facing_tag(f: UnitEnums.Facing) -> String:
	match f:
		UnitEnums.Facing.NORTH: return "N"
		UnitEnums.Facing.EAST:  return "E"
		UnitEnums.Facing.SOUTH: return "S"
		UnitEnums.Facing.WEST:  return "W"
	return "?"


static func _phase_tag(phase: TurnEnums.TurnPhase) -> String:
	match phase:
		TurnEnums.TurnPhase.TICKING:         return "TICKING"
		TurnEnums.TurnPhase.TURN_START:      return "TURN_START"
		TurnEnums.TurnPhase.AWAITING_ACTION: return "AWAITING_ACTION"
		TurnEnums.TurnPhase.CHOOSING_FACING: return "CHOOSING_FACING"
		TurnEnums.TurnPhase.TURN_ENDING:     return "TURN_ENDING"
		TurnEnums.TurnPhase.BATTLE_OVER:     return "BATTLE_OVER"
	return "?"


static func _archetype_short(a: FOILEnums.Archetype) -> String:
	match a:
		FOILEnums.Archetype.MELEE_AGGRO:    return "MELEE"
		FOILEnums.Archetype.RANGED_KITE:    return "RANGED"
		FOILEnums.Archetype.MAGIC_OFFENSE:  return "MAGE"
		FOILEnums.Archetype.HEALER_SUPPORT: return "SUPPORT"
		FOILEnums.Archetype.TANK_WALL:      return "TANK"
		FOILEnums.Archetype.AOE_BLASTER:    return "AOE"
		FOILEnums.Archetype.DEBUFFER:       return "DEBUFF"
		FOILEnums.Archetype.HYBRID:         return "HYBRID"
	return "?"
