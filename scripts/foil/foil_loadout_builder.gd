class_name FOILLoadoutBuilder
## The OUTPUT stage of the FOIL system.
## Consumes a FOILProfile + FOIL level + a base enemy pool → returns an enemy
## team CONFIG (a Dictionary of symbolic hints). A downstream EnemySpawner is
## responsible for translating these hints into real JobData / EquipmentData
## when those systems come online.
##
## This is intentionally string-tag driven, because:
##   - The job, equipment, and element systems aren't ported to GDScript yet.
##   - Keeping the contract symbolic lets us unit-test the FOIL decisions in
##     isolation from the asset pipeline.
##   - The mapping from "fire_resist_potion" → real ItemData is a single lookup
##     the spawner owns.
##
## Layering by FOIL level (per ADR-003):
##   0 OBLIVIOUS — Base enemy pool, no adaptation.
##   1 AWARE     — Base pool + counter consumables.
##   2 PREPARED  — Half the team swapped to counter jobs.
##   3 STRATEGIC — Counter jobs + AI behavior hints (formation, target priority).
##   4 MASTERY   — Full counter team + counter gear + enhanced consumables.


## --- Counter-job hints per dominant archetype --------------------------------
## These are role labels, not specific jobs. The EnemySpawner maps role → the
## actual JobData that best fits that role from the enemy pool for this region.
const COUNTER_JOBS_BY_ARCHETYPE: Dictionary = {
	FOILEnums.Archetype.MELEE_AGGRO: [
		"ranged_kiter", "spear_user", "burst_mage",
	],
	FOILEnums.Archetype.RANGED_KITE: [
		"rusher", "dash_assassin", "barrier_tank",
	],
	FOILEnums.Archetype.MAGIC_OFFENSE: [
		"silencer", "magic_resist_tank", "mp_drainer",
	],
	FOILEnums.Archetype.HEALER_SUPPORT: [
		"burst_damage", "silencer", "assassin",
	],
	FOILEnums.Archetype.TANK_WALL: [
		"armor_breaker", "true_damage", "status_caster",
	],
	FOILEnums.Archetype.AOE_BLASTER: [
		"spread_skirmisher", "stealth_operator", "reflective_mage",
	],
	FOILEnums.Archetype.DEBUFFER: [
		"cleansing_support", "resist_tank", "burst_damage",
	],
	FOILEnums.Archetype.HYBRID: [
		"generalist", "flex_support", "balanced_damage",
	],
}


## --- Counter consumables (FOIL 1+) -------------------------------------------
## Given to enemies at battle start. Symbolic names the spawner resolves.
const COUNTER_CONSUMABLES_BY_ARCHETYPE: Dictionary = {
	FOILEnums.Archetype.MELEE_AGGRO:    "defense_potion",
	FOILEnums.Archetype.RANGED_KITE:    "speed_potion",
	FOILEnums.Archetype.MAGIC_OFFENSE:  "magic_resist_potion",
	FOILEnums.Archetype.HEALER_SUPPORT: "silence_scroll",
	FOILEnums.Archetype.TANK_WALL:      "armor_pierce_elixir",
	FOILEnums.Archetype.AOE_BLASTER:    "reflect_shield",
	FOILEnums.Archetype.DEBUFFER:       "purity_charm",
	FOILEnums.Archetype.HYBRID:         "generic_elixir",
}


## --- Counter gear slots (FOIL 4 only) ----------------------------------------
## Equipment hints. The spawner picks the best item from the enemy pool that
## matches the hint; if none exists, it falls back to the default gear.
const COUNTER_GEAR_BY_ARCHETYPE: Dictionary = {
	FOILEnums.Archetype.MELEE_AGGRO:    "thorn_armor",
	FOILEnums.Archetype.RANGED_KITE:    "fleet_boots",
	FOILEnums.Archetype.MAGIC_OFFENSE:  "magic_ward_robe",
	FOILEnums.Archetype.HEALER_SUPPORT: "silence_amulet",
	FOILEnums.Archetype.TANK_WALL:      "piercing_weapon",
	FOILEnums.Archetype.AOE_BLASTER:    "blast_barrier_plate",
	FOILEnums.Archetype.DEBUFFER:       "clarity_charm",
	FOILEnums.Archetype.HYBRID:         "balanced_kit",
}


# =============================================================================
# PUBLIC API
# =============================================================================

## Build an enemy team configuration Dictionary.
##
## Parameters:
##   profile        — FOILProfile for the player character being countered.
##   foil_level     — 0–4 effective level (already resolved from renown or mission override).
##   base_enemy_pool — Array of Dictionaries representing default enemy templates
##                     for this encounter. Each entry should at minimum contain a
##                     "job" key. Copied, not mutated.
##   party_size     — Number of enemies to produce (defaults to 4 for standard fights).
##
## Returns:
##   {
##     "foil_level": int,
##     "dominant_archetype": int,
##     "enemies": Array[Dictionary],   # Each enemy config: job, consumable, gear_hint, role.
##     "ai_hints": Dictionary,         # Team-level behavior directives (FOIL 3+).
##     "notes": Array[String],         # Human-readable log of what was applied.
##   }
static func build_enemy_team(
	profile: FOILProfile,
	foil_level: int,
	base_enemy_pool: Array = [],
	party_size: int = 4
) -> Dictionary:
	var config: Dictionary = {
		"foil_level": foil_level,
		"dominant_archetype": FOILEnums.Archetype.HYBRID,
		"enemies": [],
		"ai_hints": {},
		"notes": [],
	}

	config["enemies"] = _seed_enemies(base_enemy_pool, party_size)

	# FOIL 0 — Oblivious. Also the safe fallback when we don't have enough data
	# to counter meaningfully; overtightening on a 1-battle sample is worse
	# than doing nothing.
	if profile == null or foil_level <= FOILEnums.FOILLevel.OBLIVIOUS:
		config["notes"].append("FOIL 0: no adaptation, using base pool")
		return config

	if not profile.has_sufficient_data():
		config["notes"].append(
			"Insufficient data (%d battles); falling back to FOIL 0 behavior" % profile.battles_in_window
		)
		return config

	config["dominant_archetype"] = profile.dominant_archetype

	var archetype: int = profile.dominant_archetype

	# FOIL 1+: Aware — consumables to mitigate the dominant approach.
	if foil_level >= FOILEnums.FOILLevel.AWARE:
		_apply_consumables(config["enemies"], archetype, false)
		config["notes"].append("FOIL 1: counter consumables distributed")

	# FOIL 2+: Prepared — swap half the team to counter jobs.
	if foil_level >= FOILEnums.FOILLevel.PREPARED:
		var swap_count: int = maxi(1, config["enemies"].size() / 2)
		_apply_counter_jobs(config["enemies"], archetype, profile, swap_count)
		config["notes"].append("FOIL 2: %d counter jobs applied" % swap_count)

	# FOIL 3+: Strategic — add team-level AI hints.
	if foil_level >= FOILEnums.FOILLevel.STRATEGIC:
		config["ai_hints"] = _build_ai_hints(profile)
		config["notes"].append("FOIL 3: AI hints configured")

	# FOIL 4: Mastery — full counter team, upgraded consumables, hard-counter gear.
	if foil_level >= FOILEnums.FOILLevel.MASTERY:
		_apply_counter_jobs(config["enemies"], archetype, profile, config["enemies"].size())
		_apply_consumables(config["enemies"], archetype, true)
		_apply_counter_gear(config["enemies"], archetype)
		config["notes"].append("FOIL 4: hard-counter composition, gear, elite consumables")

	return config


# =============================================================================
# ENEMY SEEDING
# =============================================================================

static func _seed_enemies(base_enemy_pool: Array, party_size: int) -> Array:
	var result: Array = []
	# If the pool is empty, seed generic placeholders — spawner will substitute.
	if base_enemy_pool.is_empty():
		for i in party_size:
			result.append(_blank_enemy_entry())
		return result

	# Clone (and cycle if pool smaller than party).
	for i in party_size:
		var source: Dictionary = base_enemy_pool[i % base_enemy_pool.size()]
		result.append(_clone_enemy_entry(source))
	return result


static func _blank_enemy_entry() -> Dictionary:
	return {
		"job": "",
		"role": "default",
		"consumable": "",
		"gear_hint": "",
	}


static func _clone_enemy_entry(source: Dictionary) -> Dictionary:
	var entry := _blank_enemy_entry()
	entry["job"] = source.get("job", "")
	entry["role"] = source.get("role", "default")
	# Preserve any extra keys the spawner might read.
	for key in source:
		if not entry.has(key):
			entry[key] = source[key]
	return entry


# =============================================================================
# LEVEL 1 — CONSUMABLES
# =============================================================================

static func _apply_consumables(enemies: Array, archetype: int, elite: bool) -> void:
	var consumable: String = COUNTER_CONSUMABLES_BY_ARCHETYPE.get(
		archetype, COUNTER_CONSUMABLES_BY_ARCHETYPE[FOILEnums.Archetype.HYBRID]
	)
	# At FOIL 4, upgrade the tag so the spawner can pick the elite variant.
	if elite:
		consumable = "elite_" + consumable

	for entry in enemies:
		entry["consumable"] = consumable


# =============================================================================
# LEVEL 2 / 4 — COUNTER JOBS
# =============================================================================

static func _apply_counter_jobs(
	enemies: Array,
	archetype: int,
	profile: FOILProfile,
	swap_count: int
) -> void:
	var counter_roles: Array = COUNTER_JOBS_BY_ARCHETYPE.get(
		archetype, COUNTER_JOBS_BY_ARCHETYPE[FOILEnums.Archetype.HYBRID]
	)

	# Let the secondary archetype also contribute if the player is a clear hybrid.
	var top_two := profile.get_top_archetypes(2)
	if top_two.size() >= 2 and top_two[1] != archetype:
		var secondary_roles: Array = COUNTER_JOBS_BY_ARCHETYPE.get(top_two[1], [])
		if not secondary_roles.is_empty():
			# Interleave so the team isn't 100% one-note.
			counter_roles = _interleave(counter_roles, secondary_roles)

	var clamped_swap: int = mini(swap_count, enemies.size())
	for i in clamped_swap:
		var role: String = counter_roles[i % counter_roles.size()]
		enemies[i]["role"] = role
		# Clear the seeded job so spawner knows to resolve from role.
		enemies[i]["job"] = ""


static func _interleave(a: Array, b: Array) -> Array:
	var merged: Array = []
	var max_len: int = maxi(a.size(), b.size())
	for i in max_len:
		if i < a.size():
			merged.append(a[i])
		if i < b.size():
			merged.append(b[i])
	return merged


# =============================================================================
# LEVEL 3 — AI HINTS
# =============================================================================

static func _build_ai_hints(profile: FOILProfile) -> Dictionary:
	var hints: Dictionary = {
		"target_priority":   "default",
		"formation":         "default",
		"engagement_range":  "default",
		"defensive_posture": false,
	}

	# Healer in the party → prioritize taking them out first.
	if profile.support_tendency >= 0.2:
		hints["target_priority"] = "focus_healer"

	# AOE-heavy player → spread formation so one cast can't hit everyone.
	if profile.aoe_tendency >= 0.35:
		hints["formation"] = "spread"
	else:
		hints["formation"] = "bunched"

	# Ranged/kiter player → close the gap. Melee player → hold/zone at range.
	if profile.avg_engagement_distance >= 3.0:
		hints["engagement_range"] = "close_aggressively"
	elif profile.avg_engagement_distance <= 1.5:
		hints["engagement_range"] = "maintain_distance"

	# Low-aggression players (slow/methodical) → turtle up, punish committed moves.
	if profile.aggression <= 0.4:
		hints["defensive_posture"] = true

	# Dominant archetype shortcut for the AI controller to specialize further.
	hints["dominant_archetype"] = profile.dominant_archetype

	return hints


# =============================================================================
# LEVEL 4 — COUNTER GEAR
# =============================================================================

static func _apply_counter_gear(enemies: Array, archetype: int) -> void:
	var gear: String = COUNTER_GEAR_BY_ARCHETYPE.get(
		archetype, COUNTER_GEAR_BY_ARCHETYPE[FOILEnums.Archetype.HYBRID]
	)
	for entry in enemies:
		entry["gear_hint"] = gear
