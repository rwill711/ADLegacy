class_name JobProgression extends Resource
## Per-unit job progression tracker (FFTA-style). Stores which jobs a unit
## has unlocked, how much AP they've earned toward each skill in each job,
## and which skills are mastered.
##
## ADR-006: Every unit carries one of these. It persists across battles
## (once save/load lands) and is the source of truth for:
##   - Can this unit switch to job X? (are prerequisites met?)
##   - Which skills has this unit mastered? (permanent, cross-job)
##   - How much AP progress toward each unmastered skill?
##
## SERIALIZATION: get_save_data() / load_save_data() are provided now so
## the save system can pick them up when it's built. Uses plain Dictionaries
## for JSON compatibility.
##
## USAGE:
##   var prog := JobProgression.new()
##   prog.unlock_job(&"squire")           # starter jobs are auto-unlocked
##   prog.set_current_job(&"squire")
##   prog.award_ap(10)                    # after battle — distributes to current job's skills
##   prog.is_skill_mastered(&"first_aid") # → true once AP >= cost
##   prog.get_unlockable_jobs()           # → jobs whose prereqs are now met
##   prog.can_switch_to(&"soldier")       # → true if unlocked


# =============================================================================
# CONSTANTS — AP economy tuning knobs
# =============================================================================

## Flat AP awarded to every living unit at battle end.
const AP_PER_BATTLE: int = 10

## Bonus AP for the unit that landed the killing blow on the last enemy.
## Set to 0 to disable. Gives a small incentive for aggressive play.
const AP_BONUS_MVP: int = 5

## Bonus AP for a battle victory (all living units on winning team).
const AP_BONUS_VICTORY: int = 5


# =============================================================================
# STATE
# =============================================================================

## The job this unit is currently leveling. AP earned goes to this job's
## skill list. Set via set_current_job().
var current_job_name: StringName = &""

## Secondary ability set slot. The unit can use mastered skills from this
## job alongside their primary. Empty string = no secondary equipped.
var secondary_job_name: StringName = &""

## Set of job names this unit has unlocked. Includes starters.
## Dictionary used as a set: { &"squire": true, &"soldier": true }
var unlocked_jobs: Dictionary = {}

## AP progress per skill per job.
## Structure: { job_name: { skill_name: ap_accumulated } }
## Only tracks skills that have ap_cost > 0 and belong to the job's
## learnable list. Mastered skills stay in here (ap >= cost) — we don't
## remove them so the data is always inspectable.
var ap_progress: Dictionary = {}

## Cache of mastered skill names for fast lookup. Rebuilt from ap_progress
## whenever AP is awarded or data is loaded. Set<StringName>.
var _mastered_cache: Dictionary = {}


# =============================================================================
# INITIALIZATION
# =============================================================================

## Set up a fresh progression for a unit starting with the given job.
## Call once at unit creation. Unlocks the starter job and seeds AP
## tracking for its learnable skills.
func initialize(starter_job_name: StringName) -> void:
	current_job_name = starter_job_name
	unlocked_jobs = {}
	ap_progress = {}
	_mastered_cache = {}
	unlock_job(starter_job_name)


## Unlock all three starter jobs (Squire, Rogue, White Mage) so the unit
## can freely switch between them from the start — matches FFTA where
## base jobs are always available.
func initialize_starters(starting_job_name: StringName) -> void:
	initialize(starting_job_name)
	# Starter jobs are always available
	unlock_job(JobLibrary.SQUIRE)
	unlock_job(JobLibrary.ROGUE)
	unlock_job(JobLibrary.WHITE_MAGE)


# =============================================================================
# JOB UNLOCK
# =============================================================================

## Mark a job as unlocked. Safe to call multiple times.
func unlock_job(job_name: StringName) -> void:
	if unlocked_jobs.has(job_name):
		return
	unlocked_jobs[job_name] = true
	_ensure_ap_tracking(job_name)


## Check if a job is currently unlocked.
func is_job_unlocked(job_name: StringName) -> bool:
	return unlocked_jobs.has(job_name)


## Can this unit switch to the given job? Must be unlocked.
func can_switch_to(job_name: StringName) -> bool:
	return is_job_unlocked(job_name)


## Check if a job's prerequisites are met (but it might not be unlocked yet).
## Returns true if every prerequisite job has enough mastered abilities.
func meets_prerequisites(job_name: StringName) -> bool:
	var job_data: JobData = JobLibrary.get_job(job_name)
	if job_data == null:
		return false
	if job_data.prerequisites.is_empty():
		return true

	for prereq_job_name in job_data.prerequisites:
		var required_count: int = int(job_data.prerequisites[prereq_job_name])
		var mastered_count: int = get_mastered_count_for_job(prereq_job_name)
		if mastered_count < required_count:
			return false
	return true


## Return a list of job names that are NOT yet unlocked but whose
## prerequisites are now met. Useful for UI prompts ("New job available!").
func get_unlockable_jobs() -> Array:
	var result: Array = []
	for job_name in JobLibrary.all_job_names():
		if not is_job_unlocked(job_name) and meets_prerequisites(job_name):
			result.append(job_name)
	return result


## Attempt to unlock all jobs whose prerequisites are now met.
## Returns the list of newly unlocked job names (may be empty).
func try_unlock_new_jobs() -> Array:
	var newly_unlocked: Array = []
	for job_name in get_unlockable_jobs():
		unlock_job(job_name)
		newly_unlocked.append(job_name)
	return newly_unlocked


# =============================================================================
# AP TRACKING & MASTERY
# =============================================================================

## Award AP after a battle. Distributes to all unmastered learnable skills
## of the current job evenly. Returns the list of newly mastered skill names.
##
## FFTA distributes AP to all abilities simultaneously — you don't pick
## which ability to level. We follow that model.
func award_ap(amount: int) -> Array:
	if amount <= 0:
		return []
	if current_job_name == &"":
		return []

	_ensure_ap_tracking(current_job_name)

	var job_data: JobData = JobLibrary.get_job(current_job_name)
	if job_data == null:
		return []

	var newly_mastered: Array = []
	var job_ap: Dictionary = ap_progress.get(current_job_name, {})

	for skill_name in job_data.learnable_skill_names:
		var skill: SkillData = SkillLibrary.get_skill(skill_name)
		if skill == null:
			continue
		if skill.ap_cost <= 0:
			# Innate skill — already mastered by definition
			if not _mastered_cache.has(skill_name):
				_mastered_cache[skill_name] = true
				newly_mastered.append(skill_name)
			continue
		if _mastered_cache.has(skill_name):
			continue  # Already mastered

		var current_ap: int = int(job_ap.get(skill_name, 0))
		var new_ap: int = current_ap + amount
		job_ap[skill_name] = new_ap

		if new_ap >= skill.ap_cost:
			_mastered_cache[skill_name] = true
			newly_mastered.append(skill_name)

	ap_progress[current_job_name] = job_ap
	return newly_mastered


## Award battle-end AP with standard bonuses. Call this from the battle
## end handler. Returns { "ap_total": int, "newly_mastered": Array,
## "newly_unlocked_jobs": Array }.
func award_battle_ap(is_victory: bool, is_mvp: bool) -> Dictionary:
	var total: int = AP_PER_BATTLE
	if is_victory:
		total += AP_BONUS_VICTORY
	if is_mvp:
		total += AP_BONUS_MVP

	var mastered: Array = award_ap(total)
	var unlocked: Array = try_unlock_new_jobs()

	return {
		"ap_total": total,
		"newly_mastered": mastered,
		"newly_unlocked_jobs": unlocked,
	}


## Check if a specific skill has been mastered (from any job).
func is_skill_mastered(skill_name: StringName) -> bool:
	return _mastered_cache.has(skill_name)


## Get the number of mastered abilities for a specific job.
func get_mastered_count_for_job(job_name: StringName) -> int:
	var job_data: JobData = JobLibrary.get_job(job_name)
	if job_data == null:
		return 0
	var count: int = 0
	for skill_name in job_data.learnable_skill_names:
		if is_skill_mastered(skill_name):
			count += 1
	return count


## Get AP progress for a specific skill in a specific job.
## Returns { "current": int, "required": int, "mastered": bool }.
func get_skill_progress(job_name: StringName, skill_name: StringName) -> Dictionary:
	var skill: SkillData = SkillLibrary.get_skill(skill_name)
	if skill == null:
		return { "current": 0, "required": 0, "mastered": false }

	var required: int = skill.ap_cost
	if required <= 0:
		return { "current": 0, "required": 0, "mastered": true }

	var job_ap: Dictionary = ap_progress.get(job_name, {})
	var current: int = int(job_ap.get(skill_name, 0))
	return {
		"current": current,
		"required": required,
		"mastered": current >= required,
	}


## Return all mastered skill names as an Array.
func get_all_mastered_skills() -> Array:
	return _mastered_cache.keys()


## Return mastered skills that belong to a specific job's learnable list.
func get_mastered_skills_for_job(job_name: StringName) -> Array:
	var job_data: JobData = JobLibrary.get_job(job_name)
	if job_data == null:
		return []
	var result: Array = []
	for skill_name in job_data.learnable_skill_names:
		if is_skill_mastered(skill_name):
			result.append(skill_name)
	return result


# =============================================================================
# JOB SWITCHING
# =============================================================================

## Switch this unit's current (primary) job. Returns true on success.
## Caller is responsible for updating the Unit's job, stats, and skills
## after this call — this resource only tracks progression state.
func set_current_job(job_name: StringName) -> bool:
	if not can_switch_to(job_name):
		push_warning("JobProgression: can't switch to '%s' — not unlocked" % job_name)
		return false
	current_job_name = job_name
	_ensure_ap_tracking(job_name)
	return true


## Set the secondary ability set job. Must be unlocked and different from
## current. Pass &"" to clear.
func set_secondary_job(job_name: StringName) -> bool:
	if job_name == &"":
		secondary_job_name = &""
		return true
	if not is_job_unlocked(job_name):
		push_warning("JobProgression: can't set secondary '%s' — not unlocked" % job_name)
		return false
	if job_name == current_job_name:
		push_warning("JobProgression: secondary can't be same as primary '%s'" % job_name)
		return false
	secondary_job_name = job_name
	return true


## Build the full skill list for a unit given their current progression.
## Returns an Array of SkillData instances:
##   1. All learnable skills from the current job (if mastered or if currently
##      the active job — active job skills are usable while learning them,
##      matching FFTA where you can use abilities from your equipped weapon
##      even before mastering them).
##   2. All mastered skills from the secondary job (if set).
## De-duplicates by skill_name.
func build_active_skill_list() -> Array:
	var seen: Dictionary = {}
	var result: Array = []

	# Primary job: all learnable skills are usable (you're "wearing the gear")
	var primary: JobData = JobLibrary.get_job(current_job_name)
	if primary != null:
		for skill_name in primary.learnable_skill_names:
			if seen.has(skill_name):
				continue
			var skill: SkillData = SkillLibrary.get_skill(skill_name)
			if skill != null:
				seen[skill_name] = true
				result.append(skill)

	# Secondary job: only mastered skills
	if secondary_job_name != &"":
		var secondary: JobData = JobLibrary.get_job(secondary_job_name)
		if secondary != null:
			for skill_name in secondary.learnable_skill_names:
				if seen.has(skill_name):
					continue
				if is_skill_mastered(skill_name):
					var skill: SkillData = SkillLibrary.get_skill(skill_name)
					if skill != null:
						seen[skill_name] = true
						result.append(skill)

	return result


# =============================================================================
# INTERNAL
# =============================================================================

## Ensure the ap_progress dictionary has an entry for this job.
func _ensure_ap_tracking(job_name: StringName) -> void:
	if ap_progress.has(job_name):
		return
	var job_data: JobData = JobLibrary.get_job(job_name)
	if job_data == null:
		ap_progress[job_name] = {}
		return

	var job_ap: Dictionary = {}
	for skill_name in job_data.learnable_skill_names:
		job_ap[skill_name] = 0
	ap_progress[job_name] = job_ap


## Rebuild the mastered cache from ap_progress. Called after loading saved
## data or when the cache might be stale.
func rebuild_mastery_cache() -> void:
	_mastered_cache = {}
	for job_name in ap_progress:
		var job_data: JobData = JobLibrary.get_job(job_name)
		if job_data == null:
			continue
		var job_ap: Dictionary = ap_progress[job_name]
		for skill_name in job_data.learnable_skill_names:
			var skill: SkillData = SkillLibrary.get_skill(skill_name)
			if skill == null:
				continue
			if skill.ap_cost <= 0:
				_mastered_cache[skill_name] = true
			elif int(job_ap.get(skill_name, 0)) >= skill.ap_cost:
				_mastered_cache[skill_name] = true


# =============================================================================
# SERIALIZATION (for future save/load system)
# =============================================================================

func get_save_data() -> Dictionary:
	return {
		"current_job": current_job_name,
		"secondary_job": secondary_job_name,
		"unlocked_jobs": unlocked_jobs.keys(),
		"ap_progress": ap_progress.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	current_job_name = StringName(data.get("current_job", ""))
	secondary_job_name = StringName(data.get("secondary_job", ""))

	unlocked_jobs = {}
	for job_name in data.get("unlocked_jobs", []):
		unlocked_jobs[StringName(job_name)] = true

	ap_progress = {}
	var saved_ap: Dictionary = data.get("ap_progress", {})
	for job_name in saved_ap:
		var job_ap: Dictionary = {}
		for skill_name in saved_ap[job_name]:
			job_ap[StringName(skill_name)] = int(saved_ap[job_name][skill_name])
		ap_progress[StringName(job_name)] = job_ap

	rebuild_mastery_cache()


# =============================================================================
# DEBUG
# =============================================================================

## Human-readable summary for the debug overlay.
func debug_summary() -> String:
	var lines: Array = []
	lines.append("Current Job: %s" % current_job_name)
	lines.append("Secondary: %s" % (secondary_job_name if secondary_job_name != &"" else "none"))
	lines.append("Unlocked: %s" % ", ".join(unlocked_jobs.keys()))
	lines.append("Mastered Skills: %d" % _mastered_cache.size())

	for job_name in ap_progress:
		var job_ap: Dictionary = ap_progress[job_name]
		var mastered_count: int = get_mastered_count_for_job(job_name)
		var job_data: JobData = JobLibrary.get_job(job_name)
		var total_skills: int = job_data.learnable_skill_names.size() if job_data != null else 0
		lines.append("  %s: %d/%d mastered" % [job_name, mastered_count, total_skills])
		for skill_name in job_ap:
			var prog: Dictionary = get_skill_progress(job_name, skill_name)
			var status: String = "✅" if prog["mastered"] else "%d/%d" % [prog["current"], prog["required"]]
			lines.append("    %s: %s" % [skill_name, status])

	return "\n".join(lines)
