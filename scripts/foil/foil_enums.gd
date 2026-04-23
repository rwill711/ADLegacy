class_name FOILEnums
## Shared enums and constants for the FOIL system.

## --- FOIL Levels ---
## Determines how aggressively the CPU counters the player.
enum FOILLevel {
	OBLIVIOUS = 0,   ## No adaptation
	AWARE = 1,        ## Consumables to mitigate
	PREPARED = 2,     ## Counter jobs/skills
	STRATEGIC = 3,    ## Tactical AI adjustments
	MASTERY = 4       ## Hard-counter builds
}

## --- FOIL Level Source ---
## How the FOIL level was determined for this encounter.
enum FOILSource {
	RENOWN_CALCULATED,  ## Derived from character renown
	MISSION_OVERRIDE    ## Hard-set by story/mission data
}

## --- Archetype Tags ---
## Broad playstyle categories derived from action history and trait tags.
## A character can have multiple. Weights determine dominance.
enum Archetype {
	MELEE_AGGRO,       ## Closes distance, physical attacks
	RANGED_KITE,       ## Keeps distance, ranged attacks
	MAGIC_OFFENSE,     ## Spell damage dealer
	HEALER_SUPPORT,    ## Healing and buffs
	TANK_WALL,         ## High defense, draws aggro, blocks paths
	AOE_BLASTER,       ## Area of effect focus
	DEBUFFER,          ## Status effects and debuffs
	HYBRID             ## No clear dominant pattern
}

## --- Skill Category ---
## Simplified skill classification for FOIL tracking.
## Maps from the full SkillType but collapsed for pattern recognition.
enum SkillCategory {
	PHYSICAL_MELEE,
	PHYSICAL_RANGED,
	MAGIC_DAMAGE,
	HEALING,
	BUFF,
	DEBUFF,
	MOVEMENT_ABILITY,  ## Reposition skills, teleports, etc.
	ITEM_USE
}

## --- Rolling Window Config ---
const ROLLING_WINDOW_SIZE: int = 12
const ROLLING_WINDOW_MIN_BATTLES: int = 3  ## Minimum battles before FOIL starts adapting

## --- Renown-to-FOIL Thresholds ---
## Renown values at which FOIL level increases for free encounters.
## These are tuning knobs — will need balancing.
const RENOWN_THRESHOLDS: Dictionary = {
	0: 0,      ## Level 0: renown 0+
	1: 50,     ## Level 1: renown 50+
	2: 150,    ## Level 2: renown 150+
	3: 300,    ## Level 3: renown 300+
	4: 500     ## Level 4: renown 500+
}

## Returns the FOIL level for a given renown value.
static func foil_level_from_renown(renown: int) -> int:
	var level: int = 0
	for threshold_level in RENOWN_THRESHOLDS:
		if renown >= RENOWN_THRESHOLDS[threshold_level]:
			level = threshold_level
	return level
