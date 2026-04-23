class_name FOILBattleRecord extends Resource
## Contains all FOIL action records from a single battle.
## This is one "slot" in the rolling window.

## All actions the player took this battle.
@export var actions: Array[FOILActionRecord] = []

## Battle metadata
@export var battle_id: String = ""
@export var character_name: String = ""
@export var character_job: String = ""
@export var turn_count: int = 0
@export var was_victory: bool = false
@export var foil_level_faced: int = 0  ## What FOIL level the CPU was at this fight
@export var timestamp: int = 0  ## Unix timestamp for ordering


func add_action(record: FOILActionRecord) -> void:
	actions.append(record)


## Quick stats derived from this battle's actions.
func get_action_count() -> int:
	return actions.size()


func get_kill_count() -> int:
	var kills: int = 0
	for action in actions:
		if action.was_kill:
			kills += 1
	return kills


func get_category_counts() -> Dictionary:
	## Returns {SkillCategory: count} for this battle.
	var counts: Dictionary = {}
	for action in actions:
		var cat: int = action.skill_category
		counts[cat] = counts.get(cat, 0) + 1
	return counts


func get_avg_engagement_distance() -> float:
	if actions.is_empty():
		return 0.0
	var total: float = 0.0
	for action in actions:
		total += action.engagement_distance
	return total / actions.size()


func get_aoe_ratio() -> float:
	if actions.is_empty():
		return 0.0
	var aoe_count: int = 0
	for action in actions:
		if action.is_aoe:
			aoe_count += 1
	return float(aoe_count) / actions.size()


func to_dict() -> Dictionary:
	var action_dicts: Array = []
	for action in actions:
		action_dicts.append(action.to_dict())
	return {
		"battle_id": battle_id,
		"character_name": character_name,
		"character_job": character_job,
		"turn_count": turn_count,
		"was_victory": was_victory,
		"foil_level_faced": foil_level_faced,
		"timestamp": timestamp,
		"actions": action_dicts
	}


static func from_dict(data: Dictionary) -> FOILBattleRecord:
	var record := FOILBattleRecord.new()
	record.battle_id = data.get("battle_id", "")
	record.character_name = data.get("character_name", "")
	record.character_job = data.get("character_job", "")
	record.turn_count = data.get("turn_count", 0)
	record.was_victory = data.get("was_victory", false)
	record.foil_level_faced = data.get("foil_level_faced", 0)
	record.timestamp = data.get("timestamp", 0)
	for action_data in data.get("actions", []):
		record.actions.append(FOILActionRecord.from_dict(action_data))
	return record
