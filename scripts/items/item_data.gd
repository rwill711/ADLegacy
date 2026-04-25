class_name ItemData extends Resource
## Base data definition for any item — equipment or consumable.
##
## Equipment items provide passive stat modifiers while worn.
## Consumable items are used from inventory during battle for instant effects.
##
## Attribute bonuses (+1 CON) are stored in attribute_modifiers and trigger a
## full stat re-derivation when equipped so they ripple through every formula.
## Flat stat bonuses (+2 speed) go in stat_modifiers and are applied on top.


## --- Identity ---------------------------------------------------------------
@export var item_name: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var item_type: ItemEnums.ItemType = ItemEnums.ItemType.EQUIPMENT
@export var rarity: ItemEnums.Rarity = ItemEnums.Rarity.COMMON


## --- Equipment fields -------------------------------------------------------
@export var equip_slot: ItemEnums.EquipSlot = ItemEnums.EquipSlot.BODY
@export var weapon_hand: ItemEnums.WeaponHand = ItemEnums.WeaponHand.NONE

## Keys: "strength", "dexterity", "constitution", "charisma", "luck", "wisdom"
@export var attribute_modifiers: Dictionary = {}

## Keys: "max_hp", "max_mp", "attack", "defense", "magic", "resistance",
##        "speed", "move_range", "jump"
@export var stat_modifiers: Dictionary = {}

@export var job_restrictions: Array = []


## --- Consumable fields ------------------------------------------------------
@export var consumable_effect: ItemEnums.ConsumableEffect = ItemEnums.ConsumableEffect.RESTORE_HP
@export var effect_value: float = 0.0
@export var use_range: int = 1


# =============================================================================
# QUERIES
# =============================================================================

func is_equipment() -> bool:
	return item_type == ItemEnums.ItemType.EQUIPMENT


func is_consumable() -> bool:
	return item_type == ItemEnums.ItemType.CONSUMABLE


func can_equip(job_name: StringName) -> bool:
	if job_restrictions.is_empty():
		return true
	return job_restrictions.has(job_name)


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

static func create_equipment(
	p_name: StringName,
	p_display_name: String,
	p_slot: ItemEnums.EquipSlot,
	p_attribute_mods: Dictionary = {},
	p_stat_mods: Dictionary = {},
	p_job_restrictions: Array = [],
	p_description: String = "",
	p_rarity: ItemEnums.Rarity = ItemEnums.Rarity.COMMON,
	p_weapon_hand: ItemEnums.WeaponHand = ItemEnums.WeaponHand.NONE
) -> ItemData:
	var item := ItemData.new()
	item.item_name = p_name
	item.display_name = p_display_name
	item.item_type = ItemEnums.ItemType.EQUIPMENT
	item.equip_slot = p_slot
	item.weapon_hand = p_weapon_hand
	item.attribute_modifiers = p_attribute_mods
	item.stat_modifiers = p_stat_mods
	item.job_restrictions = p_job_restrictions
	item.description = p_description
	item.rarity = p_rarity
	return item


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
