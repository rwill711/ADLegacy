class_name JobData extends Resource
## A job definition — the class/archetype a unit belongs to.
## Holds base attributes (the 6-stat standard array), movement identity,
## learnable skills, progression prerequisites, and cosmetic metadata.
##
## Kept as a Resource so designers can author new jobs as .tres files in the
## editor without touching code. The factory pattern (JobLibrary) is used
## for Alpha only, while we iterate fast.
##
## STAT FLOW (ADR-004):
##   JobData.base_attributes → StatFormulas.derive() → UnitStats (per unit)
##   Equipment/buff modifiers are applied on top (future system).
##
## PROGRESSION FLOW (ADR-006):
##   Each job defines learnable_skill_names (the full skill tree for this job)
##   and prerequisites (which other jobs must be partially mastered to unlock
##   this one). Starting skills are the subset available at job level 0;
##   the rest are learned via AP accumulation.


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


## --- Starting abilities (Alpha compat) --------------------------------------
## Skill names that a fresh unit in this job starts with. Subset of
## learnable_skill_names. Kept for backward compatibility — new code should
## use learnable_skill_names + JobProgression to determine available skills.
@export var starting_skill_names: Array = []


## --- Learnable abilities (ADR-006) ------------------------------------------
## The FULL list of skills this job can teach. Includes starting skills.
## Each skill's ap_cost (on SkillData) determines how much AP is needed
## to master it. Skills with ap_cost = 0 are innate (always available
## while this job is active).
@export var learnable_skill_names: Array = []


## --- Job prerequisites (ADR-006) --------------------------------------------
## Dictionary mapping prerequisite job_name → number of abilities that must
## be mastered from that job before this job unlocks.
## Example: { &"squire": 2 } means "master 2 Squire abilities to unlock."
## Empty dict = starter job (always available).
@export var prerequisites: Dictionary = {}


## --- Cosmetic ---------------------------------------------------------------
## Color tint applied to the placeholder capsule mesh. Blended with team
## color so Rogue-blue still reads as player-team-blue.
@export var job_color: Color = Color.WHITE


# =============================================================================
# QUERIES
# =============================================================================

## Resolve the job's starting skills into SkillData instances.
## For legacy/Alpha compatibility — new progression code uses
## JobProgression.build_active_skill_list() instead.
func get_starting_skills() -> Array:
	return SkillLibrary.get_skills(starting_skill_names)


## Resolve ALL learnable skills into SkillData instances.
func get_learnable_skills() -> Array:
	return SkillLibrary.get_skills(learnable_skill_names)


## Fresh UnitStats derived from this job's base attributes, safe to mutate
## on a specific unit. Pools are reset to full.
func instantiate_stats() -> UnitStats:
	if base_attributes == null:
		push_error("JobData '%s' has no base_attributes" % job_name)
		return UnitStats.new()

	return StatFormulas.derive(base_attributes, base_move_range, base_jump)


## Whether this is a starter job (no prerequisites).
func is_starter() -> bool:
	return prerequisites.is_empty()


## Total number of learnable skills.
func learnable_count() -> int:
	return learnable_skill_names.size()


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
	p_description: String = "",
	p_learnable_skill_names: Array = [],
	p_prerequisites: Dictionary = {}
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
	# If no learnable list given, fall back to starting skills (Alpha compat)
	j.learnable_skill_names = p_learnable_skill_names if not p_learnable_skill_names.is_empty() else p_starting_skill_names.duplicate()
	j.prerequisites = p_prerequisites
	return j
