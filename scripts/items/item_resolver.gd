class_name ItemResolver
## Resolves consumable item usage during battle.
##
## RESULT FORMAT (matches AbilityResolver shape for consistency):
##   {
##     "item_name": StringName,
##     "consumed":  bool,
##     "effects": [{
##       "target_id":    StringName,
##       "target_coord": Vector2i,
##       "heal":         int,
##       "mp_restored":  int,
##       "revived":      bool,
##       "message":      String,
##     }]
##   }


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
		"target_id":    target.unit_id,
		"target_coord": target.coord,
		"heal":         0,
		"mp_restored":  0,
		"revived":      false,
		"message":      "",
	}

	var success: bool = false
	match item.consumable_effect:
		ItemEnums.ConsumableEffect.RESTORE_HP: success = _apply_restore_hp(item, target, effect)
		ItemEnums.ConsumableEffect.RESTORE_MP: success = _apply_restore_mp(item, target, effect)
		ItemEnums.ConsumableEffect.REVIVE:     success = _apply_revive(item, target, effect)

	if success:
		var consumed: bool = caster_inventory.consume(item)
		result["consumed"] = consumed
		if not consumed:
			push_warning("ItemResolver: item '%s' used but not found in inventory" % item.item_name)

	result["effects"].append(effect)
	return result


# =============================================================================
# VALIDATION
# =============================================================================

static func can_use_on(item: ItemData, target: Unit) -> bool:
	if item == null or target == null or not item.is_consumable():
		return false
	match item.consumable_effect:
		ItemEnums.ConsumableEffect.RESTORE_HP: return target.is_alive() and not target.stats.is_full_hp()
		ItemEnums.ConsumableEffect.RESTORE_MP: return target.is_alive() and target.stats.mp < target.stats.max_mp
		ItemEnums.ConsumableEffect.REVIVE:     return not target.is_alive()
	return false


static func targets_allies(_item: ItemData) -> bool:
	return true


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
	var healed: int = target.heal(int(item.effect_value))
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
	var restored: int = target.stats.restore_mp(int(item.effect_value))
	if restored > 0:
		target.mp_changed.emit(target.stats.mp, target.stats.max_mp)
	effect["mp_restored"] = restored
	effect["message"] = "+%d MP" % restored
	return true


static func _apply_revive(item: ItemData, target: Unit, effect: Dictionary) -> bool:
	if target.is_alive():
		effect["message"] = "Target is not defeated"
		return false
	var revive_hp: int = maxi(1, int(float(target.stats.max_hp) * item.effect_value))
	target.stats.hp = clampi(revive_hp, 1, target.stats.max_hp)
	target.set_state(UnitEnums.UnitState.IDLE)
	target.hp_changed.emit(target.stats.hp, target.stats.max_hp)
	if target._body_mesh != null:
		var t := target.create_tween()
		t.set_ease(Tween.EASE_OUT)
		t.set_trans(Tween.TRANS_CUBIC)
		t.tween_property(target._body_mesh, "rotation_degrees:z", 0.0, 0.3)
	effect["heal"] = revive_hp
	effect["revived"] = true
	effect["message"] = "Revived with %d HP" % revive_hp
	return true
