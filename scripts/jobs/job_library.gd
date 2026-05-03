class_name JobLibrary
## Factory for Alpha's 3 jobs: Rogue, Squire, White Mage.
##
## ADR-004 STAT REWORK:
## Stats are now derived from a 6-attribute standard array (30 points,
## each 1–10) via StatFormulas. Movement stats (move_range, jump) are
## job-level identity, not attribute-derived.
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
const ROGUE       := &"rogue"
const SQUIRE      := &"squire"
const WHITE_MAGE  := &"white_mage"
const DARK_MAGE   := &"dark_mage"
const ARCHER      := &"archer"
const SOLDIER     := &"soldier"
const KNIGHT      := &"knight"
const ASSASSIN    := &"assassin"
const NINJA       := &"ninja"
const BISHOP      := &"bishop"
const TIME_MAGE   := &"time_mage"
const PALADIN     := &"paladin"
const SHADOW      := &"shadow"
const SAGE        := &"sage"


## --- Lookup -----------------------------------------------------------------
static func get_job(job_name: StringName) -> JobData:
	match job_name:
		ROGUE:      return _rogue()
		SQUIRE:     return _squire()
		WHITE_MAGE: return _white_mage()
		DARK_MAGE:  return _dark_mage()
		ARCHER:     return _archer()
		SOLDIER:    return _soldier()
		KNIGHT:     return _knight()
		ASSASSIN:   return _assassin()
		NINJA:      return _ninja()
		BISHOP:     return _bishop()
		TIME_MAGE:  return _time_mage()
		PALADIN:    return _paladin()
		SHADOW:     return _shadow()
		SAGE:       return _sage()
	push_warning("JobLibrary: unknown job '%s'" % [job_name])
	return null


static func all_alpha_jobs() -> Array:
	return [
		_rogue(), _squire(), _white_mage(), _dark_mage(), _archer(),
		_soldier(), _knight(), _assassin(), _ninja(), _bishop(), _time_mage(),
		_paladin(), _shadow(), _sage(),
	]


## All job StringNames in the registry. Add new jobs here as they land.
## Used by JobProgression unlock checks and the character-select dropdown.
static func all_job_names() -> Array:
	return [
		ROGUE, SQUIRE, WHITE_MAGE, DARK_MAGE, ARCHER,
		SOLDIER, KNIGHT, ASSASSIN, NINJA, BISHOP, TIME_MAGE,
		PALADIN, SHADOW, SAGE,
	]


## Unlock prerequisites for a job.
## Returns Array of {job: StringName, ap_needed: int} dicts.
## Empty array = starter job, always available.
## Add advanced job entries here as each Bite lands (Bites 3+).
static func get_job_prerequisites(job_name: StringName) -> Array:
	match job_name:
		ROGUE, SQUIRE, WHITE_MAGE, DARK_MAGE, ARCHER:
			return []
		SOLDIER:
			return [{job = SQUIRE, ap_needed = 1500}]
		KNIGHT:
			return [{job = SQUIRE, ap_needed = 1500}]
		ASSASSIN:
			return [{job = ROGUE, ap_needed = 1500}]
		NINJA:
			return [{job = ROGUE, ap_needed = 1500}]
		BISHOP:
			return [{job = WHITE_MAGE, ap_needed = 1500}]
		TIME_MAGE:
			return [{job = WHITE_MAGE, ap_needed = 1500}]
		PALADIN:
			return [{job = KNIGHT, ap_needed = 1500}, {job = WHITE_MAGE, ap_needed = 1500}]
		SHADOW:
			return [{job = ASSASSIN, ap_needed = 1500}, {job = NINJA, ap_needed = 1500}]
		SAGE:
			return [{job = WHITE_MAGE, ap_needed = 1500}, {job = TIME_MAGE, ap_needed = 1500}]
	push_warning("JobLibrary.get_job_prerequisites: unknown job '%s'" % job_name)
	return []


# =============================================================================
# JOB DEFINITIONS
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
		"Fast and fragile. Rewards flanking and rear attacks."
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
		"Balanced frontliner. Reliable melee with ranged and self-heal options."
	)


static func _white_mage() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(2, 4, 4, 5, 6, 9)
	# (WIS near cap: this is the high-magic job; room to grow to 10)
	return JobData.create(
		WHITE_MAGE, "White Mage", attrs,
		3,  # MOVE — low, positioning matters
		1,  # JUMP — fragile, not agile
		[SkillLibrary.STAFF_BONK, SkillLibrary.CURE, SkillLibrary.PROTECT],
		Color(0.95, 0.95, 0.95),  # near-white
		"Backline healer and buffer. Keep them out of melee."
	)


# =============================================================================
# DARK MAGE (starter)
# =============================================================================
## ATTRIBUTE SPREAD: offensive magic specialist. High CHA and WIS for damage,
## near-zero STR. Unlike White Mage, Dark Mage attacks from the start via
## Dark Orb (ap_cost=0) — limited by MP rather than AP investment.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=30, MP=50, ATK=8, DEF=4, MAG=26, RES=10, SPD=12, MOVE=3, JUMP=1
##
## COMBAT MATH SANITY CHECK:
##   Dark Orb flank (MAG=26): int(26*1.0*1.0) - RES = 26-RES (cheap, reliable)
##     vs Squire (RES=7): 19 dmg, ~3 orbs to kill (50 HP), uses 9 MP
##   Void Blast flank: int(26*1.8*1.0) - RES = 47-RES → vs Squire: 40 dmg → 2-shot
##   Enemy Squire → Dark Mage: max(1, 17-4) = 13 dmg → ~3 hits to kill (30 HP)
static func _dark_mage() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(2, 4, 3, 8, 4, 9)
	return JobData.create(
		DARK_MAGE, "Dark Mage", attrs,
		3,  # MOVE — backline spellcaster
		1,  # JUMP — fragile, stays on flat ground
		[SkillLibrary.DARK_ORB, SkillLibrary.VOID_BLAST, SkillLibrary.CURSE],
		Color(0.4, 0.1, 0.6),   # deep indigo-purple
		"Offensive spellcaster. Attacks at range from the start; limited by MP."
	)


# =============================================================================
# ARCHER (starter)
# =============================================================================
## ATTRIBUTE SPREAD: high DEX for speed and damage, solid CON for survivability.
## No melee skill — arrow_shot has min_range=2, forcing distance management.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=40, MP=25, ATK=15, DEF=6, MAG=11, RES=6, SPD=24, MOVE=4, JUMP=2
##
## COMBAT MATH SANITY CHECK:
##   Arrow Shot flank (ATK=15): int(15*0.9*1.0) - DEF = 14-DEF
##     vs Squire (DEF=10): 4 dmg (poor front), vs Rogue (DEF=5): 8 dmg — chip damage
##   Arrow Shot REAR: int(15*0.9*1.5) - DEF = 20-DEF → vs Rogue: 15 dmg → 2 shots
##   Power Shot REAR: int(15*1.5*1.5) - DEF = 34-DEF → vs Rogue: 29 dmg → kills (30 HP)
##   Squire → Archer (melee): max(1, 17-6) = 11 dmg → ~4 hits (40 HP) — must kite
static func _archer() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(3, 9, 5, 3, 6, 4)
	return JobData.create(
		ARCHER, "Archer", attrs,
		4,  # MOVE — mobile enough to kite
		2,  # JUMP — moderate elevation access
		[SkillLibrary.ARROW_SHOT, SkillLibrary.POWER_SHOT, SkillLibrary.RAIN_OF_ARROWS],
		Color(0.3, 0.7, 0.3),   # forest green
		"Ranged specialist. Cannot attack adjacent tiles — must maintain distance."
	)


# =============================================================================
# SOLDIER (advanced — unlocks from Squire at 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: heavy frontliner. High STR and CON, low DEX and LCK.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=55, MP=30, ATK=19, DEF=12, MAG=13, RES=9, SPD=9, MOVE=4, JUMP=3
##
## COMBAT MATH SANITY CHECK:
##   Soldier basic_attack → Rogue:  max(1, 19 -  5) = 14 dmg → ~3 hits (30 HP)
##   Soldier power_strike → Squire: max(1, 19 - 10) * 1.6 = 14 dmg → ~4 hits (50 HP)
##   Soldier cleave → 3 rogues:     14 dmg each in one action (devastating)
static func _soldier() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(8, 3, 8, 3, 3, 5)
	return JobData.create(
		SOLDIER, "Soldier", attrs,
		4,  # MOVE — standard, not a runner
		3,  # JUMP — armored but agile enough for terrain
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.POWER_STRIKE, SkillLibrary.CLEAVE],
		Color(0.7, 0.6, 0.4),   # warm brown/tan — plate armor
		"Heavy frontliner. Dominates melee with high damage and AoE sweeps."
	)


# =============================================================================
# KNIGHT (advanced — unlocks from Squire at 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: maximum tank. High CON for HP and DEF, low DEX = slowest.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=65, MP=35, ATK=16, DEF=13, MAG=15, RES=11, SPD=6, MOVE=3, JUMP=2
##
## COMBAT MATH SANITY CHECK:
##   Knight shield_bash → Rogue:   max(1, 16*1.3 - 5) ≈ 16 dmg → ~2 hits (30 HP)
##   Rogue basic_attack → Knight:  max(1, 16 - 13) = 3 dmg → ~22 hits (65 HP)
##   Knight rally on Squire:       15 * 0.8 = 12 HP restored per cast
static func _knight() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(7, 2, 10, 3, 2, 6)
	return JobData.create(
		KNIGHT, "Knight", attrs,
		3,  # MOVE — slow in plate armor
		2,  # JUMP — heavy armor limits vertical mobility
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.SHIELD_BASH, SkillLibrary.RALLY],
		Color(0.55, 0.65, 0.85),  # steel blue
		"Armored tank and rally point. Highest HP and DEF; can spot-heal nearby allies."
	)


# =============================================================================
# ASSASSIN (advanced — unlocks from Rogue at 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: extreme DEX and LCK for speed, almost no CON. Must kill
## before being killed — the lowest HP and DEF of any job.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=25, MP=20, ATK=20, DEF=5, MAG=9, RES=4, SPD=24, MOVE=5, JUMP=3
##
## COMBAT MATH SANITY CHECK:
##   Assassin assassinate REAR on Squire: int(20*1.0*2.5*1.5)-10 = 65 dmg → kills (50 HP)
##   Assassin assassinate REAR on Knight: int(20*1.0*2.5*1.5)-13 = 62 dmg → kills (65 HP)
##   Rogue basic_attack → Assassin: max(1, 16-5) = 11 dmg → ~3 hits (25 HP) — dies fast
##   Assassin shadow_strike (range): int(20*0.9*1.0)-10 = 8 dmg — safe but weak
static func _assassin() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(6, 8, 2, 3, 8, 3)
	return JobData.create(
		ASSASSIN, "Assassin", attrs,
		5,  # MOVE — equal to Rogue, maximum mobility
		3,  # JUMP — superior vertical (flanks from elevation)
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.ASSASSINATE, SkillLibrary.SHADOW_STRIKE],
		Color(0.2, 0.15, 0.3),   # deep dark purple
		"Glass cannon. Highest ATK and SPD; lowest HP. Kill first or die first."
	)


# =============================================================================
# NINJA (advanced — unlocks from Rogue at 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: maximum DEX and LCK for speed, minimal STR. Not a burst
## killer — harasses at any range and disrupts with Smoke Bomb.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=30, MP=15, ATK=16, DEF=4, MAG=8, RES=3, SPD=28, MOVE=5, JUMP=3
##
## COMBAT MATH SANITY CHECK:
##   Ninja shuriken → Squire: max(1, int(16*0.8*1.0)-10) = 3 dmg (front, safe chip)
##   Ninja shuriken → Squire: max(1, int(16*0.8*1.5)-10) = 9 dmg (rear, much better)
##   Ninja basic_attack → Rogue: max(1, 16-5) = 11 dmg → ~3 hits (30 HP)
##   Note: Ninja outpaces every unit — SPD=28 gets more turns than anyone.
static func _ninja() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(3, 10, 3, 4, 8, 2)
	return JobData.create(
		NINJA, "Ninja", attrs,
		5,  # MOVE — equal to Rogue and Assassin
		3,  # JUMP — agile, climbs well
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.SHURIKEN, SkillLibrary.SMOKE_BOMB],
		Color(0.85, 0.2, 0.2),   # crimson red
		"Speed specialist. Fastest unit; harasses from any range and disrupts with smoke."
	)


# =============================================================================
# BISHOP (advanced — unlocks from White Mage at 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: WIS capped at 10 for maximum MAG and MP. Lowest ATK in
## the game, but the highest MAG makes Holy a genuine threat.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=35, MP=55, ATK=5, DEF=5, MAG=27, RES=12, SPD=11, MOVE=3, JUMP=2
##
## COMBAT MATH SANITY CHECK:
##   Curaga CROSS (MAG=27): 27 * 2.5 = 67 HP per hit — full-heals any non-Knight
##   Holy rear on Rogue (RES=5): int(27*1.8*1.5) - 5 = 68 dmg → overkill
##   Holy front on Squire (RES=7): int(27*1.8*0.75) - 7 = 29 dmg → 2-shot (50 HP)
##   Enemy Squire → Bishop: max(1, 17-5) = 12 dmg → ~3 hits (35 HP) — fragile
static func _bishop() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(1, 3, 4, 7, 5, 10)
	return JobData.create(
		BISHOP, "Bishop", attrs,
		3,  # MOVE — still a backline job
		2,  # JUMP — slightly better than White Mage
		[SkillLibrary.STAFF_BONK, SkillLibrary.CURAGA, SkillLibrary.HOLY],
		Color(0.95, 0.85, 0.3),   # golden — holy order
		"Combat priest. Heals groups with Curaga and punishes enemies with Holy."
	)


# =============================================================================
# TIME MAGE (advanced — unlocks from White Mage at 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: high WIS for MAG and MP, elevated DEX/LCK for speed above
## other mages. More mobile than Bishop in turn order, less raw MAG.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=30, MP=50, ATK=7, DEF=3, MAG=24, RES=10, SPD=16, MOVE=3, JUMP=1
##
## COMBAT MATH SANITY CHECK:
##   Meteor CROSS flank (MAG=24): int(24*1.3*1.0)-RES = 31-RES per target
##     vs Squire (RES=7): 24 dmg each — up to 5 targets in CROSS
##     vs Rogue  (RES=5): 26 dmg each — nearly kills in one cast
##   Slow: stub only — shows "SLOW!" floating text until status system lands
static func _time_mage() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(1, 5, 3, 6, 6, 9)
	return JobData.create(
		TIME_MAGE, "Time Mage", attrs,
		3,  # MOVE — backline, same as Bishop
		1,  # JUMP — fragile, stays flat
		[SkillLibrary.STAFF_BONK, SkillLibrary.SLOW, SkillLibrary.METEOR],
		Color(0.3, 0.75, 0.9),   # cool cyan-blue — temporal energy
		"AoE magic bomber. Slows enemies and drops Meteor on clustered groups."
	)


# =============================================================================
# PALADIN (cross-tree — requires Knight 1500 AP + White Mage 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: balanced tank/mage hybrid. Enough CON for solid HP and DEF;
## enough WIS for meaningful healing; strong STR for melee presence.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=55, MP=35, ATK=16, DEF=11, MAG=17, RES=10, SPD=6, MOVE=3, JUMP=2
##
## COMBAT MATH SANITY CHECK:
##   Divine Blade flank (MAG=17): int(17*1.4*1.0) - RES = 24-RES (bypasses armor)
##     vs Ninja (RES=3): 21 dmg → 2 hits (30 HP)
##   Lay on Hands (MAG=17): 17 * 3.0 = 51 HP — restores nearly full health
##   Enemy Squire → Paladin: max(1, 17-11) = 6 dmg → 9+ hits to kill — hardest to kill
static func _paladin() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(7, 2, 8, 5, 2, 6)
	return JobData.create(
		PALADIN, "Paladin", attrs,
		3,  # MOVE — slow but deliberate
		2,  # JUMP — armored, moderate elevation
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.DIVINE_BLADE, SkillLibrary.LAY_ON_HANDS],
		Color(1.0, 0.95, 0.6),   # radiant gold-white
		"Holy warrior. Second-tankiest job with magic melee and powerful self-heal."
	)


# =============================================================================
# SHADOW (cross-tree — requires Assassin 1500 AP + Ninja 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: extreme DEX and LCK. Fastest unit in the game (SPD=29),
## lowest DEF of any job. Death Blow from rear is a guaranteed kill.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=25, MP=15, ATK=18, DEF=3, MAG=7, RES=3, SPD=29, MOVE=5, JUMP=3
##
## COMBAT MATH SANITY CHECK:
##   Death Blow REAR (ATK=18): int(18*1.0*4.0*1.5) - DEF = 108-DEF → kills everything
##   Chain Shuriken flank (ATK=18): int(18*0.7*1.0) - DEF = 13-DEF per tile (AoE)
##   Enemy basic_attack → Shadow: max(1, 17-3) = 14 dmg → 2 hits to kill (25 HP)
##   Shadow must act before retaliation — SPD=29 makes that very likely.
static func _shadow() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(4, 10, 2, 3, 9, 2)
	return JobData.create(
		SHADOW, "Shadow", attrs,
		5,  # MOVE — full rogue mobility
		3,  # JUMP — superior vertical access
		[SkillLibrary.BASIC_ATTACK, SkillLibrary.DEATH_BLOW, SkillLibrary.CHAIN_SHURIKEN],
		Color(0.1, 0.1, 0.15),   # near-black
		"Apex assassin. Fastest unit alive; Death Blow from behind kills anything."
	)


# =============================================================================
# SAGE (cross-tree — requires White Mage 1500 AP + Time Mage 1500 AP)
# =============================================================================
## ATTRIBUTE SPREAD: maximum WIS and CHA. Highest MAG in the game (28).
## Fragile body but the most powerful spells available.
## DERIVED STAT PREVIEW (via StatFormulas):
##   HP=30, MP=55, ATK=5, DEF=4, MAG=28, RES=11, SPD=11, MOVE=3, JUMP=1
##
## COMBAT MATH SANITY CHECK:
##   Flare CROSS flank (MAG=28): int(28*1.6*1.0) - RES = 45-RES per tile
##     vs Squire (RES=7): 38 dmg each — kills in 2 casts across the whole group
##   Full Cure CROSS (MAG=28): 28 * 3.0 = 84 HP — full-heals any unit in range
##   Both cost 10 MP: Sage can cast ~5 Flares or ~5 Full Cures before running dry
static func _sage() -> JobData:
	#              STR  DEX  CON  CHA  LCK  WIS  = 30
	var attrs := BaseAttributes.create(1, 3, 3, 8, 5, 10)
	return JobData.create(
		SAGE, "Sage", attrs,
		3,  # MOVE — still a backline mage
		1,  # JUMP — physically fragile, stays on flat ground
		[SkillLibrary.STAFF_BONK, SkillLibrary.FLARE, SkillLibrary.FULL_CURE],
		Color(0.6, 0.3, 0.9),   # deep violet — ancient arcane mastery
		"Master mage. Highest MAG in the game; nukes groups with Flare or heals with Full Cure."
	)
