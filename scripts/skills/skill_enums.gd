class_name SkillEnums
## Enums and shared lookups for the skill/ability system.
## Skills are fully data-driven — adding a new one means authoring a new
## SkillData resource, not writing code. These enums define the vocabulary
## that resolver / targeting / UI code reads.


## --- What the skill does -----------------------------------------------------
## The gameplay-effect category. Drives damage formula, whether it spends HP
## vs MP on hit, and which resist stat the target uses.
enum SkillType {
	PHYSICAL_DAMAGE,   # Uses attacker's ATK vs target's DEF
	MAGIC_DAMAGE,      # Uses attacker's MAG vs target's RES
	HEALING,           # Restores HP on an ally or self
	BUFF,              # Applies a positive status / stat change
	DEBUFF,            # Applies a negative status on an enemy
	STEAL,             # Removes an item/consumable from target
	MOVEMENT,          # Self-movement skills (teleport, dash) — no damage
}


## --- Who the skill can target ------------------------------------------------
## The targeting phase uses this to decide which tiles/units are valid picks
## given the caster's range.
enum TargetType {
	ENEMY,          # Must be a hostile unit
	ALLY,           # Must be a non-hostile unit, not self
	SELF,           # Caster only
	ALLY_OR_SELF,   # Any friendly including the caster
	TILE,           # An empty tile (for movement / ground AoE)
	ANY,            # Any unit or tile within range
}


## --- AoE shape (beyond the single anchor tile) -------------------------------
enum AreaShape {
	SINGLE,         # Just the target tile
	CROSS,          # Target + 4 orthogonal neighbors (5 tiles)
	SQUARE,         # Square of (2 * area_size + 1)^2 around target
	RADIUS,         # Manhattan-radius of `area_size` around target
	LINE,           # Line from caster through target up to `area_size` tiles
}


## --- Element slot (for future element/terrain system) ------------------------
## Not wired into damage yet — reserved so FOIL v2's elemental counter-gear
## has something to read against. All Alpha skills use NONE.
enum Element {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	EARTH,
	WATER,
	HOLY,
	DARK,
}


# =============================================================================
# HELPERS
# =============================================================================

## Offensive skills deal damage. Used by FOIL and by facing-modifier logic.
static func is_offensive(skill_type: SkillType) -> bool:
	return skill_type == SkillType.PHYSICAL_DAMAGE \
		or skill_type == SkillType.MAGIC_DAMAGE


## Support skills help allies. Healing, buffs, sometimes movement.
static func is_support(skill_type: SkillType) -> bool:
	return skill_type == SkillType.HEALING \
		or skill_type == SkillType.BUFF


## Map a SkillType into a FOIL skill category so the tracker's
## record_action() call is a one-line lookup instead of a switch at the
## call site. Keeps FOIL's vocabulary stable even when we add new
## SkillTypes later (e.g., CHARM, SUMMON) — we only need to update this
## one map, never the tracker.
const FOIL_CATEGORY_MAP: Dictionary = {
	SkillType.PHYSICAL_DAMAGE: FOILEnums.SkillCategory.PHYSICAL_MELEE,
	SkillType.MAGIC_DAMAGE:    FOILEnums.SkillCategory.MAGIC_DAMAGE,
	SkillType.HEALING:         FOILEnums.SkillCategory.HEALING,
	SkillType.BUFF:            FOILEnums.SkillCategory.BUFF,
	SkillType.DEBUFF:          FOILEnums.SkillCategory.DEBUFF,
	SkillType.STEAL:           FOILEnums.SkillCategory.ITEM_USE,
	SkillType.MOVEMENT:        FOILEnums.SkillCategory.MOVEMENT_ABILITY,
}


static func to_foil_category(skill_type: SkillType) -> FOILEnums.SkillCategory:
	return FOIL_CATEGORY_MAP.get(skill_type, FOILEnums.SkillCategory.PHYSICAL_MELEE)
