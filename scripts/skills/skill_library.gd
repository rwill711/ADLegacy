class_name SkillLibrary
## Factory for Alpha's skill set. Returns fresh SkillData instances on demand.
##
## In Alpha, skills are code-authored here for speed of iteration. Once we're
## past Alpha, these move to res://data/skills/*.tres files authored in the
## editor. The JobData → skill_names → SkillData lookup contract does not
## change; only the storage backend does.


## --- Skill name constants ---------------------------------------------------
## Use these StringNames everywhere instead of raw string literals so typos
## fail at compile time, not during battle.
const BASIC_ATTACK    := &"basic_attack"
const BACKSTAB        := &"backstab"
const STEAL           := &"steal"
const FIRST_AID       := &"first_aid"
const STONE_THROW     := &"stone_throw"
const STAFF_BONK      := &"staff_bonk"
const CURE            := &"cure"
const PROTECT         := &"protect"
const CHOP            := &"chop"
const PUSH_ROCK       := &"push_rock"
## Soldier
const POWER_STRIKE    := &"power_strike"
const CLEAVE          := &"cleave"
## Knight
const SHIELD_BASH     := &"shield_bash"
const RALLY           := &"rally"
## Assassin
const ASSASSINATE     := &"assassinate"
const SHADOW_STRIKE   := &"shadow_strike"
## Ninja
const SHURIKEN        := &"shuriken"
const SMOKE_BOMB      := &"smoke_bomb"
## Bishop
const CURAGA          := &"curaga"
const HOLY            := &"holy"
## Time Mage
const SLOW            := &"slow"
const METEOR          := &"meteor"
## Dark Mage
const DARK_ORB        := &"dark_orb"
const VOID_BLAST      := &"void_blast"
const CURSE           := &"curse"
## Archer
const ARROW_SHOT      := &"arrow_shot"
const POWER_SHOT      := &"power_shot"
const RAIN_OF_ARROWS  := &"rain_of_arrows"
## Paladin
const DIVINE_BLADE    := &"divine_blade"
const LAY_ON_HANDS    := &"lay_on_hands"
## Shadow
const DEATH_BLOW      := &"death_blow"
const CHAIN_SHURIKEN  := &"chain_shuriken"
## Sage
const FLARE           := &"flare"
const FULL_CURE       := &"full_cure"


## --- Lookup -----------------------------------------------------------------
## Return a SkillData for the given skill name, or null if unknown.
## Each call returns a FRESH instance so downstream mutation (e.g. a buffed
## power from a passive) doesn't bleed between casters.
static func get_skill(skill_name: StringName) -> SkillData:
	match skill_name:
		BASIC_ATTACK:  return _basic_attack()
		BACKSTAB:      return _backstab()
		STEAL:         return _steal()
		FIRST_AID:     return _first_aid()
		STONE_THROW:   return _stone_throw()
		STAFF_BONK:    return _staff_bonk()
		CURE:          return _cure()
		PROTECT:       return _protect()
		CHOP:          return _chop()
		PUSH_ROCK:     return _push_rock()
		POWER_STRIKE:  return _power_strike()
		CLEAVE:        return _cleave()
		SHIELD_BASH:   return _shield_bash()
		RALLY:         return _rally()
		ASSASSINATE:   return _assassinate()
		SHADOW_STRIKE: return _shadow_strike()
		SHURIKEN:      return _shuriken()
		SMOKE_BOMB:    return _smoke_bomb()
		CURAGA:        return _curaga()
		HOLY:          return _holy()
		SLOW:          return _slow()
		METEOR:        return _meteor()
		DARK_ORB:      return _dark_orb()
		VOID_BLAST:    return _void_blast()
		CURSE:         return _curse()
		ARROW_SHOT:    return _arrow_shot()
		POWER_SHOT:    return _power_shot()
		RAIN_OF_ARROWS: return _rain_of_arrows()
		DIVINE_BLADE:  return _divine_blade()
		LAY_ON_HANDS:  return _lay_on_hands()
		DEATH_BLOW:    return _death_blow()
		CHAIN_SHURIKEN: return _chain_shuriken()
		FLARE:         return _flare()
		FULL_CURE:     return _full_cure()
	push_warning("SkillLibrary: unknown skill '%s'" % [skill_name])
	return null


## Resolve a list of skill names into SkillData instances, skipping unknowns.
static func get_skills(skill_names: Array) -> Array:
	var out: Array = []
	for name in skill_names:
		var skill := get_skill(name)
		if skill != null:
			out.append(skill)
	return out


# =============================================================================
# ALPHA SKILL DEFINITIONS
# =============================================================================

## Universal basic attack — every job has it. Melee, 1 range, physical.
## Power ~1.0 means damage roughly equals the attacker's ATK stat minus DEF,
## modulated by facing.
static func _basic_attack() -> SkillData:
	return SkillData.create(
		BASIC_ATTACK, "Attack",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.0, 0,
		"Standard weapon strike."
	)


static func _backstab() -> SkillData:
	var s := SkillData.create(
		BACKSTAB, "Backstab",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.2, 0,
		"Strike. Deals massive extra damage when attacking from behind."
	)
	s.requires_rear_for_bonus = true
	s.rear_bonus_multiplier = 2.0
	s.ap_cost = 200
	return s


## Steal an item/consumable. Non-damaging — FOIL tracks this as item_use.
static func _steal() -> SkillData:
	var s := SkillData.create(
		STEAL, "Steal",
		SkillEnums.SkillType.STEAL,
		SkillEnums.TargetType.ENEMY,
		1, 1, 0.0, 0,
		"Attempt to take an item from the target. No damage."
	)
	s.ap_cost = 150
	return s


## Squire's self-heal. Small, reliable, free.
static func _first_aid() -> SkillData:
	var s := SkillData.create(
		FIRST_AID, "First Aid",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.SELF,
		0, 0, 1.5, 0,
		"Bandage your wounds. Restores a small amount of HP."
	)
	s.ap_cost = 150
	return s


static func _stone_throw() -> SkillData:
	var s := SkillData.create(
		STONE_THROW, "Stone Throw",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		2, 3, 0.7, 0,
		"Hurl a stone at a distant enemy. Low damage but 3-tile range."
	)
	s.ap_cost = 200
	return s


## Weak staff swing — White Mage's last-ditch melee when out of MP.
static func _staff_bonk() -> SkillData:
	return SkillData.create(
		STAFF_BONK, "Staff Strike",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 0.6, 0,
		"Whack with your staff. Weak but doesn't cost MP."
	)


static func _cure() -> SkillData:
	var s := SkillData.create(
		CURE, "Cure",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.ALLY_OR_SELF,
		1, 4, 2.0, 4,
		"Restore HP to an ally within 4 tiles."
	)
	s.ap_cost = 200
	return s


static func _protect() -> SkillData:
	var s := SkillData.create(
		PROTECT, "Protect",
		SkillEnums.SkillType.BUFF,
		SkillEnums.TargetType.ALLY_OR_SELF,
		1, 4, 1.0, 6,
		"Raise an ally's Defense for several turns."
	)
	s.ap_cost = 250
	return s


## Cut down an adjacent tree, clearing the tile for movement.
static func _chop() -> SkillData:
	var s := SkillData.create(
		CHOP, "Chop",
		SkillEnums.SkillType.TERRAIN_MODIFY,
		SkillEnums.TargetType.TILE,
		1, 1, 0.0, 0,
		"Chop down an adjacent tree, clearing the tile."
	)
	s.required_terrain = GridEnums.TerrainType.FOREST
	s.ap_cost = 100
	return s


## Push an adjacent rock one tile forward (in the direction from caster to rock).
## Fails silently if the destination is blocked.
static func _push_rock() -> SkillData:
	var s := SkillData.create(
		PUSH_ROCK, "Push Rock",
		SkillEnums.SkillType.TERRAIN_MODIFY,
		SkillEnums.TargetType.TILE,
		1, 1, 0.0, 0,
		"Shove an adjacent rock one tile in the direction you're pushing."
	)
	s.required_terrain = GridEnums.TerrainType.MOUNTAIN
	s.ap_cost = 100
	return s


# =============================================================================
# SOLDIER SKILLS
# =============================================================================

## Heavy overhead blow. High single-target damage at the cost of slow momentum.
static func _power_strike() -> SkillData:
	var s := SkillData.create(
		POWER_STRIKE, "Power Strike",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.6, 0,
		"A powerful melee blow. Deals significantly more damage than a basic attack."
	)
	s.ap_cost = 200
	return s


## Wide sweeping strike. Hits the target tile and all four adjacent tiles,
## dealing full weapon damage to each enemy caught in the arc.
static func _cleave() -> SkillData:
	var s := SkillData.create(
		CLEAVE, "Cleave",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.0, 0,
		"Sweep your weapon in a wide arc. Hits the target and all adjacent tiles."
	)
	s.area_shape = SkillEnums.AreaShape.CROSS
	s.ap_cost = 300
	return s


# =============================================================================
# KNIGHT SKILLS
# =============================================================================

## Drives a shield into the target. More damage than a basic attack but no AoE.
static func _shield_bash() -> SkillData:
	var s := SkillData.create(
		SHIELD_BASH, "Shield Bash",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.3, 0,
		"Drive your shield into an adjacent enemy. Deals more damage than a basic attack."
	)
	s.ap_cost = 200
	return s


## Minor heal on a nearby ally. Knight's WIS is modest, so this tops off
## rather than fully restoring — but it costs no MP.
static func _rally() -> SkillData:
	var s := SkillData.create(
		RALLY, "Rally",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.ALLY_OR_SELF,
		0, 2, 0.8, 0,
		"Call out to a nearby ally, restoring a small amount of HP."
	)
	s.ap_cost = 250
	return s


# =============================================================================
# ASSASSIN SKILLS
# =============================================================================

## Upgraded backstab. Stronger rear multiplier than Backstab — the advanced
## version of the concept with Assassin's higher ATK behind it.
## Rear assassinate (ATK=20): 20 * 1.0 * 2.5 * 1.5 - DEF ≈ 75 - DEF dmg.
static func _assassinate() -> SkillData:
	var s := SkillData.create(
		ASSASSINATE, "Assassinate",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.0, 0,
		"Strike a vital point. Deals massive damage when attacking from behind."
	)
	s.requires_rear_for_bonus = true
	s.rear_bonus_multiplier = 2.5
	s.ap_cost = 250
	return s


## Throw a blade from a safe distance. Requires staying 2–4 tiles out —
## the Assassin can't use this in melee, forcing a positioning choice.
static func _shadow_strike() -> SkillData:
	var s := SkillData.create(
		SHADOW_STRIKE, "Shadow Strike",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		2, 4, 0.9, 0,
		"Hurl a blade from the shadows. Must be 2–4 tiles away to use."
	)
	s.ap_cost = 200
	return s


# =============================================================================
# NINJA SKILLS
# =============================================================================

## Thrown shuriken. Works at any range including melee — cheaper and more
## flexible than Shadow Strike but lower damage per throw.
static func _shuriken() -> SkillData:
	var s := SkillData.create(
		SHURIKEN, "Shuriken",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 4, 0.8, 0,
		"Fling a throwing star. Usable at any range; cheap and quick."
	)
	s.ap_cost = 150
	return s


## Fills the area with blinding smoke. Stub in Alpha — future status system
## will apply an accuracy penalty for several turns.
static func _smoke_bomb() -> SkillData:
	var s := SkillData.create(
		SMOKE_BOMB, "Smoke Bomb",
		SkillEnums.SkillType.DEBUFF,
		SkillEnums.TargetType.ENEMY,
		1, 3, 0.0, 0,
		"Throw a smoke bomb at an enemy. Reduces their accuracy (future system)."
	)
	s.ap_cost = 200
	return s


# =============================================================================
# BISHOP SKILLS
# =============================================================================

## Group heal. Restores HP to the target and all adjacent allies — the anchor
## tile is a friendly unit, the CROSS expands outward from there.
## Curaga on any unit (MAG=27): 27 * 2.5 = 67 HP restored per target hit.
static func _curaga() -> SkillData:
	var s := SkillData.create(
		CURAGA, "Curaga",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.ALLY_OR_SELF,
		1, 4, 2.5, 6,
		"Heal an ally and all units adjacent to them."
	)
	s.area_shape = SkillEnums.AreaShape.CROSS
	s.ap_cost = 300
	return s


## Pure magical strike. Bypasses physical defense — targets resistance instead.
## Holy (MAG=27, front): int(27 * 1.8 * 0.75) - RES = ~36 - RES magic damage.
static func _holy() -> SkillData:
	var s := SkillData.create(
		HOLY, "Holy",
		SkillEnums.SkillType.MAGIC_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 5, 1.8, 8,
		"Channel sacred energy to strike an enemy with magical force."
	)
	s.ap_cost = 350
	return s


# =============================================================================
# TIME MAGE SKILLS
# =============================================================================

## Distort time around an enemy, reducing their speed. Stub in Alpha — the
## future status system will apply a SPD penalty for several turns.
static func _slow() -> SkillData:
	var s := SkillData.create(
		SLOW, "Slow",
		SkillEnums.SkillType.DEBUFF,
		SkillEnums.TargetType.ENEMY,
		1, 5, 0.0, 0,
		"Warp time around an enemy, slowing their turn rate (future system)."
	)
	s.ap_cost = 150
	return s


## A boulder of compressed gravity crashes down on the target and surrounding
## tiles. min_range=2 keeps the Time Mage safely out of melee.
## Meteor CROSS flank (MAG=24): int(24*1.3*1.0) - RES = 31-RES per target.
static func _meteor() -> SkillData:
	var s := SkillData.create(
		METEOR, "Meteor",
		SkillEnums.SkillType.MAGIC_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		2, 5, 1.3, 9,
		"Call down a meteor strike. Damages the target and all adjacent tiles."
	)
	s.area_shape = SkillEnums.AreaShape.CROSS
	s.ap_cost = 400
	return s


# =============================================================================
# DARK MAGE SKILLS
# =============================================================================

## Dark Mage's starter ranged attack. ap_cost=0 so it's always available,
## but the 3 MP cost means it can't be spammed forever — MP is the constraint.
static func _dark_orb() -> SkillData:
	return SkillData.create(
		DARK_ORB, "Dark Orb",
		SkillEnums.SkillType.MAGIC_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 4, 1.0, 3,
		"Hurl a sphere of dark energy. Cheap and reliable at range."
	)


## High-damage single-target blast. More powerful per cast than Dark Orb
## but burns through the MP pool faster.
## Void Blast flank (MAG=26): int(26*1.8*1.0) - RES = 47-RES.
static func _void_blast() -> SkillData:
	var s := SkillData.create(
		VOID_BLAST, "Void Blast",
		SkillEnums.SkillType.MAGIC_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 5, 1.8, 5,
		"Unleash a concentrated bolt of void energy. High magic damage."
	)
	s.ap_cost = 150
	return s


## Wither the target's will. Stub in Alpha — future status system will apply
## a stat penalty. Shows "CURSE!" floating text.
static func _curse() -> SkillData:
	var s := SkillData.create(
		CURSE, "Curse",
		SkillEnums.SkillType.DEBUFF,
		SkillEnums.TargetType.ENEMY,
		1, 4, 0.0, 0,
		"Curse an enemy, reducing their combat effectiveness (future system)."
	)
	s.ap_cost = 150
	return s


# =============================================================================
# ARCHER SKILLS
# =============================================================================

## Archer's core skill. ap_cost=0 and min_range=2 means Archers can always
## fire at range but cannot use this in melee — they must keep their distance.
static func _arrow_shot() -> SkillData:
	return SkillData.create(
		ARROW_SHOT, "Arrow Shot",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		2, 4, 0.9, 0,
		"Fire an arrow at a distant target. Cannot fire at adjacent tiles."
	)


## Charged shot — longer range and more damage. The Archer's main damage tool
## once unlocked.
## Power Shot flank (ATK=15): int(15*1.5*1.0) - DEF = 23-DEF.
static func _power_shot() -> SkillData:
	var s := SkillData.create(
		POWER_SHOT, "Power Shot",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		2, 5, 1.5, 0,
		"Draw back and release a powerful shot. More damage and range than Arrow Shot."
	)
	s.ap_cost = 200
	return s


## Loose a volley of arrows in a wide arc. Hits the anchor and all adjacent
## tiles — deadly against packed formations at range.
## Rain of Arrows flank (ATK=15): int(15*0.8*1.0) - DEF = 12-DEF per tile.
static func _rain_of_arrows() -> SkillData:
	var s := SkillData.create(
		RAIN_OF_ARROWS, "Rain of Arrows",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		2, 5, 0.8, 0,
		"Launch a volley of arrows. Hits the target and all adjacent tiles."
	)
	s.area_shape = SkillEnums.AreaShape.CROSS
	s.ap_cost = 300
	return s


# =============================================================================
# PALADIN SKILLS
# =============================================================================

## Enchanted weapon swing — deals magic damage from melee range, bypassing
## physical armor. Hits resistance instead of defense.
## Divine Blade flank (MAG=17): int(17*1.4*1.0) - RES = 24-RES.
static func _divine_blade() -> SkillData:
	var s := SkillData.create(
		DIVINE_BLADE, "Divine Blade",
		SkillEnums.SkillType.MAGIC_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.4, 4,
		"Strike with a weapon imbued with holy power. Ignores physical armor."
	)
	s.ap_cost = 300
	return s


## Powerful self-heal — the Paladin's signature sustain tool. Costs no AP
## once unlocked; the 5 MP cost limits overuse.
## Lay on Hands (MAG=17): 17 * 3.0 = 51 HP restored — nearly full health.
static func _lay_on_hands() -> SkillData:
	var s := SkillData.create(
		LAY_ON_HANDS, "Lay on Hands",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.SELF,
		0, 0, 3.0, 5,
		"Channel holy energy to mend your own wounds. Restores a large amount of HP."
	)
	s.ap_cost = 300
	return s


# =============================================================================
# SHADOW SKILLS
# =============================================================================

## The deadliest rear attack in the game. Combine with Shadow's SPD=29 to
## reposition behind targets before they can act.
## Death Blow rear (ATK=18): int(18*1.0*4.0*1.5) - DEF = 108-DEF. One-shots anything.
static func _death_blow() -> SkillData:
	var s := SkillData.create(
		DEATH_BLOW, "Death Blow",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.0, 0,
		"A strike aimed at a vital point. Devastating when landing from behind."
	)
	s.requires_rear_for_bonus = true
	s.rear_bonus_multiplier = 4.0
	s.ap_cost = 300
	return s


## Throw a volley of shurikens in a burst pattern — hits the target and all
## adjacent tiles. Weak per hit; strong against tight formations.
## Chain Shuriken flank (ATK=18): int(18*0.7*1.0) - DEF = 13-DEF per target.
static func _chain_shuriken() -> SkillData:
	var s := SkillData.create(
		CHAIN_SHURIKEN, "Chain Shuriken",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 4, 0.7, 0,
		"Launch a fan of throwing stars at a target and surrounding tiles."
	)
	s.area_shape = SkillEnums.AreaShape.CROSS
	s.ap_cost = 350
	return s


# =============================================================================
# SAGE SKILLS
# =============================================================================

## The most powerful offensive spell. Hits the target and all adjacent tiles
## with raw magical force — upgraded Meteor that works at any range.
## Flare CROSS flank (MAG=28): int(28*1.6*1.0) - RES = 45-RES per target.
static func _flare() -> SkillData:
	var s := SkillData.create(
		FLARE, "Flare",
		SkillEnums.SkillType.MAGIC_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 5, 1.6, 10,
		"Unleash a massive explosion of magical energy on a target and adjacent tiles."
	)
	s.area_shape = SkillEnums.AreaShape.CROSS
	s.ap_cost = 450
	return s


## Flood the battlefield with restorative energy. Heals the target and all
## adjacent allies — the Sage's MAG makes this more than a full heal.
## Full Cure CROSS (MAG=28): 28 * 3.0 = 84 HP — fully heals any unit.
static func _full_cure() -> SkillData:
	var s := SkillData.create(
		FULL_CURE, "Full Cure",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.ALLY_OR_SELF,
		0, 5, 3.0, 10,
		"Restore a massive amount of HP to an ally and all adjacent allies."
	)
	s.area_shape = SkillEnums.AreaShape.CROSS
	s.ap_cost = 450
	return s
