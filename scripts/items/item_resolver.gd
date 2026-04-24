class_name ItemResolver
## Resolves consumable item usage during battle. Analogous to AbilityResolver
## for skills, but operates on ItemData instead of SkillData.
##
## USAGE FLOW:
##   1. Player selects "Item" from the ability bar
##   2. UI shows inventory contents; player picks an item
##   3. If item targets others, targeting phase shows valid targets
##   4. Player clicks target → ActionController calls ItemResolver.resolve()
##   5. ItemResolver applies the effect, consumes the item from inventory,
##      and returns a result Dictionary for visuals/logging
##
## REVIVE TARGETING:
##   The Lazarus Potion targets defeated (0 HP) allies. This is a special
##   case — no other system currently targets dead units. The resolver
##   validates that the target is actually dead before applying the revive.
##
## RESULT FORMAT (matches AbilityResolver's "effects" shape for consistency):
##   {
##     "item_name": StringName,
##     "consumed": bool,
##     "effects": [
##       {
##         "target_id": StringName,
##         "target_coord": Vector2i,
##         "heal": int,
##         "mp_restored": int,
##         "revived": bool,
##         "message": String,
##       }
##     ]
##   }


# =============================================================================
# RESOLVE — apply a consumable item's effect
# =============================================================================

## Apply a consumable to a target unit. The item is consumed from the caster's
## inventory on success. Returns a result Dictionary.
##
## caster: the unit using the item (item is consumed from their inventory)
## item: the ItemData being used (must be consumable)
## target: the unit receiving the effect (can be caster for self-use)
static func resolve(caster_inventory: Inventory, item: ItemData, target: Unit) -> Dictionary:
	var result: Dictionary = {
		"item_name": item.item_name if item != null else &"",
		"consumed": false,
		"effects": [],
	}

	if item == null or not item.is_consumable():
		push_error("ItemResolver.resolve: null or non-consumable item")
		return result

	if target == null:
		push_error("ItemResolver.resolve: null target")
		return result

	if caster_inventory == null:
		push_error("ItemResolver.resolve: null inventory")
		return result

	var effect: Dictionary = {
		"target_id": target.unit_id,
		"target_coord": target.coord,
		"heal": 0,
		"mp_restored": 0,
		"revived": false,
		"message": "",
	}

	var success: bool = false

	match item.consumable_effect:
		ItemEnums.ConsumableEffect.RESTORE_HP:
			success = _apply_restore_hp(item, target, effect)

		ItemEnums.ConsumableEffect.RESTORE_MP:
			success = _apply_restore_mp(item, target, effect)

		ItemEnums.ConsumableEffect.REVIVE:
			success = _apply_revive(item, target, effect)

	if success:
		# Consume the item from inventory
		var consumed: bool = caster_inventory.consume(item)
		result["consumed"] = consumed
		if not consumed:
			push_warning("ItemResolver: item '%s' used but not found in inventory" % item.item_name)

	result["effects"].append(effect)
	return result


# =============================================================================
# VALIDATION — can this item be used on this target?
# =============================================================================

## Check if a consumable can legally be used on a target.
## Used by the targeting phase to filter valid targets.
static func can_use_on(item: ItemData, target: Unit) -> bool:
	if item == null or target == null:
		return false
	if not item.is_consumable():
		return false

	match item.consumable_effect:
		ItemEnums.ConsumableEffect.RESTORE_HP:
			# Must be alive and not at full HP
			return target.is_alive() and not target.stats.is_full_hp()

		ItemEnums.ConsumableEffect.RESTORE_MP:
			# Must be alive and not at full MP
			return target.is_alive() and target.stats.mp < target.stats.max_mp

		ItemEnums.ConsumableEffect.REVIVE:
			# Must be defeated (0 HP) — the whole point of the Lazarus Potion
			return not target.is_alive()

	return false


## Check if a consumable targets allies, enemies, or self.
## Used for targeting-phase team filtering.
static func targets_allies(item: ItemData) -> bool:
	if item == null or not item.is_consumable():
		return false
	# All Alpha consumables target allies or self
	match item.consumable_effect:
		ItemEnums.ConsumableEffect.RESTORE_HP:  return true
		ItemEnums.ConsumableEffect.RESTORE_MP:  return true
		ItemEnums.ConsumableEffect.REVIVE:      return true
	return false


# =============================================================================
# EFFECT APPLICATION
# =============================================================================

static func _apply_restore_hp(item: ItemData, target: Unit, effect: Dictionary) -> bool:
	if not target.is_alive():
		effect["message"] = "Target is defeated"
		return false
	if target.stats.is_full_hp():
		effect["message"] = "Already at full HP"
		return false

	var amount: int = int(item.effect_value)
	var healed: int = target.heal(amount)
	effect["heal"] = healed
	effect["message"] = "+%d HP" % healed
	return true


static func _apply_restore_mp(item: ItemData, target: Unit, effect: Dictionary) -> bool:
	if not target.is_alive():
		effect["message"] = "Target is defeated"
		return false
	if target.stats.mp >= target.stats.max_mp:
		effect["message"] = "Already at full MP"
		return false

	var amount: int = int(item.effect_value)
	var restored: int = target.restore_mp(amount)  # wrapper emits mp_changed
	effect["mp_restored"] = restored
	effect["message"] = "+%d MP" % restored
	return true


static func _apply_revive(item: ItemData, target: Unit, effect: Dictionary) -> bool:
	if target.is_alive():
		effect["message"] = "Target is not defeated"
		return false

	# Revive at fraction of max HP — Unit.revive() handles state + visual reset.
	var revive_hp: int = maxi(1, int(float(target.stats.max_hp) * item.effect_value))
	target.revive(revive_hp)
	effect["heal"] = revive_hp
	effect["revived"] = true
	effect["message"] = "Revived with %d HP" % revive_hp

	return true
