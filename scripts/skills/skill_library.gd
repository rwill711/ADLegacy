class_name SkillLibrary
## Factory for Alpha's skill set. Returns fresh SkillData instances on demand.
##
## In Alpha, skills are code-authored here for speed of iteration. Once we're
## past Alpha, these move to res://data/skills/*.tres files authored in the
## editor. The JobData → skill_names → SkillData lookup contract does not
## change; only the storage backend does.
##
## ADR-006: Every skill now carries an ap_cost for the job progression system.
##   ap_cost = 0  → innate (always known, no AP needed)
##   ap_cost > 0  → must be learned via AP accumulation while the parent job
##                  is active. Starter skills: 50–100 AP. Advanced: 150–300.
##
## AP ECONOMY REFERENCE (10 AP per battle baseline):
##   50 AP  = ~5 battles to master  (basic utility)
##   75 AP  = ~8 battles            (core identity skill)
##   100 AP = ~10 battles           (high-value ability)


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


## --- Lookup -----------------------------------------------------------------
## Return a SkillData for the given skill name, or null if unknown.
## Each call returns a FRESH instance so downstream mutation (e.g. a buffed
## power from a passive) doesn't bleed between casters.
static func get_skill(skill_name: StringName) -> SkillData:
	match skill_name:
		BASIC_ATTACK: return _basic_attack()
		BACKSTAB:     return _backstab()
		STEAL:        return _steal()
		FIRST_AID:    return _first_aid()
		STONE_THROW:  return _stone_throw()
		STAFF_BONK:   return _staff_bonk()
		CURE:         return _cure()
		PROTECT:      return _protect()
		CHOP:         return _chop()
		PUSH_ROCK:    return _push_rock()
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
# STARTER JOB SKILLS
# =============================================================================

## Universal basic attack — every job has it. Melee, 1 range, physical.
## Power ~1.0 means damage roughly equals the attacker's ATK stat minus DEF,
## modulated by facing.
## ap_cost: 0 (innate — always available on any job that lists it)
static func _basic_attack() -> SkillData:
	return SkillData.create(
		BASIC_ATTACK, "Attack",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.0, 0,
		"Standard weapon strike.",
		0  # innate
	)


## Rogue signature. Rewards positional play.
## ap_cost: 75 — core identity skill, ~8 battles to master.
static func _backstab() -> SkillData:
	var s := SkillData.create(
		BACKSTAB, "Backstab",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 1.2, 0,
		"Strike. Deals massive extra damage when attacking from behind.",
		75
	)
	s.requires_rear_for_bonus = true
	s.rear_bonus_multiplier = 2.0
	return s


## Steal an item/consumable. Non-damaging — FOIL tracks this as item_use.
## ap_cost: 75 — same tier as Backstab, defines the Rogue's utility angle.
static func _steal() -> SkillData:
	return SkillData.create(
		STEAL, "Steal",
		SkillEnums.SkillType.STEAL,
		SkillEnums.TargetType.ENEMY,
		1, 1, 0.0, 0,
		"Attempt to take an item from the target. No damage.",
		75
	)


## Squire's self-heal. Small, reliable, free.
## ap_cost: 50 — basic utility, ~5 battles.
static func _first_aid() -> SkillData:
	return SkillData.create(
		FIRST_AID, "First Aid",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.SELF,
		0, 0, 1.5, 0,
		"Bandage your wounds. Restores a small amount of HP.",
		50
	)


## Squire ranged option. Low damage, good range.
## ap_cost: 50 — basic utility.
static func _stone_throw() -> SkillData:
	return SkillData.create(
		STONE_THROW, "Stone Throw",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		2, 3, 0.7, 0,
		"Hurl a stone at a distant enemy. Low damage but 3-tile range.",
		50
	)


## Weak staff swing — White Mage's last-ditch melee when out of MP.
## ap_cost: 0 (innate — WM always has this fallback)
static func _staff_bonk() -> SkillData:
	return SkillData.create(
		STAFF_BONK, "Staff Strike",
		SkillEnums.SkillType.PHYSICAL_DAMAGE,
		SkillEnums.TargetType.ENEMY,
		1, 1, 0.6, 0,
		"Whack with your staff. Weak but doesn't cost MP.",
		0  # innate
	)


## White Mage core heal. High value, costs MP.
## ap_cost: 100 — high-value ability, ~10 battles.
static func _cure() -> SkillData:
	return SkillData.create(
		CURE, "Cure",
		SkillEnums.SkillType.HEALING,
		SkillEnums.TargetType.ALLY_OR_SELF,
		1, 4, 2.0, 4,
		"Restore HP to an ally within 4 tiles.",
		100
	)


## White Mage defensive buff. Expensive MP, big impact.
## ap_cost: 100 — same tier as Cure.
static func _protect() -> SkillData:
	return SkillData.create(
		PROTECT, "Protect",
		SkillEnums.SkillType.BUFF,
		SkillEnums.TargetType.ALLY_OR_SELF,
		1, 4, 1.0, 6,
		"Raise an ally's Defense for several turns.",
		100
	)


## Cut down an adjacent tree, clearing the tile for movement.
## ap_cost: 50 — basic terrain utility.
static func _chop() -> SkillData:
	var s := SkillData.create(
		CHOP, "Chop",
		SkillEnums.SkillType.TERRAIN_MODIFY,
		SkillEnums.TargetType.TILE,
		1, 1, 0.0, 0,
		"Chop down an adjacent tree, clearing the tile.",
		50
	)
	s.required_terrain = GridEnums.TerrainType.FOREST
	return s


## Push an adjacent rock one tile forward (in the direction from caster to rock).
## Fails silently if the destination is blocked.
## ap_cost: 50 — basic terrain utility.
static func _push_rock() -> SkillData:
	var s := SkillData.create(
		PUSH_ROCK, "Push Rock",
		SkillEnums.SkillType.TERRAIN_MODIFY,
		SkillEnums.TargetType.TILE,
		1, 1, 0.0, 0,
		"Shove an adjacent rock one tile in the direction you're pushing.",
		50
	)
	s.required_terrain = GridEnums.TerrainType.MOUNTAIN
	return s
