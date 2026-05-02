class_name SkillData extends Resource
## Data definition for a single ability.
## Per Creative Director: "Every skill we add later should just be data, not new code."
## This resource IS the full contract — targeting, resolution, UI, and FOIL
## tracking all read from these fields.
##
## ADR-006 addition: ap_cost field for job progression mastery.


## --- Identity ---------------------------------------------------------------
@export var skill_name: StringName = &""
@export var display_name: String = ""
@export var description: String = ""


## --- Effect -----------------------------------------------------------------
@export var skill_type: SkillEnums.SkillType = SkillEnums.SkillType.PHYSICAL_DAMAGE

## Multiplier applied to the attacker's relevant stat in the damage/heal
## formula. 1.0 = baseline weapon swing. Higher = more powerful.
@export var power: float = 1.0

## MP cost. 0 = free action.
@export var mp_cost: int = 0


## --- Progression (ADR-006) --------------------------------------------------
## AP required to master this skill. Once a unit accumulates this much AP
## while their current job lists this skill as learnable, the skill is
## permanently mastered.
## 0 = innate / always known (e.g., basic Attack on every job).
@export var ap_cost: int = 0


## --- Targeting --------------------------------------------------------------
@export var target_type: SkillEnums.TargetType = SkillEnums.TargetType.ENEMY

## Inclusive range in tiles (manhattan distance).
## min_range 1 + max_range 1 = melee only.
## min_range 2 + max_range 4 = bow that can't shoot adjacent tiles.
@export var min_range: int = 1
@export var max_range: int = 1

## Area of effect around the target tile. SINGLE for point-target skills.
@export var area_shape: SkillEnums.AreaShape = SkillEnums.AreaShape.SINGLE
@export var area_size: int = 0


## --- Conditions -------------------------------------------------------------
## If true, this skill's bonus triggers ONLY when the attacker is behind the
## target. Used by Backstab. Hit-from-front still legal, just no bonus.
@export var requires_rear_for_bonus: bool = false

## Extra damage multiplier applied when rear-condition is met.
## Ignored unless requires_rear_for_bonus is true.
@export var rear_bonus_multiplier: float = 1.0


## --- Terrain requirement (TERRAIN_MODIFY skills only) -----------------------
## For TILE-targeted terrain skills: only tiles with this terrain are valid.
## -1 means no terrain restriction.
@export var required_terrain: int = -1

## --- Element (future) -------------------------------------------------------
@export var element: SkillEnums.Element = SkillEnums.Element.NONE


# =============================================================================
# QUERIES
# =============================================================================

func is_offensive() -> bool:
	return SkillEnums.is_offensive(skill_type)


func is_support() -> bool:
	return SkillEnums.is_support(skill_type)


func is_melee_only() -> bool:
	return max_range <= 1


func foil_category() -> FOILEnums.SkillCategory:
	return SkillEnums.to_foil_category(skill_type)


## Whether this skill hits multiple tiles in one cast. Used by FOIL's
## AOE-tendency stat and by the targeting preview.
func is_area() -> bool:
	return area_shape != SkillEnums.AreaShape.SINGLE or area_size > 0


## Whether this skill is innate (no AP cost, always available).
func is_innate() -> bool:
	return ap_cost <= 0


## Can this skill legally target `target_unit` given the caster's team?
## Teams are compared to determine hostile-vs-friendly.
## Same-tile targeting (SELF) requires caster == target.
func can_target(
	caster_team: UnitEnums.Team,
	target_team: UnitEnums.Team,
	is_self_target: bool
) -> bool:
	match target_type:
		SkillEnums.TargetType.ENEMY:
			return UnitEnums.teams_are_hostile(caster_team, target_team) and not is_self_target
		SkillEnums.TargetType.ALLY:
			return not UnitEnums.teams_are_hostile(caster_team, target_team) and not is_self_target
		SkillEnums.TargetType.SELF:
			return is_self_target
		SkillEnums.TargetType.ALLY_OR_SELF:
			return not UnitEnums.teams_are_hostile(caster_team, target_team)
		SkillEnums.TargetType.TILE:
			return false   # TILE skills don't target units
		SkillEnums.TargetType.ANY:
			return true
	return false


# =============================================================================
# FACTORY
# =============================================================================

## Convenience constructor for the skill library. Keeps static-builder code
## terse without requiring every caller to set every field explicitly.
static func create(
	p_skill_name: StringName,
	p_display_name: String,
	p_skill_type: SkillEnums.SkillType,
	p_target_type: SkillEnums.TargetType,
	p_min_range: int,
	p_max_range: int,
	p_power: float = 1.0,
	p_mp_cost: int = 0,
	p_description: String = "",
	p_ap_cost: int = 0
) -> SkillData:
	var s := SkillData.new()
	s.skill_name = p_skill_name
	s.display_name = p_display_name
	s.skill_type = p_skill_type
	s.target_type = p_target_type
	s.min_range = p_min_range
	s.max_range = p_max_range
	s.power = p_power
	s.mp_cost = p_mp_cost
	s.description = p_description
	s.ap_cost = p_ap_cost
	return s
