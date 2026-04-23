class_name JobLibrary
## Factory for Alpha's 3 jobs: Rogue, Squire, White Mage.
## Stats are the Creative Director's roadmap targets, with concrete numbers
## picked to sell each job's identity:
##   - Rogue: glass cannon mobility (high SPD, high MOVE, low HP/DEF)
##   - Squire: balanced frontliner (everything mid)
##   - White Mage: fragile backline support (low HP/DEF, high MP/RES)
## These are first-pass values. Phase 10 (Tuning Pass) will revisit.


## --- Job name constants -----------------------------------------------------
const ROGUE       := &"rogue"
const SQUIRE      := &"squire"
const WHITE_MAGE  := &"white_mage"


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
# JOB DEFINITIONS
# =============================================================================

static func _rogue() -> JobData:
	var stats := UnitStats.create(
		80,   # HP — low
		20,   # MP — low, Rogue is MP-free
		14,   # ATK — high (primary damage)
		 8,   # DEF — low
		 6,   # MAG — token amount
		 6,   # RES — low
		14,   # SPD — high (gets more turns)
		 5,   # MOVE — high
		 2,   # JUMP — can handle moderate elevation
	)
	return JobData.create(
		ROGUE, "Rogue", stats,
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.BACKSTAB, SkillLibrary.STEAL],
		Color(0.75, 0.55, 0.95),  # purple-ish accent
		"Fast and fragile. Rewards flanking and rear attacks."
	)


static func _squire() -> JobData:
	var stats := UnitStats.create(
		110,  # HP — solid
		 30,  # MP — modest
		 11,  # ATK — mid
		 11,  # DEF — mid
		  8,  # MAG — low
		  8,  # RES — low
		 10,  # SPD — mid
		  4,  # MOVE — standard
		  3,  # JUMP — best vertical mobility
	)
	return JobData.create(
		SQUIRE, "Squire", stats,
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.FIRST_AID, SkillLibrary.STONE_THROW],
		Color(0.9, 0.85, 0.55),  # warm tan
		"Balanced frontliner. Reliable melee with ranged and self-heal options."
	)


static func _white_mage() -> JobData:
	var stats := UnitStats.create(
		 75,  # HP — fragile
		 60,  # MP — highest (fuels spells)
		  6,  # ATK — very low
		  7,  # DEF — low
		 14,  # MAG — highest
		 13,  # RES — high (magic-resistant)
		  8,  # SPD — slowest of the three
		  3,  # MOVE — low, positioning matters
		  1,  # JUMP — fragile, not agile
	)
	return JobData.create(
		WHITE_MAGE, "White Mage", stats,
		[SkillLibrary.STAFF_BONK, SkillLibrary.CURE, SkillLibrary.PROTECT],
		Color(0.95, 0.95, 0.95),  # near-white
		"Backline healer and buffer. Keep them out of melee."
	)
