class_name FOILDebugPanel extends ScrollContainer
## Debug overlay panel showing the FOIL state for the current encounter.
##
## Registers itself with DebugManager via the extensibility contract, so the
## DebugOverlay's TabContainer picks it up automatically. Other systems can
## copy this pattern without touching debug_overlay.gd.
##
## Displays:
##   - Current battle's FOIL level + source (renown / override / default)
##   - Primary character being countered
##   - Dominant archetype + top 3 archetype weights
##   - Behavioral stats (aggression, aoe_tendency, support_tendency, avg dist)
##   - Sample size + confidence
##   - Enemy loadout preview (jobs, consumables, ai_hints)
##   - Trait tags (if any)


const REFRESH_SECONDS: float = 0.5


var _list: VBoxContainer = null
var _refresh_timer: Timer = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.size_flags_vertical = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = REFRESH_SECONDS
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh)
	add_child(_refresh_timer)

	_refresh()


# =============================================================================
# RENDER
# =============================================================================

func _refresh() -> void:
	# Throttle away when the panel isn't actually on-screen (the overlay
	# hides its Root control, but our Timer keeps firing regardless).
	if not is_visible_in_tree():
		return

	for child in _list.get_children():
		child.queue_free()

	var mgr: Node = get_tree().root.get_node_or_null("DebugManager")
	if mgr == null:
		_add_line("(no DebugManager)")
		return
	if mgr.unit_spawner == null:
		_add_line("(waiting for bind_scene)")
		return

	# Rebuild the encounter preview using current FOIL state. Safe to run mid-
	# battle; it won't affect the live loadout (which was captured at setup).
	var player_names: Array = []
	for unit in mgr.unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER):
		player_names.append(unit.display_name)

	var encounter: Dictionary = FOILBattleSetup.build_encounter(
		player_names,
		UnitSpawner.default_base_enemy_pool(),
		3
	)

	_render_level_header(encounter)
	_add_separator()
	_render_primary_profile(encounter)
	_add_separator()
	_render_all_profiles(encounter)
	_add_separator()
	_render_loadout_preview(encounter)


func _render_level_header(encounter: Dictionary) -> void:
	var level: int = encounter["level"]
	var source: String = encounter["level_source"]
	_add_heading("FOIL Level %d (source: %s)" % [level, source])
	_add_line(_level_label(level))


func _render_primary_profile(encounter: Dictionary) -> void:
	var name_: String = encounter["primary_character"]
	var profile: FOILProfile = encounter["profile"]
	_add_heading("Primary target: %s" % (name_ if not name_.is_empty() else "—"))
	if profile == null:
		_add_line("(no profile)")
		return

	_add_line("Dominant: %s   confidence %.2f   battles %d   actions %d" % [
		_archetype_name(profile.dominant_archetype),
		profile.confidence,
		profile.battles_in_window,
		profile.total_actions_analyzed,
	])
	_add_line("aggression %.2f   aoe %.2f   support %.2f   avg dist %.2f" % [
		profile.aggression,
		profile.aoe_tendency,
		profile.support_tendency,
		profile.avg_engagement_distance,
	])

	_add_line("Top archetypes:")
	var pairs: Array = []
	for key in profile.archetype_weights:
		pairs.append({"a": key, "w": profile.archetype_weights[key]})
	pairs.sort_custom(func(a, b): return a["w"] > b["w"])
	for i in mini(3, pairs.size()):
		_add_line("  %-16s %.2f" % [
			_archetype_name(pairs[i]["a"]),
			pairs[i]["w"],
		])

	if not profile.trait_tags.is_empty():
		_add_line("Trait tags: %s" % [", ".join(profile.trait_tags)])


func _render_all_profiles(encounter: Dictionary) -> void:
	var profiles_by_name: Dictionary = encounter.get("profiles_by_name", {})
	if profiles_by_name.is_empty():
		_add_heading("Party profiles")
		_add_line("(no data yet — profiles build as players take actions)")
		return
	_add_heading("Party profiles")
	for name in profiles_by_name:
		var p: FOILProfile = profiles_by_name[name]
		_add_line("%-14s %-14s conf %.2f  (%d battles, %d actions)" % [
			name,
			_archetype_name(p.dominant_archetype),
			p.confidence,
			p.battles_in_window,
			p.total_actions_analyzed,
		])


func _render_loadout_preview(encounter: Dictionary) -> void:
	var loadout: Dictionary = encounter["loadout"]
	_add_heading("Enemy loadout preview")

	var enemies: Array = loadout.get("enemies", [])
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		var resolved_job: StringName = UnitSpawner._resolve_job_name(e)
		var role: String = String(e.get("role", "default"))
		var consumable: String = String(e.get("consumable", ""))
		var gear: String = String(e.get("gear_hint", ""))
		_add_line("  #%d  %s  role=%s  item=%s  gear=%s" % [
			i + 1,
			String(resolved_job),
			role,
			consumable if not consumable.is_empty() else "-",
			gear if not gear.is_empty() else "-",
		])

	var ai_hints: Dictionary = loadout.get("ai_hints", {})
	if ai_hints.is_empty():
		_add_line("AI hints: (none)")
	else:
		_add_line("AI hints:")
		for key in ai_hints:
			_add_line("  %s = %s" % [key, str(ai_hints[key])])

	var notes: Array = loadout.get("notes", [])
	if not notes.is_empty():
		_add_line("Notes:")
		for note in notes:
			_add_line("  • %s" % note)


# =============================================================================
# HELPERS
# =============================================================================

func _add_heading(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.75, 1.0, 0.7)
	_list.add_child(lbl)


func _add_line(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	_list.add_child(lbl)
	return lbl


func _add_separator() -> void:
	var sep := HSeparator.new()
	_list.add_child(sep)


static func _level_label(level: int) -> String:
	match level:
		0: return "OBLIVIOUS — random / default loadouts"
		1: return "AWARE — consumables mitigate dominant approach"
		2: return "PREPARED — half team swapped to counter jobs"
		3: return "STRATEGIC — AI adjusts targeting / positioning"
		4: return "MASTERY — hard-counter gear + full counter team"
	return "?"


static func _archetype_name(a: FOILEnums.Archetype) -> String:
	match a:
		FOILEnums.Archetype.MELEE_AGGRO:    return "MELEE_AGGRO"
		FOILEnums.Archetype.RANGED_KITE:    return "RANGED_KITE"
		FOILEnums.Archetype.MAGIC_OFFENSE:  return "MAGIC_OFFENSE"
		FOILEnums.Archetype.HEALER_SUPPORT: return "HEALER_SUPPORT"
		FOILEnums.Archetype.TANK_WALL:      return "TANK_WALL"
		FOILEnums.Archetype.AOE_BLASTER:    return "AOE_BLASTER"
		FOILEnums.Archetype.DEBUFFER:       return "DEBUFFER"
		FOILEnums.Archetype.HYBRID:         return "HYBRID"
	return "?"
