class_name AbilityResolver
## Pure-logic ability resolution. Takes a caster, skill, anchor coord, and
## the current roster; mutates target units' stats and returns a structured
## result. UI, animations, sound, and FOIL logging are the caller's job —
## the resolver only touches game state.
##
## Facing modifiers (CD roadmap, first-pass tuning):
##   Front = 0.75x  (defender is facing the attacker head-on)
##   Flank = 1.0x   (attacker is on the defender's side)
##   Rear  = 1.5x   (attacker is behind the defender)
## Backstab's `rear_bonus_multiplier` stacks ON TOP of the rear modifier
## when fired from behind, so a rear backstab lands at 1.5 × 2.0 = 3.0x.


const FRONT_MOD: float = 0.75
const FLANK_MOD: float = 1.0
const REAR_MOD: float = 1.5


# =============================================================================
# PUBLIC API
# =============================================================================

## Resolve `skill` cast by `caster` anchored at `anchor`. Applies damage / heal /
## (stub) buff effects to every affected unit. Returns a Dictionary describing
## what happened; caller routes this to floating text, FOIL, and debug log.
##
## Return shape:
##   {
##     "caster_id": StringName,
##     "skill_name": StringName,
##     "skill_type": int,
##     "anchor_coord": Vector2i,
##     "mp_spent": int,
##     "mp_paid": bool,        # false if caster couldn't afford the skill
##     "effects": Array[Dictionary],
##     "turn_number": int,
##   }
##
## Each entry in "effects":
##   {
##     "target_id": StringName,
##     "target_coord": Vector2i,
##     "damage": int,
##     "heal": int,
##     "was_kill": bool,
##     "was_hit": bool,        # Alpha = always true (CD Q2 ruling)
##     "side": int,            # 0=front, 1=flank, 2=rear
##     "buff_label": String,   # stub — status system is post-Alpha
##   }
static func resolve(
	caster: Unit,
	skill: SkillData,
	anchor: Vector2i,
	grid: BattleGrid,
	all_units: Array,
	turn_number: int
) -> Dictionary:
	var result: Dictionary = {
		"caster_id": caster.unit_id if caster != null else &"",
		"skill_name": skill.skill_name if skill != null else &"",
		"skill_type": int(skill.skill_type) if skill != null else -1,
		"anchor_coord": anchor,
		"mp_spent": 0,
		"mp_paid": false,
		"effects": [],
		"turn_number": turn_number,
	}
	if caster == null or skill == null or grid == null:
		return result

	# MP check — if we can't afford it, bail before mutating state.
	if not caster.spend_mp(skill.mp_cost):
		return result
	result["mp_paid"] = true
	result["mp_spent"] = skill.mp_cost

	# Expand AoE then filter to valid hit targets.
	var coords: Array = Targeting.expand_area(skill, anchor, grid)
	for coord in coords:
		var target := _unit_at(grid, all_units, coord)
		if target == null or not target.is_alive():
			continue
		if not _is_valid_hit(caster, target, skill):
			continue

		var effect: Dictionary = _apply_one(caster, skill, target)
		result["effects"].append(effect)

	return result


# =============================================================================
# PER-TARGET EFFECT APPLICATION
# =============================================================================

static func _apply_one(caster: Unit, skill: SkillData, target: Unit) -> Dictionary:
	var effect: Dictionary = {
		"target_id": target.unit_id,
		"target_coord": target.coord,
		"damage": 0,
		"heal": 0,
		"was_kill": false,
		"was_hit": true,
		"side": 1,
		"buff_label": "",
	}

	match skill.skill_type:
		SkillEnums.SkillType.PHYSICAL_DAMAGE:
			_apply_damage(caster, skill, target, effect, caster.stats.attack, target.stats.defense)
		SkillEnums.SkillType.MAGIC_DAMAGE:
			_apply_damage(caster, skill, target, effect, caster.stats.magic, target.stats.resistance)
		SkillEnums.SkillType.HEALING:
			var amount: int = int(float(caster.stats.magic) * skill.power)
			var healed: int = target.heal(amount)
			effect["heal"] = healed
		SkillEnums.SkillType.BUFF:
			# Minimal stub. Phase 4/5 wires a StatusEffect system; for now we
			# just surface the label so floating text can show "PROTECT!".
			effect["buff_label"] = skill.display_name
		SkillEnums.SkillType.DEBUFF:
			effect["buff_label"] = skill.display_name + " (Debuff)"
		SkillEnums.SkillType.STEAL:
			# No real inventory yet. Mark as an attempted steal; damage = 0.
			effect["buff_label"] = "STEAL"
		SkillEnums.SkillType.MOVEMENT:
			pass
	return effect


static func _apply_damage(
	caster: Unit,
	skill: SkillData,
	target: Unit,
	effect: Dictionary,
	attack_stat: int,
	defense_stat: int
) -> void:
	var side: int = UnitEnums.attack_side(caster.coord, target.coord, target.facing)
	effect["side"] = side

	var facing_mod: float = _side_modifier(side)
	var base: float = float(attack_stat) * skill.power

	# Backstab-style "bonus only from rear" modifier stacks on top of the
	# standard facing mod — a rear backstab with x2 rear_bonus yields
	# 1.5 × 2.0 = 3.0x of the base stat.
	if side == 2 and skill.requires_rear_for_bonus:
		base *= skill.rear_bonus_multiplier

	var damage: int = maxi(1, int(base * facing_mod) - defense_stat)
	target.take_damage(damage)

	effect["damage"] = damage
	effect["was_kill"] = not target.is_alive()


# =============================================================================
# PREDICATES / HELPERS
# =============================================================================

static func _is_valid_hit(caster: Unit, target: Unit, skill: SkillData) -> bool:
	var is_self: bool = (target.unit_id == caster.unit_id)
	return skill.can_target(caster.team, target.team, is_self)


static func _side_modifier(side: int) -> float:
	match side:
		0: return FRONT_MOD
		1: return FLANK_MOD
		2: return REAR_MOD
	return FLANK_MOD


static func _unit_at(grid: BattleGrid, all_units: Array, coord: Vector2i) -> Unit:
	var tile := grid.get_tile(coord)
	if tile == null or tile.occupant_id == &"":
		return null
	for unit in all_units:
		if unit != null and unit.unit_id == tile.occupant_id:
			return unit
	return null
