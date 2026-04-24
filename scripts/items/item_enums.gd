class_name ItemEnums
## Vocabulary for the item and equipment systems.


## --- Item categories --------------------------------------------------------
enum ItemType {
	EQUIPMENT,      ## Worn in a slot, provides passive stat bonuses
	CONSUMABLE,     ## One-use, consumed from inventory during battle
}


## --- Equipment slot types ---------------------------------------------------
## Each unit has one of each slot except RING which has two.
enum EquipSlot {
	HELM,
	BODY,
	BOOTS,
	CLOAK,
	NECKLACE,
	RING,
	TRINKET,
}

## How many of each slot a unit has. Queried by Equipment to validate
## ring-slot assignments.
const SLOT_COUNTS: Dictionary = {
	EquipSlot.HELM: 1,
	EquipSlot.BODY: 1,
	EquipSlot.BOOTS: 1,
	EquipSlot.CLOAK: 1,
	EquipSlot.NECKLACE: 1,
	EquipSlot.RING: 2,
	EquipSlot.TRINKET: 1,
}

## Total number of equipment slots (including both ring slots).
const TOTAL_SLOTS: int = 8


## --- Consumable effect types ------------------------------------------------
## What happens when a consumable is used. The ItemResolver reads this to
## decide which pool to modify and how.
enum ConsumableEffect {
	RESTORE_HP,     ## Heals the target a flat amount
	RESTORE_MP,     ## Restores MP to the target
	REVIVE,         ## Brings a defeated (0 HP) ally back to life
}


## --- Rarity (future, stubbed for now) ---------------------------------------
enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
}


# =============================================================================
# HELPERS
# =============================================================================

## Human-readable slot name for UI and debug logs.
static func slot_display_name(slot: EquipSlot) -> String:
	match slot:
		EquipSlot.HELM:     return "Helm"
		EquipSlot.BODY:     return "Body"
		EquipSlot.BOOTS:    return "Boots"
		EquipSlot.CLOAK:    return "Cloak"
		EquipSlot.NECKLACE: return "Necklace"
		EquipSlot.RING:     return "Ring"
		EquipSlot.TRINKET:  return "Trinket"
	return "?"


static func effect_display_name(effect: ConsumableEffect) -> String:
	match effect:
		ConsumableEffect.RESTORE_HP: return "Restore HP"
		ConsumableEffect.RESTORE_MP: return "Restore MP"
		ConsumableEffect.REVIVE:     return "Revive"
	return "?"
