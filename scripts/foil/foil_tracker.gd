class_name FOILTracker extends Node
## Autoload singleton. Records player actions during battle and manages the rolling window.
## Hook into BattleManager — call record_action() on every player action,
## call commit_battle() when battle ends.

## --- Rolling Window ---
## Array of FOILBattleRecord. Most recent battle is at the end.
var battle_history: Array[FOILBattleRecord] = []

## --- Current Battle ---
## Accumulates actions for the battle in progress. Committed on battle end.
var _current_battle: FOILBattleRecord = null
var _battle_active: bool = false

## --- Character Context ---
## Set at battle start so every action record gets tagged correctly.
var _current_character_name: String = ""
var _current_character_job: String = ""

## --- Signals ---
signal battle_committed(battle_record: FOILBattleRecord)


# ===========================================================================
# BATTLE LIFECYCLE
# ===========================================================================

## Call at battle start. Sets up a fresh battle record.
func begin_battle(character_name: String, character_job: String, foil_level: int = 0) -> void:
	_current_battle = FOILBattleRecord.new()
	_current_battle.battle_id = _generate_battle_id()
	_current_battle.character_name = character_name
	_current_battle.character_job = character_job
	_current_battle.foil_level_faced = foil_level
	_current_battle.timestamp = int(Time.get_unix_time_from_system())
	_current_character_name = character_name
	_current_character_job = character_job
	_battle_active = true


## Call on every player action during battle.
func record_action(
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
	if not _battle_active or _current_battle == null:
		push_warning("FOILTracker: record_action called with no active battle.")
		return

	var record := FOILActionRecord.create(
		_current_character_name,
		_current_character_job,
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
	_current_battle.add_action(record)


## Call when battle ends. Commits the battle record to the rolling window.
func commit_battle(turn_count: int, was_victory: bool) -> void:
	if not _battle_active or _current_battle == null:
		push_warning("FOILTracker: commit_battle called with no active battle.")
		return

	_current_battle.turn_count = turn_count
	_current_battle.was_victory = was_victory

	# Push to rolling window
	battle_history.append(_current_battle)

	# Trim window to max size
	while battle_history.size() > FOILEnums.ROLLING_WINDOW_SIZE:
		battle_history.pop_front()

	battle_committed.emit(_current_battle)

	# Clean up
	_current_battle = null
	_battle_active = false


## Discard current battle without committing (e.g., player quit mid-battle).
func abort_battle() -> void:
	_current_battle = null
	_battle_active = false


# ===========================================================================
# WINDOW QUERIES
# ===========================================================================

## Returns the number of battles in the rolling window.
func get_battle_count() -> int:
	return battle_history.size()


## Returns true if enough data exists for FOIL to adapt.
func has_sufficient_data() -> bool:
	return battle_history.size() >= FOILEnums.ROLLING_WINDOW_MIN_BATTLES


## Returns all action records across the entire rolling window (flattened).
func get_all_actions() -> Array[FOILActionRecord]:
	var all_actions: Array[FOILActionRecord] = []
	for battle in battle_history:
		for action in battle.actions:
			all_actions.append(action)
	return all_actions


## Returns battle records for a specific character only.
func get_battles_for_character(character_name: String) -> Array[FOILBattleRecord]:
	var filtered: Array[FOILBattleRecord] = []
	for battle in battle_history:
		if battle.character_name == character_name:
			filtered.append(battle)
	return filtered


## Returns the win rate across the rolling window.
func get_win_rate() -> float:
	if battle_history.is_empty():
		return 0.0
	var wins: int = 0
	for battle in battle_history:
		if battle.was_victory:
			wins += 1
	return float(wins) / battle_history.size()


# ===========================================================================
# CHARACTER RESET
# ===========================================================================

## Clear all history. Called on character death (new character starts fresh).
func reset_history() -> void:
	battle_history.clear()
	abort_battle()


## Clear history for a specific character only (if tracking multiple).
func clear_character_history(character_name: String) -> void:
	var kept: Array[FOILBattleRecord] = []
	for battle in battle_history:
		if battle.character_name != character_name:
			kept.append(battle)
	battle_history = kept


# ===========================================================================
# SAVE / LOAD
# ===========================================================================

## Serialize the full rolling window to a dictionary for save files.
func save_to_dict() -> Dictionary:
	var battle_dicts: Array = []
	for battle in battle_history:
		battle_dicts.append(battle.to_dict())
	return {
		"version": 1,
		"battle_history": battle_dicts
	}


## Load rolling window from saved dictionary.
func load_from_dict(data: Dictionary) -> void:
	battle_history.clear()
	var _version: int = data.get("version", 1)
	for battle_data in data.get("battle_history", []):
		battle_history.append(FOILBattleRecord.from_dict(battle_data))


# ===========================================================================
# INTERNALS
# ===========================================================================

func _generate_battle_id() -> String:
	return "battle_%s_%d" % [_current_character_name, int(Time.get_unix_time_from_system())]
