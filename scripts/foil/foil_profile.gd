class_name FOILProfile extends Resource
## The analyzed output of a character's FOIL data.
## Built by FOILAnalyzer from tracker data + trait tags.
## Consumed by FOILLoadoutBuilder to configure enemy teams.

## --- Archetype Weights ---
## Each archetype gets a 0.0–1.0 weight. Higher = more dominant.
## These are normalized so the highest is always 1.0.
@export var archetype_weights: Dictionary = {}
# Example: { Archetype.MELEE_AGGRO: 0.8, Archetype.TANK_WALL: 0.3, ... }

## The single dominant archetype (highest weight). HYBRID if no clear winner.
@export var dominant_archetype: FOILEnums.Archetype = FOILEnums.Archetype.HYBRID

## --- Skill Category Weights ---
## Normalized usage frequency of each skill category.
@export var category_weights: Dictionary = {}

## --- Behavioral Stats ---
@export var avg_engagement_distance: float = 2.0
@export var aoe_tendency: float = 0.0  ## 0.0 = never uses AOE, 1.0 = always AOE
@export var aggression: float = 0.5    ## 0.0 = passive/defensive, 1.0 = always attacking
@export var support_tendency: float = 0.0  ## How often they heal/buff vs attack

## --- Trait Tags ---
## Permanent tags from character progression. These persist outside the rolling window.
## Format: Array of strings like ["master_swordsman", "pyromancer", "glass_cannon"]
@export var trait_tags: Array[String] = []

## --- Confidence ---
## How much data we have. Low confidence = FOIL should be conservative.
@export var battles_in_window: int = 0
@export var total_actions_analyzed: int = 0
@export var confidence: float = 0.0  ## 0.0–1.0, based on battles_in_window vs minimum


## Returns true if we have enough data for FOIL to meaningfully adapt.
func has_sufficient_data() -> bool:
	return battles_in_window >= FOILEnums.ROLLING_WINDOW_MIN_BATTLES


## Returns the top N archetypes by weight.
func get_top_archetypes(n: int = 2) -> Array:
	var sorted_pairs: Array = []
	for archetype in archetype_weights:
		sorted_pairs.append({"archetype": archetype, "weight": archetype_weights[archetype]})
	sorted_pairs.sort_custom(func(a, b): return a["weight"] > b["weight"])
	var result: Array = []
	for i in mini(n, sorted_pairs.size()):
		result.append(sorted_pairs[i]["archetype"])
	return result


## Returns true if the character has a specific trait tag.
func has_trait(tag: String) -> bool:
	return trait_tags.has(tag)


## Returns the weight for a given skill category, defaulting to 0.
func get_category_weight(category: FOILEnums.SkillCategory) -> float:
	return category_weights.get(category, 0.0)


func to_dict() -> Dictionary:
	return {
		"archetype_weights": archetype_weights,
		"dominant_archetype": dominant_archetype,
		"category_weights": category_weights,
		"avg_engagement_distance": avg_engagement_distance,
		"aoe_tendency": aoe_tendency,
		"aggression": aggression,
		"support_tendency": support_tendency,
		"trait_tags": trait_tags,
		"battles_in_window": battles_in_window,
		"total_actions_analyzed": total_actions_analyzed,
		"confidence": confidence
	}
