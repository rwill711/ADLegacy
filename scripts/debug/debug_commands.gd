class_name DebugCommands
## Built-in console commands for the Alpha debug system.
## Registers the full Alpha command set with DebugManager.
##
## Each command returns a String. Console renders the return value; empty
## strings are treated as silent success.
##
## Adding a new command: wire it inside register_all(). The signature is
## always `func(args: PackedStringArray) -> String` so the console can
## execute uniformly.


## Entry point — main.gd.bind_scene invokes this once.
static func register_all(mgr) -> void:
	mgr.register_command("help",          _cmd_help.bind(mgr),          "list all commands")
	mgr.register_command("?",             _cmd_help.bind(mgr),          "alias for 'help'")
	mgr.register_command("clear",         _cmd_clear_log.bind(mgr),     "clear the debug log")
	mgr.register_command("log_export",    _cmd_log_export.bind(mgr),    "save debug log to user://debug_log_<ts>.txt")

	# Unit manipulation
	mgr.register_command("heal",          _cmd_heal.bind(mgr),          "heal <unit> <amount>")
	mgr.register_command("damage",        _cmd_damage.bind(mgr),        "damage <unit> <amount>")
	mgr.register_command("kill",          _cmd_kill.bind(mgr),          "kill <unit>")
	mgr.register_command("set_hp",        _cmd_set_hp.bind(mgr),        "set_hp <unit> <value>")
	mgr.register_command("move",          _cmd_move.bind(mgr),          "move <unit> <x> <y>")

	# Battle flow
	mgr.register_command("win",           _cmd_win.bind(mgr),           "force victory")
	mgr.register_command("lose",          _cmd_lose.bind(mgr),          "force defeat")
	mgr.register_command("next_turn",     _cmd_next_turn.bind(mgr),     "skip the current unit's turn")

	# FOIL
	mgr.register_command("foil_profile",  _cmd_foil_profile.bind(mgr),  "foil_profile [character] — dump FOIL profile")
	mgr.register_command("foil_level",    _cmd_foil_level.bind(mgr),    "foil_level <0-4> — set override for next battle")

	# Read-only inspectors
	mgr.register_command("list_units",    _cmd_list_units.bind(mgr),    "list all units with HP/coord/team")
	mgr.register_command("list_tiles",    _cmd_list_tiles.bind(mgr),    "list tiles with special properties")


# =============================================================================
# META
# =============================================================================

static func _cmd_help(mgr, _args: PackedStringArray) -> String:
	var lines: Array = ["Available commands:"]
	for name in mgr.get_commands_sorted():
		var desc: String = mgr.get_command_description(name)
		lines.append("  %s — %s" % [name, desc])
	return "\n".join(lines)


static func _cmd_clear_log(mgr, _args: PackedStringArray) -> String:
	mgr.clear_log()
	return "log cleared"


static func _cmd_log_export(mgr, _args: PackedStringArray) -> String:
	var path: String = mgr.export_log()
	if path.is_empty():
		return "export failed"
	return "log exported to %s" % path


# =============================================================================
# UNIT MANIPULATION
# =============================================================================

static func _cmd_heal(mgr, args: PackedStringArray) -> String:
	if args.size() < 2:
		return "usage: heal <unit> <amount>"
	var unit := _find_unit(mgr, args[0])
	if unit == null:
		return "no unit matching '%s'" % args[0]
	var amount: int = int(args[1])
	var gained: int = unit.heal(amount)
	mgr.log(DebugEnums.CATEGORY_CONSOLE, "heal %s +%d" % [unit.unit_id, gained])
	return "healed %s for %d HP (hp=%d/%d)" % [unit.unit_id, gained, unit.stats.hp, unit.stats.max_hp]


static func _cmd_damage(mgr, args: PackedStringArray) -> String:
	if args.size() < 2:
		return "usage: damage <unit> <amount>"
	var unit := _find_unit(mgr, args[0])
	if unit == null:
		return "no unit matching '%s'" % args[0]
	var amount: int = int(args[1])
	var lost: int = unit.take_damage(amount)
	mgr.log(DebugEnums.CATEGORY_CONSOLE, "damage %s -%d" % [unit.unit_id, lost])
	_maybe_end_battle_on_lethal_debug(mgr)
	return "damaged %s for %d HP (hp=%d/%d)" % [unit.unit_id, lost, unit.stats.hp, unit.stats.max_hp]


static func _cmd_kill(mgr, args: PackedStringArray) -> String:
	if args.size() < 1:
		return "usage: kill <unit>"
	var unit := _find_unit(mgr, args[0])
	if unit == null:
		return "no unit matching '%s'" % args[0]
	var lost: int = unit.take_damage(unit.stats.hp if unit.stats != null else 9999)
	mgr.log(DebugEnums.CATEGORY_CONSOLE, "kill %s" % unit.unit_id)
	_maybe_end_battle_on_lethal_debug(mgr)
	return "killed %s (%d damage dealt)" % [unit.unit_id, lost]


static func _cmd_set_hp(mgr, args: PackedStringArray) -> String:
	if args.size() < 2:
		return "usage: set_hp <unit> <value>"
	var unit := _find_unit(mgr, args[0])
	if unit == null:
		return "no unit matching '%s'" % args[0]
	var value: int = clampi(int(args[1]), 0, unit.stats.max_hp)
	unit.stats.hp = value
	unit.hp_changed.emit(unit.stats.hp, unit.stats.max_hp)
	if value == 0:
		unit.set_state(UnitEnums.UnitState.DEFEATED)
		unit.defeated.emit()
		_maybe_end_battle_on_lethal_debug(mgr)
	return "set %s hp=%d" % [unit.unit_id, value]


static func _cmd_move(mgr, args: PackedStringArray) -> String:
	if args.size() < 3:
		return "usage: move <unit> <x> <y>"
	if mgr.grid == null:
		return "no active grid"
	var unit := _find_unit(mgr, args[0])
	if unit == null:
		return "no unit matching '%s'" % args[0]
	var coord := Vector2i(int(args[1]), int(args[2]))
	var tile := mgr.grid.get_tile(coord)
	if tile == null:
		return "coord %s out of bounds" % [coord]
	mgr.grid.clear_occupant(unit.coord)
	unit.place_on_tile(tile, true)
	mgr.grid.set_occupant(coord, unit.unit_id)
	return "teleported %s to %s" % [unit.unit_id, coord]


# =============================================================================
# BATTLE FLOW
# =============================================================================

static func _cmd_win(mgr, _args: PackedStringArray) -> String:
	if mgr.turn_manager == null:
		return "no active battle"
	mgr.turn_manager.end_battle(TurnEnums.BattleOutcome.PLAYER_VICTORY)
	return "forced VICTORY"


static func _cmd_lose(mgr, _args: PackedStringArray) -> String:
	if mgr.turn_manager == null:
		return "no active battle"
	mgr.turn_manager.end_battle(TurnEnums.BattleOutcome.PLAYER_DEFEAT)
	return "forced DEFEAT"


static func _cmd_next_turn(mgr, _args: PackedStringArray) -> String:
	if mgr.turn_manager == null:
		return "no active battle"
	var active := mgr.turn_manager.get_active_unit()
	if active == null:
		return "no active unit"
	mgr.turn_manager.end_turn_immediate()
	return "skipped %s's turn" % active.unit_id


# =============================================================================
# FOIL
# =============================================================================

static func _cmd_foil_profile(mgr, args: PackedStringArray) -> String:
	var foil: Node = mgr.get_tree().root.get_node_or_null("FOILTracker")
	if foil == null:
		return "FOILTracker autoload not found"

	# If no character specified, dump whichever player unit is active, falling
	# back to the first player unit.
	var character_name: String = ""
	if args.size() >= 1:
		character_name = args[0]
	else:
		var active: Unit = mgr.turn_manager.get_active_unit() if mgr.turn_manager != null else null
		if active != null and active.team == UnitEnums.Team.PLAYER:
			character_name = active.display_name
		elif mgr.unit_spawner != null:
			var players: Array = mgr.unit_spawner.get_units_on_team(UnitEnums.Team.PLAYER)
			if not players.is_empty():
				character_name = players[0].display_name

	if character_name.is_empty():
		return "no character to profile"

	var profile: FOILProfile = FOILAnalyzer.build_profile(foil, character_name)
	if profile == null:
		return "no profile for '%s'" % character_name

	return "FOIL profile for %s:\n  battles=%d  actions=%d  confidence=%.2f\n  dominant=%s\n  aggression=%.2f  aoe=%.2f  support=%.2f  avg_dist=%.2f" % [
		character_name,
		profile.battles_in_window,
		profile.total_actions_analyzed,
		profile.confidence,
		_archetype_name(profile.dominant_archetype),
		profile.aggression,
		profile.aoe_tendency,
		profile.support_tendency,
		profile.avg_engagement_distance,
	]


static func _cmd_foil_level(mgr, args: PackedStringArray) -> String:
	if args.size() < 1:
		return "usage: foil_level <0-4>"
	var level: int = clampi(int(args[0]), 0, 4)
	# Phase 6 will consume this. For now, store on the DebugManager so the
	# battle-setup code can read it before Phase 6 lands.
	mgr.set_meta("foil_level_override", level)
	return "FOIL level override set to %d (takes effect next battle)" % level


# =============================================================================
# INSPECTORS
# =============================================================================

static func _cmd_list_units(mgr, _args: PackedStringArray) -> String:
	if mgr.unit_spawner == null:
		return "no spawner bound"
	var lines: Array = ["unit_id                team    hp        coord   ct"]
	for unit in mgr.unit_spawner.get_all_units():
		var ct: int = mgr.turn_manager.get_ct(unit.unit_id) if mgr.turn_manager != null else 0
		var team_tag: String = _team_tag(unit.team)
		lines.append("%-22s %-7s %3d/%-3d   %s   %d" % [
			unit.unit_id, team_tag,
			unit.stats.hp, unit.stats.max_hp,
			unit.coord, ct,
		])
	return "\n".join(lines)


static func _cmd_list_tiles(mgr, _args: PackedStringArray) -> String:
	if mgr.grid == null:
		return "no grid bound"
	var lines: Array = ["Tiles with non-default properties:"]
	for row in mgr.grid.tiles:
		for tile in row:
			var is_interesting: bool = tile.height != 0 \
				or tile.terrain != GridEnums.TerrainType.GRASS \
				or tile.occupant_id != &""
			if is_interesting:
				lines.append("  %s  terrain=%d  height=%d  occ=%s" % [
					tile.coord, int(tile.terrain), tile.height,
					tile.occupant_id if tile.occupant_id != &"" else "-",
				])
	return "\n".join(lines)


# =============================================================================
# HELPERS
# =============================================================================

## Find a unit by unit_id (exact) OR display_name (case-insensitive substring).
## Tries exact id first for precision, falls back to fuzzy so 'rogue' finds
## 'player_rogue' / 'Rogue'.
static func _find_unit(mgr, token: String) -> Unit:
	if mgr.unit_spawner == null:
		return null
	var needle: String = token.to_lower()

	# Exact unit_id match first.
	for unit in mgr.unit_spawner.get_all_units():
		if String(unit.unit_id) == token:
			return unit

	# Case-insensitive substring on id or display name.
	for unit in mgr.unit_spawner.get_all_units():
		if String(unit.unit_id).to_lower().contains(needle):
			return unit
		if unit.display_name.to_lower().contains(needle):
			return unit
	return null


## When a debug-dealt lethal blow empties a team, fire the battle-end check
## so the summary modal appears. Normal gameplay does this in ActionController;
## console damage bypasses it.
static func _maybe_end_battle_on_lethal_debug(mgr) -> void:
	if mgr.turn_manager == null:
		return
	var outcome := mgr.turn_manager.check_outcome()
	if outcome != TurnEnums.BattleOutcome.ONGOING:
		mgr.turn_manager.end_battle(outcome)


static func _team_tag(team: UnitEnums.Team) -> String:
	match team:
		UnitEnums.Team.PLAYER:  return "PLAYER"
		UnitEnums.Team.ENEMY:   return "ENEMY"
		UnitEnums.Team.NEUTRAL: return "NEUTRAL"
	return "?"


static func _archetype_name(archetype: FOILEnums.Archetype) -> String:
	match archetype:
		FOILEnums.Archetype.MELEE_AGGRO:    return "MELEE_AGGRO"
		FOILEnums.Archetype.RANGED_KITE:    return "RANGED_KITE"
		FOILEnums.Archetype.MAGIC_OFFENSE:  return "MAGIC_OFFENSE"
		FOILEnums.Archetype.HEALER_SUPPORT: return "HEALER_SUPPORT"
		FOILEnums.Archetype.TANK_WALL:      return "TANK_WALL"
		FOILEnums.Archetype.AOE_BLASTER:    return "AOE_BLASTER"
		FOILEnums.Archetype.DEBUFFER:       return "DEBUFFER"
		FOILEnums.Archetype.HYBRID:         return "HYBRID"
	return "?"
