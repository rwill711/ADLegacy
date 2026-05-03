class_name JobData extends Resource
## A job definition — the class/archetype a unit belongs to.
## Holds base attributes (the 6-stat standard array), movement identity,
## starting skills, and cosmetic metadata.
##
## Kept as a Resource so designers can author new jobs as .tres files in the
## editor without touching code. The factory pattern (JobLibrary) is used
## for Alpha only, while we iterate fast.
##
## STAT FLOW (ADR-004):
##   JobData.base_attributes → StatFormulas.derive() → UnitStats (per unit)
##   Equipment/buff modifiers are applied on top (future system).


## --- Identity ---------------------------------------------------------------
@export var job_name: StringName = &""
@export var display_name: String = ""
@export var description: String = ""


## --- Base attributes --------------------------------------------------------
## The standard-array allocation for this job. Must satisfy BaseAttributes
## validation (total = 30, each 1–10). On unit spawn, StatFormulas reads
## this to produce the unit's derived combat stats.
@export var base_attributes: BaseAttributes = null


## --- Movement identity ------------------------------------------------------
## These are job-level stats, NOT derived from attributes. They define the
## class's tactical identity on the grid.
@export var base_move_range: int = 3
@export var base_jump: int = 2


## --- Starting abilities -----------------------------------------------------
## Skill names (StringNames) that SkillLibrary.get_skill() resolves to
## SkillData instances. Using names (not direct resource references) keeps
## JobData decoupled from the skill storage backend — swap in .tres files
## later without changing this resource.
@export var starting_skill_names: Array = []


## --- Cosmetic ---------------------------------------------------------------
## Color tint applied to the placeholder capsule mesh. Blended with team
## color so Rogue-blue still reads as player-team-blue.
@export var job_color: Color = Color.WHITE


# =============================================================================
# QUERIES
# =============================================================================

## Resolve the job's starting skills into SkillData instances.
func get_starting_skills() -> Array:
	return SkillLibrary.get_skills(starting_skill_names)


## Fresh UnitStats derived from this job's base attributes, safe to mutate
## on a specific unit. Pools are reset to full.
func instantiate_stats() -> UnitStats:
	if base_attributes == null:
		push_error("JobData '%s' has no base_attributes" % job_name)
		return UnitStats.new()

	return StatFormulas.derive(base_attributes, base_move_range, base_jump)


# =============================================================================
# FACTORY
# =============================================================================

static func create(
	p_job_name: StringName,
	p_display_name: String,
	p_base_attributes: BaseAttributes,
	p_move_range: int,
	p_jump: int,
	p_starting_skill_names: Array,
	p_job_color: Color = Color.WHITE,
	p_description: String = ""
) -> JobData:
	var j := JobData.new()
	j.job_name = p_job_name
	j.display_name = p_display_name
	j.base_attributes = p_base_attributes
	j.base_move_range = p_move_range
	j.base_jump = p_jump
	j.starting_skill_names = p_starting_skill_names
	j.job_color = p_job_color
	j.description = p_description
	return j
