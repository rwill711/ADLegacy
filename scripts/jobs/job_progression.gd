class_name JobProgression extends Resource
## Per-unit record of AP earned in each job and job unlock state.
##
## Lives on Unit. Survives job changes — switching back to an old job restores
## every skill the unit had already earned there.
##
## AP model:
##   - Units start with STARTING_JOB_AP in their initial job, so all of that
##     job's starting_skill_names (even those with ap_cost > 0) are available
##     from turn 1.
##   - Newly unlocked advanced jobs start at 0 AP; only ap_cost=0 skills
##     (basic attacks) are available until AP is earned in battle.
##   - skills_for_job() is the single query for "what skills does this unit
##     have access to right now in job X?" — used by change_job() and the UI.


## AP awarded for completing a starter job at initialization.
const STARTING_JOB_AP: int = 1000

## AP accumulated per job. StringName(job_name) → int.
var ap_per_job: Dictionary = {}


# =============================================================================
# AP TRACKING
# =============================================================================

## Award AP toward a job. Returns the new total for that job.
func award_ap(job_name: StringName, amount: int) -> int:
	if amount <= 0:
		return ap_per_job.get(job_name, 0)
	ap_per_job[job_name] = ap_per_job.get(job_name, 0) + amount
	return ap_per_job[job_name]


## AP accumulated in a job (0 if never touched).
func get_ap(job_name: StringName) -> int:
	return ap_per_job.get(job_name, 0)


# =============================================================================
# UNLOCK / SKILL QUERIES
# =============================================================================

## Whether this unit may switch to the given job.
## Starter jobs (no prerequisites) always return true.
## Advanced jobs require the unit to have earned enough AP in prerequisite jobs.
func is_job_unlocked(job_name: StringName) -> bool:
	for req in JobLibrary.get_job_prerequisites(job_name):
		if get_ap(StringName(req["job"])) < int(req["ap_needed"]):
			return false
	return true


## Skills this unit currently has access to in the given job, based on AP earned.
## Includes ap_cost=0 starters always; higher-cost skills unlock as AP grows.
func skills_for_job(job_name: StringName) -> Array:
	var job: JobData = JobLibrary.get_job(job_name)
	if job == null:
		return []
	var ap: int = get_ap(job_name)
	var out: Array = []
	for skill_name in job.starting_skill_names:
		var skill: SkillData = SkillLibrary.get_skill(skill_name)
		if skill != null and ap >= skill.ap_cost:
			out.append(skill)
	return out
