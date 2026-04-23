class_name JobData extends Resource
## A job definition — the class/archetype a unit belongs to.
## Holds base stats, starting skills, and cosmetic metadata.
##
## Kept as a Resource so designers can author new jobs as .tres files in the
## editor without touching code. The factory pattern (JobLibrary) is used
## for Alpha only, while we iterate fast.


## --- Identity ---------------------------------------------------------------
@export var job_name: StringName = &""
@export var display_name: String = ""
@export var description: String = ""


## --- Base stats template ----------------------------------------------------
## This is a template. On unit spawn, call base_stats.duplicate() so each
## unit gets its own HP/MP pool to mutate.
@export var base_stats: UnitStats = null


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


## Fresh copy of the base stats, safe to mutate on a specific unit.
func instantiate_stats() -> UnitStats:
	if base_stats == null:
		push_error("JobData '%s' has no base_stats" % job_name)
		return UnitStats.new()
	var s: UnitStats = base_stats.duplicate(true)
	s.reset_to_full()
	return s


# =============================================================================
# FACTORY
# =============================================================================

static func create(
	p_job_name: StringName,
	p_display_name: String,
	p_base_stats: UnitStats,
	p_starting_skill_names: Array,
	p_job_color: Color = Color.WHITE,
	p_description: String = ""
) -> JobData:
	var j := JobData.new()
	j.job_name = p_job_name
	j.display_name = p_display_name
	j.base_stats = p_base_stats
	j.starting_skill_names = p_starting_skill_names
	j.job_color = p_job_color
	j.description = p_description
	return j
