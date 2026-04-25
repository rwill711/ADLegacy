class_name ItemLibrary
## Catalog of all items available in Alpha. Returns fresh ItemData instances
## on each call so downstream mutation doesn't bleed between owners.
##
## STARTER LOADOUT: every unit spawns with body armor + boots.
## Both pieces give +1 CON → +5 HP, +1 DEF per piece via StatFormulas.
## Total starter bonus: +2 CON → +10 HP, +2 DEF.


# --- Body Armor ---
const LEATHER_VEST     := &"leather_vest"
const CHAIN_MAIL       := &"chain_mail"
const CLOTH_ROBE       := &"cloth_robe"

# --- Boots ---
const LEATHER_BOOTS    := &"leather_boots"
const IRON_BOOTS       := &"iron_boots"
const SANDALS          := &"sandals"

# --- Helms (stubs — not equipped by default in Alpha) ---
const LEATHER_CAP      := &"leather_cap"
const IRON_HELM        := &"iron_helm"
const CLOTH_HOOD       := &"cloth_hood"

# --- Weapons ---
const DAGGER           := &"dagger"
const SHORT_SWORD      := &"short_sword"
const WOODEN_STAFF     := &"wooden_staff"

# --- Off-hand ---
const IRON_SHIELD      := &"iron_shield"

# --- Consumables ---
const HEALTH_POTION    := &"health_potion"
const MANA_POTION      := &"mana_potion"
const LAZARUS_POTION   := &"lazarus_potion"


# =============================================================================
# LOOKUP
# =============================================================================

static func get_item(item_name: StringName) -> ItemData:
	match item_name:
		LEATHER_VEST:   return _leather_vest()
		CHAIN_MAIL:     return _chain_mail()
		CLOTH_ROBE:     return _cloth_robe()
		LEATHER_BOOTS:  return _leather_boots()
		IRON_BOOTS:     return _iron_boots()
		SANDALS:        return _sandals()
		LEATHER_CAP:    return _leather_cap()
		IRON_HELM:      return _iron_helm()
		CLOTH_HOOD:     return _cloth_hood()
		DAGGER:         return _dagger()
		SHORT_SWORD:    return _short_sword()
		WOODEN_STAFF:   return _wooden_staff()
		IRON_SHIELD:    return _iron_shield()
		HEALTH_POTION:  return _health_potion()
		MANA_POTION:    return _mana_potion()
		LAZARUS_POTION: return _lazarus_potion()
	push_warning("ItemLibrary: unknown item '%s'" % [item_name])
	return null


static func get_items(item_names: Array) -> Array:
	var out: Array = []
	for name in item_names:
		var item := get_item(name)
		if item != null:
			out.append(item)
	return out


# =============================================================================
# STARTER LOADOUTS
# =============================================================================

static func get_starter_equipment(job_name: StringName) -> Array:
	match job_name:
		JobLibrary.ROGUE:
			return [_dagger(), _leather_vest(), _leather_boots()]
		JobLibrary.SQUIRE:
			return [_short_sword(), _iron_shield(), _chain_mail(), _iron_boots()]
		JobLibrary.WHITE_MAGE:
			return [_wooden_staff(), _cloth_robe(), _sandals()]
	push_warning("ItemLibrary: no starter loadout for job '%s'" % [job_name])
	return []


static func get_starter_consumables() -> Array:
	return [_health_potion(), _mana_potion()]


# =============================================================================
# BODY ARMOR
# =============================================================================

static func _leather_vest() -> ItemData:
	return ItemData.create_equipment(LEATHER_VEST, "Leather Vest",
		ItemEnums.EquipSlot.BODY, {"constitution": 1}, {},
		[], "Light leather armor. Supple and quiet.")

static func _chain_mail() -> ItemData:
	return ItemData.create_equipment(CHAIN_MAIL, "Chain Mail",
		ItemEnums.EquipSlot.BODY, {"constitution": 1}, {},
		[], "Interlocking metal rings. Heavy but protective.")

static func _cloth_robe() -> ItemData:
	return ItemData.create_equipment(CLOTH_ROBE, "Cloth Robe",
		ItemEnums.EquipSlot.BODY, {"constitution": 1}, {},
		[], "Simple woven garment. Lets magic flow freely.")


# =============================================================================
# BOOTS
# =============================================================================

static func _leather_boots() -> ItemData:
	return ItemData.create_equipment(LEATHER_BOOTS, "Leather Boots",
		ItemEnums.EquipSlot.BOOTS, {"constitution": 1}, {},
		[], "Sturdy leather footwear. Light and reliable.")

static func _iron_boots() -> ItemData:
	return ItemData.create_equipment(IRON_BOOTS, "Iron Boots",
		ItemEnums.EquipSlot.BOOTS, {"constitution": 1}, {},
		[], "Heavy metal boots. Your feet won't feel a thing.")

static func _sandals() -> ItemData:
	return ItemData.create_equipment(SANDALS, "Sandals",
		ItemEnums.EquipSlot.BOOTS, {"constitution": 1}, {},
		[], "Simple open-toed footwear. Barely counts as armor.")


# =============================================================================
# HELMS (stubs)
# =============================================================================

static func _leather_cap() -> ItemData:
	return ItemData.create_equipment(LEATHER_CAP, "Leather Cap",
		ItemEnums.EquipSlot.HELM, {"dexterity": 1}, {},
		[], "Snug leather cap.")

static func _iron_helm() -> ItemData:
	return ItemData.create_equipment(IRON_HELM, "Iron Helm",
		ItemEnums.EquipSlot.HELM, {"constitution": 1}, {},
		[], "Solid metal helm.")

static func _cloth_hood() -> ItemData:
	return ItemData.create_equipment(CLOTH_HOOD, "Cloth Hood",
		ItemEnums.EquipSlot.HELM, {"wisdom": 1}, {},
		[], "A mage's hood. Helps focus the mind.")


# =============================================================================
# WEAPONS
# =============================================================================

static func _dagger() -> ItemData:
	return ItemData.create_equipment(DAGGER, "Dagger",
		ItemEnums.EquipSlot.MAIN_HAND, {"dexterity": 1}, {"attack": 3},
		[], "A short blade favored by rogues. Quick and precise.",
		ItemEnums.Rarity.COMMON, ItemEnums.WeaponHand.ONE_HANDED)

static func _short_sword() -> ItemData:
	return ItemData.create_equipment(SHORT_SWORD, "Short Sword",
		ItemEnums.EquipSlot.MAIN_HAND, {"strength": 1}, {"attack": 4},
		[], "A reliable sidearm. Every squire's first blade.",
		ItemEnums.Rarity.COMMON, ItemEnums.WeaponHand.ONE_HANDED)

static func _wooden_staff() -> ItemData:
	return ItemData.create_equipment(WOODEN_STAFF, "Wooden Staff",
		ItemEnums.EquipSlot.MAIN_HAND, {"wisdom": 1}, {"magic": 4},
		[], "Gnarled oak staff. Channels magic — and bonks in a pinch.",
		ItemEnums.Rarity.COMMON, ItemEnums.WeaponHand.TWO_HANDED)


# =============================================================================
# OFF-HAND
# =============================================================================

static func _iron_shield() -> ItemData:
	return ItemData.create_equipment(IRON_SHIELD, "Iron Shield",
		ItemEnums.EquipSlot.OFF_HAND, {}, {"defense": 3},
		[], "A sturdy iron shield. Blocks blows the armor can't.",
		ItemEnums.Rarity.COMMON, ItemEnums.WeaponHand.OFF_HAND_ONLY)


# =============================================================================
# CONSUMABLES
# =============================================================================

static func _health_potion() -> ItemData:
	return ItemData.create_consumable(HEALTH_POTION, "Health Potion",
		ItemEnums.ConsumableEffect.RESTORE_HP, 20.0, 1,
		"A crimson vial that mends wounds. Restores 20 HP.")

static func _mana_potion() -> ItemData:
	return ItemData.create_consumable(MANA_POTION, "Mana Potion",
		ItemEnums.ConsumableEffect.RESTORE_MP, 15.0, 1,
		"A shimmering blue vial. Restores 15 MP.")

static func _lazarus_potion() -> ItemData:
	return ItemData.create_consumable(LAZARUS_POTION, "Lazarus Potion",
		ItemEnums.ConsumableEffect.REVIVE, 0.5, 1,
		"A legendary draught. Revives a fallen ally with 50% HP.",
		ItemEnums.Rarity.RARE)
