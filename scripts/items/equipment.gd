class_name Equipment extends Resource
## A unit's equipment loadout — manages 8 slots and computes aggregate
## stat modifiers from all worn gear.
##
## MODIFIER APPLICATION FLOW:
##   1. get_total_attribute_modifiers() → apply to base_attributes copy
##   2. StatFormulas.derive() → UnitStats with attribute bonuses baked in
##   3. get_total_stat_modifiers() → flat additive layer on top


var _gear: Dictionary = {}       # EquipSlot → ItemData
var _rings: Array = [null, null] # index 0 and 1


# =============================================================================
# EQUIP / UNEQUIP
# =============================================================================

func equip(item: ItemData) -> ItemData:
	if item == null or not item.is_equipment():
		push_error("Equipment.equip: null or non-equipment item")
		return null
	if item.equip_slot == ItemEnums.EquipSlot.RING:
		return _equip_ring_auto(item)

	# Two-handed weapon clears the off-hand slot automatically.
	if item.equip_slot == ItemEnums.EquipSlot.MAIN_HAND \
	and item.weapon_hand == ItemEnums.WeaponHand.TWO_HANDED:
		_gear.erase(ItemEnums.EquipSlot.OFF_HAND)

	# Off-hand items can't be equipped while a two-hander is in the main hand.
	if item.equip_slot == ItemEnums.EquipSlot.OFF_HAND:
		var main: ItemData = _gear.get(ItemEnums.EquipSlot.MAIN_HAND, null)
		if main != null and main.weapon_hand == ItemEnums.WeaponHand.TWO_HANDED:
			push_warning("Equipment.equip: can't equip off-hand while wielding '%s' (two-handed)" % main.item_name)
			return null

	# Off-hand-only items must go in the off-hand slot.
	if item.weapon_hand == ItemEnums.WeaponHand.OFF_HAND_ONLY \
	and item.equip_slot != ItemEnums.EquipSlot.OFF_HAND:
		push_error("Equipment.equip: '%s' is off-hand only" % item.item_name)
		return null

	var old: ItemData = _gear.get(item.equip_slot, null)
	_gear[item.equip_slot] = item
	return old


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
	var other_index: int = 1 - slot_index
	if _rings[other_index] != null and _rings[other_index].item_name == item.item_name:
		push_warning("Equipment.equip_ring: '%s' already in the other ring slot" % item.item_name)
		return null
	var old: ItemData = _rings[slot_index]
	_rings[slot_index] = item
	return old


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

func get_item(slot: ItemEnums.EquipSlot, ring_index: int = 0) -> ItemData:
	if slot == ItemEnums.EquipSlot.RING:
		if ring_index < 0 or ring_index > 1:
			return null
		return _rings[ring_index]
	return _gear.get(slot, null)


func get_all_items() -> Array:
	var items: Array = []
	for slot in _gear:
		if _gear[slot] != null:
			items.append(_gear[slot])
	for ring in _rings:
		if ring != null:
			items.append(ring)
	return items


func is_slot_filled(slot: ItemEnums.EquipSlot, ring_index: int = 0) -> bool:
	return get_item(slot, ring_index) != null


func get_equipped_count() -> int:
	return get_all_items().size()


func is_empty() -> bool:
	return get_equipped_count() == 0


# =============================================================================
# MODIFIER AGGREGATION
# =============================================================================

func get_total_attribute_modifiers() -> Dictionary:
	var totals: Dictionary = {}
	for item in get_all_items():
		for attr_name in item.attribute_modifiers:
			var val: int = int(item.attribute_modifiers[attr_name])
			totals[attr_name] = totals.get(attr_name, 0) + val
	return totals


func get_total_stat_modifiers() -> Dictionary:
	var totals: Dictionary = {}
	for item in get_all_items():
		for stat_name in item.stat_modifiers:
			var val: int = int(item.stat_modifiers[stat_name])
			totals[stat_name] = totals.get(stat_name, 0) + val
	return totals


# =============================================================================
# INTERNALS
# =============================================================================

func _equip_ring_auto(item: ItemData) -> ItemData:
	for ring in _rings:
		if ring != null and ring.item_name == item.item_name:
			push_warning("Equipment: '%s' already equipped in a ring slot" % item.item_name)
			return null
	for i in _rings.size():
		if _rings[i] == null:
			_rings[i] = item
			return null
	var old: ItemData = _rings[0]
	_rings[0] = item
	return old
