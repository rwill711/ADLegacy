class_name FOILActionRecord extends Resource
## A single recorded player action during battle.
## These get collected per-battle, then the full battle gets pushed to the rolling window.

## --- Who acted ---
@export var caster_name: String = ""
@export var caster_job: String = ""

## --- What they did ---
@export var skill_name: String = ""
@export var skill_category: FOILEnums.SkillCategory = FOILEnums.SkillCategory.PHYSICAL_MELEE
@export var is_aoe: bool = false

## --- Target info ---
@export var target_name: String = ""
@export var target_job: String = ""
@export var targeted_ally: bool = false  ## true if healing/buff on ally

## --- Outcome ---
@export var damage_dealt: int = 0
@export var was_kill: bool = false
@export var was_hit: bool = true  ## false if missed

## --- Positioning ---
@export var engagement_distance: int = 1  ## Manhattan distance caster-to-target
@export var caster_grid_pos: Vector2i = Vector2i.ZERO
@export var target_grid_pos: Vector2i = Vector2i.ZERO

## --- Context ---
@export var turn_number: int = 0


static func create(
	p_caster_name: String,
	p_caster_job: String,
	p_skill_name: String,
	p_skill_category: FOILEnums.SkillCategory,
	p_is_aoe: bool,
	p_target_name: String,
	p_target_job: String,
	p_targeted_ally: bool,
	p_damage_dealt: int,
	p_was_kill: bool,
	p_was_hit: bool,
	p_engagement_distance: int,
	p_caster_grid_pos: Vector2i,
	p_target_grid_pos: Vector2i,
	p_turn_number: int
) -> FOILActionRecord:
	var record := FOILActionRecord.new()
	record.caster_name = p_caster_name
	record.caster_job = p_caster_job
	record.skill_name = p_skill_name
	record.skill_category = p_skill_category
	record.is_aoe = p_is_aoe
	record.target_name = p_target_name
	record.target_job = p_target_job
	record.targeted_ally = p_targeted_ally
	record.damage_dealt = p_damage_dealt
	record.was_kill = p_was_kill
	record.was_hit = p_was_hit
	record.engagement_distance = p_engagement_distance
	record.caster_grid_pos = p_caster_grid_pos
	record.target_grid_pos = p_target_grid_pos
	record.turn_number = p_turn_number
	return record


func to_dict() -> Dictionary:
	return {
		"caster_name": caster_name,
		"caster_job": caster_job,
		"skill_name": skill_name,
		"skill_category": skill_category,
		"is_aoe": is_aoe,
		"target_name": target_name,
		"target_job": target_job,
		"targeted_ally": targeted_ally,
		"damage_dealt": damage_dealt,
		"was_kill": was_kill,
		"was_hit": was_hit,
		"engagement_distance": engagement_distance,
		"caster_grid_pos": {"x": caster_grid_pos.x, "y": caster_grid_pos.y},
		"target_grid_pos": {"x": target_grid_pos.x, "y": target_grid_pos.y},
		"turn_number": turn_number
	}


static func from_dict(data: Dictionary) -> FOILActionRecord:
	var record := FOILActionRecord.new()
	record.caster_name = data.get("caster_name", "")
	record.caster_job = data.get("caster_job", "")
	record.skill_name = data.get("skill_name", "")
	record.skill_category = data.get("skill_category", FOILEnums.SkillCategory.PHYSICAL_MELEE)
	record.is_aoe = data.get("is_aoe", false)
	record.target_name = data.get("target_name", "")
	record.target_job = data.get("target_job", "")
	record.targeted_ally = data.get("targeted_ally", false)
	record.damage_dealt = data.get("damage_dealt", 0)
	record.was_kill = data.get("was_kill", false)
	record.was_hit = data.get("was_hit", true)
	record.engagement_distance = data.get("engagement_distance", 1)
	var cpos = data.get("caster_grid_pos", {"x": 0, "y": 0})
	record.caster_grid_pos = Vector2i(cpos["x"], cpos["y"])
	var tpos = data.get("target_grid_pos", {"x": 0, "y": 0})
	record.target_grid_pos = Vector2i(tpos["x"], tpos["y"])
	record.turn_number = data.get("turn_number", 0)
	return record
