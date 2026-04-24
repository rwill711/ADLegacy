class_name ItemLibrary
## Catalog of all items available in Alpha. Returns fresh ItemData instances
## on each call so downstream mutation doesn't bleed between owners.
##
## EQUIPMENT NAMING CONVENTION:
##   Body/Boots come in 3 class-appropriate tiers. Alpha only uses starter
##   gear — the higher tiers are stubs for future loot/shops.
##
## STARTER LOADOUT DESIGN:
##   Every base character spawns with body armor + boots only.
##   Both pieces give +1 CON (via attribute_modifiers), which ripples through
##   StatFormulas to grant +5 HP, +1 DEF, and minor RES per piece.
##   Total starter bonus: +2 CON → +10 HP, +2 DEF from gear alone.
##
##   Slot allocation follows class fantasy:
##     Rogue      → Leather Vest + Leather Boots (light, fast)
##     Squire     → Chain Mail + Iron Boots (heavy, tough)
##     White Mage → Cloth Robe + Sandals (magical, simple)
##
## CONSUMABLE DESIGN:
##   3 potions for Alpha. Health and Mana potions are common support items.
##   Lazarus Potion is rare — single-target revive at 50% max HP.
##   All potions have use_range 1 (must be adjacent or self).


# =============================================================================
# ITEM NAME CONSTANTS — use these everywhere to avoid string typos
# =============================================================================

# --- Body Armor ---
const LEATHER_VEST     := &"leather_vest"
const CHAIN_MAIL       := &"chain_mail"
const CLOTH_ROBE       := &"cloth_robe"

# --- Boots ---
const LEATHER_BOOTS    := &"leather_boots"
const IRON_BOOTS       := &"iron_boots"
const SANDALS          := &"sandals"

# --- Helms (empty slots for Alpha — stubs for future) ---
const LEATHER_CAP      := &"leather_cap"
const IRON_HELM        := &"iron_helm"
const CLOTH_HOOD       := &"cloth_hood"

# --- Weapons (cosmetic / identity — no weapon slot yet, stored as reference) ---
const DAGGER           := &"dagger"
const SHORT_SWORD      := &"short_sword"
const WOODEN_STAFF     := &"wooden_staff"

# --- Consumables ---
const HEALTH_POTION    := &"health_potion"
const MANA_POTION      := &"mana_potion"
const LAZARUS_POTION   := &"lazarus_potion"


# =============================================================================
# LOOKUP
# =============================================================================

## Return a fresh ItemData for the given item name, or null if unknown.
static func get_item(item_name: StringName) -> ItemData:
	match item_name:
		# Body armor
		LEATHER_VEST:   return _leather_vest()
		CHAIN_MAIL:     return _chain_mail()
		CLOTH_ROBE:     return _cloth_robe()
		# Boots
		LEATHER_BOOTS:  return _leather_boots()
		IRON_BOOTS:     return _iron_boots()
		SANDALS:        return _sandals()
		# Helms
		LEATHER_CAP:    return _leather_cap()
		IRON_HELM:      return _iron_helm()
		CLOTH_HOOD:     return _cloth_hood()
		# Weapons
		DAGGER:         return _dagger()
		SHORT_SWORD:    return _short_sword()
		WOODEN_STAFF:   return _wooden_staff()
		# Consumables
		HEALTH_POTION:  return _health_potion()
		MANA_POTION:    return _mana_potion()
		LAZARUS_POTION: return _lazarus_potion()
	push_warning("ItemLibrary: unknown item '%s'" % [item_name])
	return null


## Resolve multiple item names. Skips unknowns.
static func get_items(item_names: Array) -> Array:
	var out: Array = []
	for name in item_names:
		var item := get_item(name)
		if item != null:
			out.append(item)
	return out


# =============================================================================
# STARTER LOADOUTS — returns the default equipment for a given job
# =============================================================================

## Returns an array of ItemData for the starter gear of a job.
## Only body armor + boots for Alpha. All give +1 CON.
static func get_starter_equipment(job_name: StringName) -> Array:
	match job_name:
		JobLibrary.ROGUE:
			return [_leather_vest(), _leather_boots()]
		JobLibrary.SQUIRE:
			return [_chain_mail(), _iron_boots()]
		JobLibrary.WHITE_MAGE:
			return [_cloth_robe(), _sandals()]
	push_warning("ItemLibrary: no starter loadout for job '%s'" % [job_name])
	return []


## Returns an array of starter consumables every unit begins with.
## For Alpha: 1 Health Potion, 1 Mana Potion per unit.
static func get_starter_consumables() -> Array:
	return [_health_potion(), _mana_potion()]


# =============================================================================
# BODY ARMOR DEFINITIONS
# =============================================================================

static func _leather_vest() -> ItemData:
	return ItemData.create_equipment(
		LEATHER_VEST, "Leather Vest",
		ItemEnums.EquipSlot.BODY,
		{"constitution": 1},   # attribute modifier: +1 CON
		{},                    # no flat stat mods
		[],                    # equippable by anyone
		"Light leather armor. Supple and quiet.",
	)

static func _chain_mail() -> ItemData:
	return ItemData.create_equipment(
		CHAIN_MAIL, "Chain Mail",
		ItemEnums.EquipSlot.BODY,
		{"constitution": 1},
		{},
		[],
		"Interlocking metal rings. Heavy but protective.",
	)

static func _cloth_robe() -> ItemData:
	return ItemData.create_equipment(
		CLOTH_ROBE, "Cloth Robe",
		ItemEnums.EquipSlot.BODY,
		{"constitution": 1},
		{},
		[],
		"Simple woven garment. Lets magic flow freely.",
	)


# =============================================================================
# BOOTS DEFINITIONS
# =============================================================================

static func _leather_boots() -> ItemData:
	return ItemData.create_equipment(
		LEATHER_BOOTS, "Leather Boots",
		ItemEnums.EquipSlot.BOOTS,
		{"constitution": 1},
		{},
		[],
		"Sturdy leather footwear. Light and reliable.",
	)

static func _iron_boots() -> ItemData:
	return ItemData.create_equipment(
		IRON_BOOTS, "Iron Boots",
		ItemEnums.EquipSlot.BOOTS,
		{"constitution": 1},
		{},
		[],
		"Heavy metal boots. Your feet won't feel a thing.",
	)

static func _sandals() -> ItemData:
	return ItemData.create_equipment(
		SANDALS, "Sandals",
		ItemEnums.EquipSlot.BOOTS,
		{"constitution": 1},
		{},
		[],
		"Simple open-toed footwear. Barely counts as armor.",
	)


# =============================================================================
# HELM DEFINITIONS (stubs — not equipped by default in Alpha)
# =============================================================================

static func _leather_cap() -> ItemData:
	return ItemData.create_equipment(
		LEATHER_CAP, "Leather Cap",
		ItemEnums.EquipSlot.HELM,
		{"dexterity": 1},
		{},
		[],
		"Snug leather cap. Keeps your head warm and safe-ish.",
	)

static func _iron_helm() -> ItemData:
	return ItemData.create_equipment(
		IRON_HELM, "Iron Helm",
		ItemEnums.EquipSlot.HELM,
		{"constitution": 1},
		{},
		[],
		"Solid metal helm. Restricts vision but protects well.",
	)

static func _cloth_hood() -> ItemData:
	return ItemData.create_equipment(
		CLOTH_HOOD, "Cloth Hood",
		ItemEnums.EquipSlot.HELM,
		{"wisdom": 1},
		{},
		[],
		"A mage's hood. Helps focus the mind.",
	)


# =============================================================================
# WEAPON DEFINITIONS (cosmetic identity — no weapon slot in Alpha)
# =============================================================================

static func _dagger() -> ItemData:
	return ItemData.create_equipment(
		DAGGER, "Dagger",
		ItemEnums.EquipSlot.TRINKET,  # Using trinket slot for weapon identity
		{"dexterity": 1},
		{},
		[],
		"A short blade favored by rogues. Quick and precise.",
	)

static func _short_sword() -> ItemData:
	return ItemData.create_equipment(
		SHORT_SWORD, "Short Sword",
		ItemEnums.EquipSlot.TRINKET,
		{"strength": 1},
		{},
		[],
		"A reliable sidearm. Every squire's first blade.",
	)

static func _wooden_staff() -> ItemData:
	return ItemData.create_equipment(
		WOODEN_STAFF, "Wooden Staff",
		ItemEnums.EquipSlot.TRINKET,
		{"wisdom": 1},
		{},
		[],
		"Gnarled oak staff. Channels magic — and bonks in a pinch.",
	)


# =============================================================================
# CONSUMABLE DEFINITIONS
# =============================================================================

static func _health_potion() -> ItemData:
	return ItemData.create_consumable(
		HEALTH_POTION, "Health Potion",
		ItemEnums.ConsumableEffect.RESTORE_HP,
		20.0,         # Restores 20 HP (Squire has 50 max, so ~40% heal)
		1,            # Must be adjacent or self
		"A crimson vial that mends wounds. Restores 20 HP.",
		ItemEnums.Rarity.COMMON,
	)

static func _mana_potion() -> ItemData:
	return ItemData.create_consumable(
		MANA_POTION, "Mana Potion",
		ItemEnums.ConsumableEffect.RESTORE_MP,
		15.0,         # Restores 15 MP (White Mage has 50 max, so ~30% restore)
		1,
		"A shimmering blue vial. Restores 15 MP.",
		ItemEnums.Rarity.COMMON,
	)

static func _lazarus_potion() -> ItemData:
	return ItemData.create_consumable(
		LAZARUS_POTION, "Lazarus Potion",
		ItemEnums.ConsumableEffect.REVIVE,
		0.5,          # Revive at 50% of max HP
		1,
		"A legendary draught that pulls souls back from the brink. Revives a fallen ally with 50% HP.",
		ItemEnums.Rarity.RARE,
	)
