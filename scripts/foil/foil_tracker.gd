class_name FOILTracker extends Node
## Autoload singleton. Records player actions during battle and manages the
## rolling window. Supports MULTIPLE CONCURRENT CHARACTER BATTLES — one
## player party can have N units, each tracked independently against the
## rolling window per CD's per-character design.
##
## Integration:
##   BattleManager.start_battle() → FOILTracker.begin_battle(name) per party member
##   BattleManager.execute_skill() → FOILTracker.record_action(name, ...) for actor
##   BattleManager.end_battle()   → FOILTracker.commit_battle(name, ...) per member


## --- Rolling Window ---
## Array of FOILBattleRecord. Most recent battle is at the end.
var battle_history: Array[FOILBattleRecord] = []

## --- Current battles keyed by character name ---
## Each character in the active party gets their own record, updated in
## parallel. commit_battle(name) commits just one; abort_battle(name) drops it.
var _current_battles: Dictionary = {}

## --- Signals ---
signal battle_committed(battle_record: FOILBattleRecord)


# ===========================================================================
# BATTLE LIFECYCLE
# ===========================================================================

## Call at battle start for EACH player unit. Creates a fresh battle record
## for that character. Called multiple times in one battle is fine — one per
## party member.
func begin_battle(character_name: String, character_job: String, foil_level: int = 0) -> void:
	var key := StringName(character_name)
	var record := FOILBattleRecord.new()
	record.battle_id = _generate_battle_id(character_name)
	record.character_name = character_name
	record.character_job = character_job
	record.foil_level_faced = foil_level
	record.timestamp = int(Time.get_unix_time_from_system())
	_current_battles[key] = record


## Call on every action taken by `character_name`. Each caster routes to
## their own record, so a party of 3 builds 3 separate action trails.
func record_action(
	character_name: String,
	skill_name: String,
	skill_category: FOILEnums.SkillCategory,
	is_aoe: bool,
	target_name: String,
	target_job: String,
	targeted_ally: bool,
	damage_dealt: int,
	was_kill: bool,
	was_hit: bool,
	engagement_distance: int,
	caster_grid_pos: Vector2i,
	target_grid_pos: Vector2i,
	turn_number: int
) -> void:
	var key := StringName(character_name)
	if not _current_battles.has(key):
		push_warning("FOILTracker: record_action for '%s' with no active battle." % character_name)
		return

	var record: FOILBattleRecord = _current_battles[key]
	var character_job: String = record.character_job

	var action := FOILActionRecord.create(
		character_name,
		character_job,
		skill_name,
		skill_category,
		is_aoe,
		target_name,
		target_job,
		targeted_ally,
		damage_dealt,
		was_kill,
		was_hit,
		engagement_distance,
		caster_grid_pos,
		target_grid_pos,
		turn_number
	)
	record.add_action(action)


## Commit one character's battle record to the rolling window.
## Call once per party member at battle end.
func commit_battle(character_name: String, turn_count: int, was_victory: bool) -> void:
	var key := StringName(character_name)
	if not _current_battles.has(key):
		push_warning("FOILTracker: commit_battle for '%s' with no active battle." % character_name)
		return

	var record: FOILBattleRecord = _current_battles[key]
	record.turn_count = turn_count
	record.was_victory = was_victory

	battle_history.append(record)
	while battle_history.size() > FOILEnums.ROLLING_WINDOW_SIZE:
		battle_history.pop_front()

	battle_committed.emit(record)
	_current_battles.erase(key)


## Commit every currently-active battle in one call. Convenience for battle
## end so callers don't need to iterate their party.
func commit_all_battles(turn_count: int, was_victory: bool) -> void:
	for key in _current_battles.keys():
		commit_battle(String(key), turn_count, was_victory)


## Discard current battle for one character (e.g., unit defeated mid-battle
## with death-resets-profile behavior). Trait tags handled elsewhere.
func abort_battle(character_name: String) -> void:
	var key := StringName(character_name)
	_current_battles.erase(key)


func abort_all_battles() -> void:
	_current_battles.clear()


# ===========================================================================
# WINDOW QUERIES
# ===========================================================================

func get_battle_count() -> int:
	return battle_history.size()


func has_sufficient_data() -> bool:
	return battle_history.size() >= FOILEnums.ROLLING_WINDOW_MIN_BATTLES


func get_all_actions() -> Array[FOILActionRecord]:
	var all_actions: Array[FOILActionRecord] = []
	for battle in battle_history:
		for action in battle.actions:
			all_actions.append(action)
	return all_actions


func get_battles_for_character(character_name: String) -> Array[FOILBattleRecord]:
	var filtered: Array[FOILBattleRecord] = []
	for battle in battle_history:
		if battle.character_name == character_name:
			filtered.append(battle)
	return filtered


func get_win_rate() -> float:
	if battle_history.is_empty():
		return 0.0
	var wins: int = 0
	for battle in battle_history:
		if battle.was_victory:
			wins += 1
	return float(wins) / battle_history.size()


## True if any character has an open battle right now.
func has_active_battle() -> bool:
	return not _current_battles.is_empty()


## True if the given character already has an open battle record.
## Lets the action controller avoid double-starting a character's record.
func has_character_battle(character_name: String) -> bool:
	return _current_battles.has(StringName(character_name))


# ===========================================================================
# CHARACTER RESET
# ===========================================================================

func reset_history() -> void:
	battle_history.clear()
	abort_all_battles()


func clear_character_history(character_name: String) -> void:
	var kept: Array[FOILBattleRecord] = []
	for battle in battle_history:
		if battle.character_name != character_name:
			kept.append(battle)
	battle_history = kept


# ===========================================================================
# SAVE / LOAD
# ===========================================================================

func save_to_dict() -> Dictionary:
	var battle_dicts: Array = []
	for battle in battle_history:
		battle_dicts.append(battle.to_dict())
	return {
		"version": 2,   # bumped: v1 had single active battle, v2 supports many
		"battle_history": battle_dicts,
	}


func load_from_dict(data: Dictionary) -> void:
	battle_history.clear()
	var _version: int = data.get("version", 1)
	for battle_data in data.get("battle_history", []):
		battle_history.append(FOILBattleRecord.from_dict(battle_data))


# ===========================================================================
# INTERNALS
# ===========================================================================

func _generate_battle_id(character_name: String) -> String:
	return "battle_%s_%d" % [character_name, int(Time.get_unix_time_from_system())]
