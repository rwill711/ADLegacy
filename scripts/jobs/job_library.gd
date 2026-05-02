class_name JobLibrary
## Factory for all jobs. Started with Alpha's 3 starters; advanced jobs are
## added one at a time as ADR-006 rolls out.
##
## ADR-004 STAT REWORK:
## Stats are now derived from a 6-attribute standard array (30 points,
## each 1–10) via StatFormulas. Movement stats (move_range, jump) are
## job-level identity, not attribute-derived.
##
## ADR-006 JOB PROGRESSION:
## Each job now carries:
##   - learnable_skill_names: full set of skills this job can teach
##   - prerequisites: { job_name → mastered_count } to unlock this job
## Starter jobs have empty prerequisites (always available).
##
## ATTRIBUTE SPREADS — designed so each job has a clear identity:
##   Rogue:      fast and lucky, physically fragile
##   Squire:     balanced frontliner, toughest Constitution
##   White Mage: high Wisdom, fragile body, decent Charisma
##
## DERIVED STAT PREVIEW (via StatFormulas):
## ┌────────────┬────┬────┬────┬─────┬─────┬─────┬─────┬──────┬──────┐
## │ Job        │ HP │ MP │ATK │ DEF │ MAG │ RES │ SPD │ MOVE │ JUMP │
## ├────────────┼────┼────┼────┼─────┼─────┼─────┼─────┼──────┼──────┤
## │ Rogue      │ 30 │ 25 │ 16 │  5  │ 12  │  5  │ 23  │  5   │  2   │
## │ Squire     │ 50 │ 25 │ 17 │ 10  │ 12  │  7  │ 14  │  4   │  3   │
## │ White Mage │ 35 │ 50 │  8 │  5  │ 23  │ 11  │ 12  │  3   │  1   │
## └────────────┴────┴────┴────┴─────┴─────┴─────┴─────┴──────┴──────┘
##
## COMBAT MATH SANITY CHECK (basic attack, flank, power 1.0):
##   Rogue → Squire:  max(1, 16 - 10) = 6 dmg  → ~8 hits to kill (50 HP)
##   Squire → Rogue:  max(1, 17 -  5) = 12 dmg → ~3 hits to kill (30 HP)
##   Rogue → WM:      max(1, 16 -  5) = 11 dmg → ~3 hits to kill (35 HP)
##   WM Cure on Squire: 23 * 2.0 = 46 HP healed (nearly full, 4 MP)
##
## Encounters should resolve in 4–8 rounds. Tuning pass in Phase 10.


## --- Job name constants -----------------------------------------------------
## Starter jobs
const ROGUE       := &"rogue"
const SQUIRE      := &"squire"
const WHITE_MAGE  := &"white_mage"

## Advanced jobs (added one at a time — constants defined up front so
## prerequisites can reference them before the job factory is wired up)
const SOLDIER     := &"soldier"
const KNIGHT      := &"knight"
const PALADIN     := &"paladin"
const ASSASSIN    := &"assassin"
const NINJA       := &"ninja"
const SHADOW      := &"shadow"
const BISHOP      := &"bishop"
const TIME_MAGE   := &"time_mage"
const SAGE        := &"sage"


## --- Master registry --------------------------------------------------------
## Returns all job name constants. Used by JobProgression.get_unlockable_jobs()
## to iterate the full tree without hardcoding names outside this file.
## ADD new jobs here as they're implemented.
static func all_job_names() -> Array:
	return [
		# Starters
		ROGUE, SQUIRE, WHITE_MAGE,
		# Advanced — uncomment as each job is implemented:
		# SOLDIER, KNIGHT, PALADIN,
		# ASSASSIN, NINJA, SHADOW,
		# BISHOP, TIME_MAGE, SAGE,
	]


## --- Lookup -----------------------------------------------------------------
static func get_job(job_name: StringName) -> JobData:
	match job_name:
		ROGUE:      return _rogue()
		SQUIRE:     return _squire()
		WHITE_MAGE: return _white_mage()
	push_warning("JobLibrary: unknown job '%s'" % [job_name])
	return null


static func all_alpha_jobs() -> Array:
	return [_rogue(), _squire(), _white_mage()]


# =============================================================================
# STARTER JOB DEFINITIONS
# =============================================================================

static func _rogue() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(4, 8, 3, 4, 7, 4)
	return JobData.create(
		ROGUE, "Rogue", attrs,
		5,  # MOVE — high, flanking is the whole identity
		2,  # JUMP — moderate, can handle elevation
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.BACKSTAB, SkillLibrary.STEAL],
		Color(0.75, 0.55, 0.95),  # purple-ish accent
		"Fast and fragile. Rewards flanking and rear attacks.",
		# learnable_skill_names — same as starting for now; advanced Rogue
		# skills added when Assassin/Ninja are implemented
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.BACKSTAB, SkillLibrary.STEAL],
		{}  # no prerequisites — starter job
	)


static func _squire() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(6, 5, 7, 4, 4, 4)
	return JobData.create(
		SQUIRE, "Squire", attrs,
		4,  # MOVE — standard
		3,  # JUMP — best vertical mobility
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.FIRST_AID, SkillLibrary.STONE_THROW,
		 SkillLibrary.CHOP, SkillLibrary.PUSH_ROCK],
		Color(0.9, 0.85, 0.55),  # warm tan
		"Balanced frontliner. Reliable melee with ranged and self-heal options.",
		# learnable_skill_names
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.FIRST_AID, SkillLibrary.STONE_THROW,
		 SkillLibrary.CHOP, SkillLibrary.PUSH_ROCK],
		{}  # no prerequisites — starter job
	)


static func _white_mage() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(2, 4, 4, 5, 4, 9)
	# (WIS near cap: this is the high-magic job; room to grow to 10)
	return JobData.create(
		WHITE_MAGE, "White Mage", attrs,
		3,  # MOVE — low, positioning matters
		1,  # JUMP — fragile, not agile
		[SkillLibrary.STAFF_BONK, SkillLibrary.CURE, SkillLibrary.PROTECT],
		Color(0.95, 0.95, 0.95),  # near-white
		"Backline healer and buffer. Keep them out of melee.",
		# learnable_skill_names
		[SkillLibrary.STAFF_BONK, SkillLibrary.CURE, SkillLibrary.PROTECT],
		{}  # no prerequisites — starter job
	)
