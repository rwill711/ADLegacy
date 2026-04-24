class_name Equipment extends Resource
## A unit's equipment loadout — manages 8 slots and computes aggregate
## stat modifiers from all worn gear.
##
## SLOT LAYOUT:
##   Helm, Body, Boots, Cloak, Necklace, Ring 1, Ring 2, Trinket
##
## Ring slots are distinguished by index (0 and 1) in the _rings array.
## All other slots are single-occupancy Dictionary entries in _gear.
##
## MODIFIER APPLICATION FLOW:
##   1. Unit calls equipment.get_total_attribute_modifiers()
##   2. Unit temporarily applies those to its base_attributes copy
##   3. Unit calls StatFormulas.derive() → UnitStats with attribute bonuses
##   4. Unit calls equipment.get_total_stat_modifiers()
##   5. Unit applies those as flat additive bonuses on top of derived stats
##   6. Result: final UnitStats ready for combat
##
## This two-pass approach means a +1 CON amulet gives +5 HP AND +1 DEF
## (attribute ripple), while a +2 speed ring gives exactly +2 speed (flat).


## --- Storage ----------------------------------------------------------------
## Single-slot gear. Key = EquipSlot enum value, Value = ItemData or null.
var _gear: Dictionary = {}

## Ring slots (2). Index 0 = ring slot 1, index 1 = ring slot 2.
var _rings: Array = [null, null]


# =============================================================================
# EQUIP / UNEQUIP
# =============================================================================

## Equip an item into its designated slot. Returns the previously equipped
## item (or null if the slot was empty). Validates slot match and prevents
## duplicate ring equips.
##
## For rings: fills the first empty ring slot, or replaces slot 0 if both
## are full. Use equip_ring() to target a specific ring slot.
func equip(item: ItemData) -> ItemData:
	if item == null or not item.is_equipment():
		push_error("Equipment.equip: null or non-equipment item")
		return null

	if item.equip_slot == ItemEnums.EquipSlot.RING:
		return _equip_ring_auto(item)

	var old: ItemData = _gear.get(item.equip_slot, null)
	_gear[item.equip_slot] = item
	return old


## Equip a ring into a specific ring slot (0 or 1).
func equip_ring(item: ItemData, slot_index: int) -> ItemData:
	if item == null or not item.is_equipment():
		push_error("Equipment.equip_ring: null or non-equipment item")
		return null
	if item.equip_slot != ItemEnums.EquipSlot.RING:
		push_error("Equipment.equip_ring: item '%s' is not a ring" % item.item_name)
		return null
	if slot_index < 0 or slot_index > 1:
		push_error("Equipment.equip_ring: invalid slot_index %d" % slot_index)
		return null

	# Prevent equipping the exact same item in both ring slots.
	var other_index: int = 1 - slot_index
	if _rings[other_index] != null and _rings[other_index].item_name == item.item_name:
		push_warning("Equipment.equip_ring: '%s' already in the other ring slot" % item.item_name)
		return null

	var old: ItemData = _rings[slot_index]
	_rings[slot_index] = item
	return old


## Remove the item from a specific slot. Returns the removed item or null.
func unequip(slot: ItemEnums.EquipSlot, ring_index: int = 0) -> ItemData:
	if slot == ItemEnums.EquipSlot.RING:
		if ring_index < 0 or ring_index > 1:
			return null
		var old: ItemData = _rings[ring_index]
		_rings[ring_index] = null
		return old

	var old: ItemData = _gear.get(slot, null)
	_gear.erase(slot)
	return old


## Remove all equipment. Returns an array of all removed items (no nulls).
func unequip_all() -> Array:
	var removed: Array = []
	for slot in _gear:
		if _gear[slot] != null:
			removed.append(_gear[slot])
	_gear.clear()
	for i in _rings.size():
		if _rings[i] != null:
			removed.append(_rings[i])
			_rings[i] = null
	return removed


# =============================================================================
# QUERIES
# =============================================================================

## Get the item in a specific slot. Returns null if empty.
func get_item(slot: ItemEnums.EquipSlot, ring_index: int = 0) -> ItemData:
	if slot == ItemEnums.EquipSlot.RING:
		if ring_index < 0 or ring_index > 1:
			return null
		return _rings[ring_index]
	return _gear.get(slot, null)


## Get all equipped items as a flat array (no nulls).
func get_all_items() -> Array:
	var items: Array = []
	for slot in _gear:
		if _gear[slot] != null:
			items.append(_gear[slot])
	for ring in _rings:
		if ring != null:
			items.append(ring)
	return items


## Is a specific slot occupied?
func is_slot_filled(slot: ItemEnums.EquipSlot, ring_index: int = 0) -> bool:
	return get_item(slot, ring_index) != null


## How many total items are equipped?
func get_equipped_count() -> int:
	return get_all_items().size()


## Is this loadout completely empty?
func is_empty() -> bool:
	return get_equipped_count() == 0


# =============================================================================
# MODIFIER AGGREGATION
# =============================================================================

## Sum all attribute_modifiers from every equipped item.
## Returns a Dictionary with attribute names as keys and total bonus as values.
## Example: {"constitution": 2, "dexterity": 1}
func get_total_attribute_modifiers() -> Dictionary:
	var totals: Dictionary = {}
	for item in get_all_items():
		for attr_name in item.attribute_modifiers:
			var val: int = int(item.attribute_modifiers[attr_name])
			totals[attr_name] = totals.get(attr_name, 0) + val
	return totals


## Sum all stat_modifiers from every equipped item.
## Returns a Dictionary with stat names as keys and total bonus as values.
## Example: {"speed": 2, "max_hp": 5}
func get_total_stat_modifiers() -> Dictionary:
	var totals: Dictionary = {}
	for item in get_all_items():
		for stat_name in item.stat_modifiers:
			var val: int = int(item.stat_modifiers[stat_name])
			totals[stat_name] = totals.get(stat_name, 0) + val
	return totals


# =============================================================================
# DEBUG / UI
# =============================================================================

## Return a human-readable summary of all equipped items and their bonuses.
func get_loadout_summary() -> String:
	var lines: Array = []
	# Non-ring slots
	var ordered_slots: Array = [
		ItemEnums.EquipSlot.HELM,
		ItemEnums.EquipSlot.BODY,
		ItemEnums.EquipSlot.BOOTS,
		ItemEnums.EquipSlot.CLOAK,
		ItemEnums.EquipSlot.NECKLACE,
		ItemEnums.EquipSlot.TRINKET,
	]
	for slot in ordered_slots:
		var item: ItemData = _gear.get(slot, null)
		var slot_name: String = ItemEnums.slot_display_name(slot)
		if item != null:
			lines.append("  %s: %s (%s)" % [slot_name, item.display_name, item.get_modifier_summary()])
		else:
			lines.append("  %s: —" % slot_name)
	# Ring slots
	for i in 2:
		var ring: ItemData = _rings[i]
		if ring != null:
			lines.append("  Ring %d: %s (%s)" % [i + 1, ring.display_name, ring.get_modifier_summary()])
		else:
			lines.append("  Ring %d: —" % [i + 1])
	return "\n".join(lines)


# =============================================================================
# INTERNALS
# =============================================================================

## Auto-assign a ring to the first empty ring slot, or replace slot 0 if full.
func _equip_ring_auto(item: ItemData) -> ItemData:
	# Check for duplicate ring name
	for ring in _rings:
		if ring != null and ring.item_name == item.item_name:
			push_warning("Equipment: '%s' already equipped in a ring slot" % item.item_name)
			return null

	# Fill first empty slot
	for i in _rings.size():
		if _rings[i] == null:
			_rings[i] = item
			return null  # nothing was replaced

	# Both full — replace slot 0
	var old: ItemData = _rings[0]
	_rings[0] = item
	return old
