class_name ItemData extends Resource
## Base data definition for any item — equipment or consumable.
##
## Equipment items provide passive stat modifiers while worn.
## Consumable items are used from inventory during battle for instant effects.
##
## MODIFIER DESIGN:
## Equipment modifiers are flat additive bonuses to DERIVED stats (the ones
## on UnitStats: max_hp, attack, defense, etc.), NOT to base attributes.
## This keeps the standard-array invariant intact and makes the bonus
## immediately readable: "+2 defense" means exactly +2 on the stat sheet.
##
## Attribute bonuses (like +1 CON) are stored as attribute_modifiers and
## trigger a full stat re-derivation when equipped, so they ripple through
## every formula that reads that attribute. This is the more powerful
## (and rarer) bonus type.


## --- Identity ---------------------------------------------------------------
@export var item_name: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var item_type: ItemEnums.ItemType = ItemEnums.ItemType.EQUIPMENT
@export var rarity: ItemEnums.Rarity = ItemEnums.Rarity.COMMON


## --- Equipment fields -------------------------------------------------------
## Which slot this item occupies. Only meaningful if item_type == EQUIPMENT.
@export var equip_slot: ItemEnums.EquipSlot = ItemEnums.EquipSlot.BODY

## Flat bonuses to BASE ATTRIBUTES. When equipped, these are added to the
## unit's base_attributes copy, and stats are re-derived via StatFormulas.
## Keys: "strength", "dexterity", "constitution", "charisma", "luck", "wisdom"
## Values: int (can be negative for cursed items, but not in Alpha).
##
## Example: {"constitution": 1} means +1 CON → +5 max HP, +1 DEF, etc.
@export var attribute_modifiers: Dictionary = {}

## Flat bonuses to DERIVED STATS. Applied after re-derivation as a simple
## additive layer. Use this for targeted bonuses like "+2 speed" that
## shouldn't ripple through attribute formulas.
## Keys: "max_hp", "max_mp", "attack", "defense", "magic", "resistance",
##        "speed", "move_range", "jump"
## Values: int
@export var stat_modifiers: Dictionary = {}

## Job restrictions. Empty array = equippable by anyone.
## Contains StringNames matching JobLibrary constants (e.g., &"rogue").
@export var job_restrictions: Array = []


## --- Consumable fields ------------------------------------------------------
## Only meaningful if item_type == CONSUMABLE.
@export var consumable_effect: ItemEnums.ConsumableEffect = ItemEnums.ConsumableEffect.RESTORE_HP

## The magnitude of the effect (HP restored, MP restored, etc.).
## For REVIVE, this is the fraction of max HP restored (0.5 = 50%).
@export var effect_value: float = 0.0

## Range in tiles for using this consumable on another unit. 0 = self only.
@export var use_range: int = 1


# =============================================================================
# QUERIES
# =============================================================================

func is_equipment() -> bool:
	return item_type == ItemEnums.ItemType.EQUIPMENT


func is_consumable() -> bool:
	return item_type == ItemEnums.ItemType.CONSUMABLE


## Can this equipment be worn by the given job? Empty restrictions = universal.
func can_equip(job_name: StringName) -> bool:
	if job_restrictions.is_empty():
		return true
	return job_restrictions.has(job_name)


## Total attribute modifier sum (for UI: "how impactful is this item?").
func get_attribute_modifier_total() -> int:
	var total: int = 0
	for key in attribute_modifiers:
		total += int(attribute_modifiers[key])
	return total


## Total stat modifier sum.
func get_stat_modifier_total() -> int:
	var total: int = 0
	for key in stat_modifiers:
		total += int(stat_modifiers[key])
	return total


## Human-readable summary of all modifiers for tooltips.
func get_modifier_summary() -> String:
	var parts: Array = []
	for key in attribute_modifiers:
		var val: int = int(attribute_modifiers[key])
		if val != 0:
			parts.append("%+d %s" % [val, key.to_upper().left(3)])
	for key in stat_modifiers:
		var val: int = int(stat_modifiers[key])
		if val != 0:
			parts.append("%+d %s" % [val, key])
	if parts.is_empty():
		return "No bonuses"
	return ", ".join(parts)


# =============================================================================
# FACTORIES
# =============================================================================

## Create an equipment item.
static func create_equipment(
	p_name: StringName,
	p_display_name: String,
	p_slot: ItemEnums.EquipSlot,
	p_attribute_mods: Dictionary = {},
	p_stat_mods: Dictionary = {},
	p_job_restrictions: Array = [],
	p_description: String = "",
	p_rarity: ItemEnums.Rarity = ItemEnums.Rarity.COMMON
) -> ItemData:
	var item := ItemData.new()
	item.item_name = p_name
	item.display_name = p_display_name
	item.item_type = ItemEnums.ItemType.EQUIPMENT
	item.equip_slot = p_slot
	item.attribute_modifiers = p_attribute_mods
	item.stat_modifiers = p_stat_mods
	item.job_restrictions = p_job_restrictions
	item.description = p_description
	item.rarity = p_rarity
	return item


## Create a consumable item.
static func create_consumable(
	p_name: StringName,
	p_display_name: String,
	p_effect: ItemEnums.ConsumableEffect,
	p_value: float,
	p_range: int = 1,
	p_description: String = "",
	p_rarity: ItemEnums.Rarity = ItemEnums.Rarity.COMMON
) -> ItemData:
	var item := ItemData.new()
	item.item_name = p_name
	item.display_name = p_display_name
	item.item_type = ItemEnums.ItemType.CONSUMABLE
	item.consumable_effect = p_effect
	item.effect_value = p_value
	item.use_range = p_range
	item.description = p_description
	item.rarity = p_rarity
	return item
