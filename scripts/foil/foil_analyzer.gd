class_name FOILAnalyzer
## The BRAIN of the FOIL system.
## Reads FOILTracker data + permanent trait tags → produces a populated FOILProfile.
## Purely static; no state of its own. Safe to call any time battle is not mid-action.
##
## Pipeline:
##   1. Filter rolling-window battles to this character.
##   2. Flatten all action records.
##   3. Compute skill-category weights (normalized usage frequency).
##   4. Compute behavioral stats (distance, AOE, aggression, support).
##   5. Compute archetype weights by combining category signals + trait tag signals.
##   6. Pick dominant archetype (HYBRID if the top two are too close).
##   7. Compute confidence from sample size.


## --- Tuning knobs ------------------------------------------------------------

## How much weight each trait tag adds to its mapped archetype (before normalization).
## Trait tags should meaningfully push the profile even with thin battle data,
## but not completely dominate a player who has pivoted playstyle recently.
const TRAIT_WEIGHT_PER_TAG: float = 0.35

## How close (in normalized weight) the top two archetypes can be before we
## label the profile HYBRID instead of committing to a dominant archetype.
const HYBRID_MARGIN: float = 0.12

## Confidence scales linearly from 0 → 1 as battles_in_window goes
## from MIN_BATTLES up to ROLLING_WINDOW_SIZE.
## Below MIN_BATTLES, confidence is clamped to 0 (FOIL treats as no data).


## --- Trait tag → archetype signal map ----------------------------------------
## Tags come from titles, job mastery, story choices. They persist outside the
## rolling window, so they let FOIL react to long-term identity even after the
## player swaps jobs or goes through a losing streak that flushes the window.
const TRAIT_ARCHETYPE_SIGNALS: Dictionary = {
	"master_swordsman":    FOILEnums.Archetype.MELEE_AGGRO,
	"melee_range_fighter": FOILEnums.Archetype.MELEE_AGGRO,
	"berserker":           FOILEnums.Archetype.MELEE_AGGRO,
	"duelist":             FOILEnums.Archetype.MELEE_AGGRO,

	"master_archer":       FOILEnums.Archetype.RANGED_KITE,
	"sniper":              FOILEnums.Archetype.RANGED_KITE,
	"marksman":            FOILEnums.Archetype.RANGED_KITE,

	"pyromancer":          FOILEnums.Archetype.MAGIC_OFFENSE,
	"archmage":            FOILEnums.Archetype.MAGIC_OFFENSE,
	"elementalist":        FOILEnums.Archetype.MAGIC_OFFENSE,

	"white_mage":          FOILEnums.Archetype.HEALER_SUPPORT,
	"field_medic":         FOILEnums.Archetype.HEALER_SUPPORT,
	"cleric":              FOILEnums.Archetype.HEALER_SUPPORT,

	"juggernaut":          FOILEnums.Archetype.TANK_WALL,
	"fortress":            FOILEnums.Archetype.TANK_WALL,
	"shield_bearer":       FOILEnums.Archetype.TANK_WALL,

	"bomber":              FOILEnums.Archetype.AOE_BLASTER,
	"artillerist":         FOILEnums.Archetype.AOE_BLASTER,
	"stormcaller":         FOILEnums.Archetype.AOE_BLASTER,

	"shadow_agent":        FOILEnums.Archetype.DEBUFFER,
	"curse_bearer":        FOILEnums.Archetype.DEBUFFER,
	"saboteur":            FOILEnums.Archetype.DEBUFFER,
}


## --- Skill category → archetype signal map -----------------------------------
## Each logged action casts a vote for one archetype based on its category.
## MOVEMENT_ABILITY and ITEM_USE don't vote; they're neutral context.
const CATEGORY_ARCHETYPE_SIGNALS: Dictionary = {
	FOILEnums.SkillCategory.PHYSICAL_MELEE:  FOILEnums.Archetype.MELEE_AGGRO,
	FOILEnums.SkillCategory.PHYSICAL_RANGED: FOILEnums.Archetype.RANGED_KITE,
	FOILEnums.SkillCategory.MAGIC_DAMAGE:    FOILEnums.Archetype.MAGIC_OFFENSE,
	FOILEnums.SkillCategory.HEALING:         FOILEnums.Archetype.HEALER_SUPPORT,
	FOILEnums.SkillCategory.BUFF:            FOILEnums.Archetype.HEALER_SUPPORT,
	FOILEnums.SkillCategory.DEBUFF:          FOILEnums.Archetype.DEBUFFER,
}


# =============================================================================
# PUBLIC API
# =============================================================================

## Build a FOILProfile for the given character from tracker data + trait tags.
## Safe to call with no battle data; returns a thin profile seeded from tags only.
static func build_profile(
	tracker: FOILTracker,
	character_name: String,
	trait_tags: Array[String] = []
) -> FOILProfile:
	var profile := FOILProfile.new()
	# Copy (not reference-share) so later caller mutations don't leak in.
	for tag in trait_tags:
		profile.trait_tags.append(tag)

	_init_archetype_weights(profile)

	if tracker == null:
		_finalize_thin_profile(profile, trait_tags)
		return profile

	var battles := tracker.get_battles_for_character(character_name)
	if battles.is_empty():
		_finalize_thin_profile(profile, trait_tags)
		return profile

	var actions: Array[FOILActionRecord] = []
	for battle in battles:
		for action in battle.actions:
			actions.append(action)

	profile.battles_in_window = battles.size()
	profile.total_actions_analyzed = actions.size()
	profile.confidence = _compute_confidence(battles.size())

	_compute_category_weights(profile, actions)
	_compute_behavioral_stats(profile, actions)
	_compute_archetype_weights(profile, actions, trait_tags)
	_select_dominant_archetype(profile)

	return profile


## Resolve the FOIL level to use for an encounter.
## If mission_override >= 0, that value wins (story battles).
## Otherwise we scale from accumulated renown.
static func resolve_foil_level(renown: int, mission_override: int = -1) -> int:
	if mission_override >= 0:
		return clampi(mission_override, 0, FOILEnums.FOILLevel.MASTERY)
	return FOILEnums.foil_level_from_renown(renown)


# =============================================================================
# PROFILE BUILDERS — SKILL CATEGORIES
# =============================================================================

static func _compute_category_weights(
	profile: FOILProfile,
	actions: Array[FOILActionRecord]
) -> void:
	var counts: Dictionary = {}
	for action in actions:
		var cat: int = action.skill_category
		counts[cat] = counts.get(cat, 0) + 1

	var total: int = actions.size()
	if total <= 0:
		profile.category_weights = {}
		return

	var weights: Dictionary = {}
	for cat in counts:
		weights[cat] = float(counts[cat]) / float(total)
	profile.category_weights = weights


# =============================================================================
# PROFILE BUILDERS — BEHAVIORAL STATS
# =============================================================================

static func _compute_behavioral_stats(
	profile: FOILProfile,
	actions: Array[FOILActionRecord]
) -> void:
	if actions.is_empty():
		return

	var total_actions: int = actions.size()
	var offensive_actions: int = 0
	var aoe_offensive: int = 0
	var support_actions: int = 0
	var distance_sum: float = 0.0
	var distance_samples: int = 0

	for action in actions:
		var is_offense := _is_offensive(action.skill_category)
		var is_support := _is_support(action.skill_category)

		if is_offense:
			offensive_actions += 1
			if action.is_aoe:
				aoe_offensive += 1
			# Distance only meaningful on offensive actions (hit an enemy).
			distance_sum += float(action.engagement_distance)
			distance_samples += 1

		if is_support:
			support_actions += 1

	# Aggression = share of turns spent attacking.
	profile.aggression = float(offensive_actions) / float(total_actions)

	# Support tendency = share of turns spent healing/buffing.
	profile.support_tendency = float(support_actions) / float(total_actions)

	# AOE tendency is scoped to offensive actions only — healing an ally
	# with an AOE heal shouldn't make us build a spread-out enemy formation.
	profile.aoe_tendency = 0.0 if offensive_actions == 0 else float(aoe_offensive) / float(offensive_actions)

	# Average engagement distance (manhattan). 2.0 default if no offensive data yet.
	profile.avg_engagement_distance = 2.0 if distance_samples == 0 else distance_sum / float(distance_samples)


# =============================================================================
# PROFILE BUILDERS — ARCHETYPE WEIGHTS
# =============================================================================

static func _compute_archetype_weights(
	profile: FOILProfile,
	actions: Array[FOILActionRecord],
	trait_tags: Array[String]
) -> void:
	# 1. Category votes: each action contributes 1 vote to its mapped archetype.
	for action in actions:
		var archetype = CATEGORY_ARCHETYPE_SIGNALS.get(action.skill_category, -1)
		if archetype == -1:
			continue
		profile.archetype_weights[archetype] = profile.archetype_weights.get(archetype, 0.0) + 1.0

	# 2. Trait tag signals: permanent identity nudges archetype scores.
	_apply_trait_archetype_signals(profile, trait_tags)

	# 3. AOE-heavy players get an AOE_BLASTER boost even if their damage
	#    type would otherwise count them as MAGIC_OFFENSE or RANGED_KITE.
	if profile.aoe_tendency >= 0.4 and not actions.is_empty():
		profile.archetype_weights[FOILEnums.Archetype.AOE_BLASTER] = \
			profile.archetype_weights.get(FOILEnums.Archetype.AOE_BLASTER, 0.0) \
			+ float(actions.size()) * profile.aoe_tendency * 0.5

	# 4. Normalize so the max weight is 1.0 and others scale proportionally.
	_normalize_archetype_weights(profile)


static func _apply_trait_archetype_signals(
	profile: FOILProfile,
	trait_tags: Array[String]
) -> void:
	for tag in trait_tags:
		var key := tag.to_lower()
		if not TRAIT_ARCHETYPE_SIGNALS.has(key):
			continue
		var archetype = TRAIT_ARCHETYPE_SIGNALS[key]
		profile.archetype_weights[archetype] = \
			profile.archetype_weights.get(archetype, 0.0) + TRAIT_WEIGHT_PER_TAG


static func _normalize_archetype_weights(profile: FOILProfile) -> void:
	var max_weight: float = 0.0
	for archetype in profile.archetype_weights:
		max_weight = maxf(max_weight, profile.archetype_weights[archetype])
	if max_weight <= 0.0:
		return
	for archetype in profile.archetype_weights:
		profile.archetype_weights[archetype] = profile.archetype_weights[archetype] / max_weight


static func _select_dominant_archetype(profile: FOILProfile) -> void:
	var top_archetype: int = FOILEnums.Archetype.HYBRID
	var top_weight: float = -1.0
	var second_weight: float = -1.0

	for archetype in profile.archetype_weights:
		var w: float = profile.archetype_weights[archetype]
		if w > top_weight:
			second_weight = top_weight
			top_weight = w
			top_archetype = archetype
		elif w > second_weight:
			second_weight = w

	# Nothing voted → HYBRID.
	if top_weight <= 0.0:
		profile.dominant_archetype = FOILEnums.Archetype.HYBRID
		return

	# Top two archetypes are within HYBRID_MARGIN of each other → the player
	# isn't committed to a single playstyle; treat as hybrid.
	if second_weight >= 0.0 and (top_weight - second_weight) < HYBRID_MARGIN:
		profile.dominant_archetype = FOILEnums.Archetype.HYBRID
		return

	profile.dominant_archetype = top_archetype


# =============================================================================
# HELPERS
# =============================================================================

static func _init_archetype_weights(profile: FOILProfile) -> void:
	profile.archetype_weights = {
		FOILEnums.Archetype.MELEE_AGGRO:    0.0,
		FOILEnums.Archetype.RANGED_KITE:    0.0,
		FOILEnums.Archetype.MAGIC_OFFENSE:  0.0,
		FOILEnums.Archetype.HEALER_SUPPORT: 0.0,
		FOILEnums.Archetype.TANK_WALL:      0.0,
		FOILEnums.Archetype.AOE_BLASTER:    0.0,
		FOILEnums.Archetype.DEBUFFER:       0.0,
		FOILEnums.Archetype.HYBRID:         0.0,
	}


static func _finalize_thin_profile(profile: FOILProfile, trait_tags: Array[String]) -> void:
	_apply_trait_archetype_signals(profile, trait_tags)
	_normalize_archetype_weights(profile)
	profile.dominant_archetype = FOILEnums.Archetype.HYBRID
	profile.battles_in_window = 0
	profile.total_actions_analyzed = 0
	profile.confidence = 0.0


static func _compute_confidence(battles_in_window: int) -> float:
	if battles_in_window < FOILEnums.ROLLING_WINDOW_MIN_BATTLES:
		return 0.0
	var span: float = float(FOILEnums.ROLLING_WINDOW_SIZE - FOILEnums.ROLLING_WINDOW_MIN_BATTLES)
	if span <= 0.0:
		return 1.0
	var numerator: float = float(battles_in_window - FOILEnums.ROLLING_WINDOW_MIN_BATTLES)
	return clampf(numerator / span, 0.0, 1.0)


static func _is_offensive(category: FOILEnums.SkillCategory) -> bool:
	return category == FOILEnums.SkillCategory.PHYSICAL_MELEE \
		or category == FOILEnums.SkillCategory.PHYSICAL_RANGED \
		or category == FOILEnums.SkillCategory.MAGIC_DAMAGE


static func _is_support(category: FOILEnums.SkillCategory) -> bool:
	return category == FOILEnums.SkillCategory.HEALING \
		or category == FOILEnums.SkillCategory.BUFF
