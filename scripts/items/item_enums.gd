class_name ItemEnums
## Vocabulary for the item and equipment systems.


## --- Item categories --------------------------------------------------------
enum ItemType {
	EQUIPMENT,
	CONSUMABLE,
}


## --- Equipment slot types ---------------------------------------------------
enum EquipSlot {
	MAIN_HAND,   ## Primary weapon hand
	OFF_HAND,    ## Shield, focus, or off-hand weapon (one-handed only)
	HELM,
	BODY,
	BOOTS,
	CLOAK,
	NECKLACE,
	RING,
	TRINKET,
}

const SLOT_COUNTS: Dictionary = {
	EquipSlot.MAIN_HAND: 1,
	EquipSlot.OFF_HAND:  1,
	EquipSlot.HELM:      1,
	EquipSlot.BODY:      1,
	EquipSlot.BOOTS:     1,
	EquipSlot.CLOAK:     1,
	EquipSlot.NECKLACE:  1,
	EquipSlot.RING:      2,
	EquipSlot.TRINKET:   1,
}

const TOTAL_SLOTS: int = 10


## --- Weapon hand tag --------------------------------------------------------
## Applied to MAIN_HAND and OFF_HAND items to encode grip requirements.
enum WeaponHand {
	NONE,         ## Not a weapon (armor, accessories)
	ONE_HANDED,   ## Fits in MAIN_HAND; leaves OFF_HAND free
	TWO_HANDED,   ## Occupies MAIN_HAND; blocks OFF_HAND slot
	OFF_HAND_ONLY ## Shields and focuses — can only go in OFF_HAND
}


## --- Consumable effect types ------------------------------------------------
enum ConsumableEffect {
	RESTORE_HP,
	RESTORE_MP,
	REVIVE,
}


## --- Rarity -----------------------------------------------------------------
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
}


# =============================================================================
# HELPERS
# =============================================================================

static func slot_display_name(slot: EquipSlot) -> String:
	match slot:
		EquipSlot.MAIN_HAND: return "Main Hand"
		EquipSlot.OFF_HAND:  return "Off Hand"
		EquipSlot.HELM:      return "Helm"
		EquipSlot.BODY:      return "Body"
		EquipSlot.BOOTS:     return "Boots"
		EquipSlot.CLOAK:     return "Cloak"
		EquipSlot.NECKLACE:  return "Necklace"
		EquipSlot.RING:      return "Ring"
		EquipSlot.TRINKET:   return "Trinket"
	return "?"


static func weapon_hand_display_name(hand: WeaponHand) -> String:
	match hand:
		WeaponHand.ONE_HANDED:   return "One-Handed"
		WeaponHand.TWO_HANDED:   return "Two-Handed"
		WeaponHand.OFF_HAND_ONLY: return "Off-Hand Only"
	return ""


static func effect_display_name(effect: ConsumableEffect) -> String:
	match effect:
		ConsumableEffect.RESTORE_HP: return "Restore HP"
		ConsumableEffect.RESTORE_MP: return "Restore MP"
		ConsumableEffect.REVIVE:     return "Revive"
	return "?"
