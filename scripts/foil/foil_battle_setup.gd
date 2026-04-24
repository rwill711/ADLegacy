class_name FOILBattleSetup
## Glue layer. At battle start, produces the enemy-loadout configuration the
## UnitSpawner should build this encounter from.
##
## Pipeline (Phase 6):
##   1. Pull each player character's FOILProfile via FOILAnalyzer.
##   2. Pick a "primary" profile to counter (for Alpha: the first player
##      character in party order; post-Alpha: highest confidence profile).
##   3. Resolve FOIL level from DebugManager override, then renown (Alpha:
##      renown system unbuilt, defaults to 0).
##   4. Call FOILLoadoutBuilder with the profile + level + base pool.
##   5. Return everything the spawner / HUD / debug panel need.
##
## Static + stateless — safe to call mid-battle for previews too.


## --- Result shape -----------------------------------------------------------
## {
##   "level": int,              # 0-4, post-clamp
##   "level_source": String,    # "renown" | "override" | "default"
##   "profile": FOILProfile,    # primary-character profile (never null)
##   "primary_character": String,
##   "loadout": Dictionary,     # FOILLoadoutBuilder.build_enemy_team output
## }


# =============================================================================
# PUBLIC API
# =============================================================================

## Build an encounter config for a party of player units.
## `player_character_names` is the in-order list of display_names (FOIL keys).
## `base_enemy_pool` is an Array of Dictionaries like
##   [{"job": "rogue"}, {"job": "squire"}, {"job": "white_mage"}]
## `renown` defaults to 0 (renown system not in Alpha); a debug override
## via DebugManager.set_meta("foil_level_override", N) wins over renown.
static func build_encounter(
	player_character_names: Array,
	base_enemy_pool: Array,
	party_size: int = 3,
	renown: int = 0
) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var foil: Node = null
	var debug_mgr: Node = null
	if tree != null:
		foil = tree.root.get_node_or_null("FOILTracker")
		debug_mgr = tree.root.get_node_or_null("DebugManager")

	# --- Step 1: Build profiles for each player character ------------------
	var profiles_by_name: Dictionary = {}
	if foil != null:
		for name in player_character_names:
			if name is String and not name.is_empty():
				var p: FOILProfile = FOILAnalyzer.build_profile(foil, name)
				if p != null:
					profiles_by_name[name] = p

	# --- Step 2: Pick the primary profile to counter -----------------------
	var primary_name: String = _pick_primary_character(player_character_names, profiles_by_name)
	var profile: FOILProfile = profiles_by_name.get(primary_name, null)
	if profile == null:
		profile = FOILProfile.new()  # empty / no-data profile

	# --- Step 3: Resolve FOIL level ----------------------------------------
	var override_level: int = -1
	var source: String = "renown"
	if debug_mgr != null and debug_mgr.has_meta("foil_level_override"):
		override_level = int(debug_mgr.get_meta("foil_level_override"))
		source = "override"
	var level: int = FOILAnalyzer.resolve_foil_level(renown, override_level)
	if source == "renown" and renown == 0:
		source = "default"  # renown not wired → clearer tag than "renown"

	# --- Step 4: Build the loadout -----------------------------------------
	var loadout: Dictionary = FOILLoadoutBuilder.build_enemy_team(
		profile, level, base_enemy_pool, party_size
	)

	return {
		"level": level,
		"level_source": source,
		"profile": profile,
		"primary_character": primary_name,
		"profiles_by_name": profiles_by_name,
		"loadout": loadout,
	}


# =============================================================================
# PRIMARY CHARACTER SELECTION
# =============================================================================

## Choose who to counter. In Alpha, preference order:
##   1. The highest-confidence profile (most battles_in_window).
##   2. Ties broken by party order (first in list wins).
##   3. If no profiles exist (first battle ever), return the first name.
## Post-Alpha: could aggregate the whole party into a synthetic profile,
## but a single-character counter is more legible for testing.
static func _pick_primary_character(
	names: Array,
	profiles_by_name: Dictionary
) -> String:
	if names.is_empty():
		return ""
	var best_name: String = names[0]
	var best_confidence: float = -1.0
	for name in names:
		if not profiles_by_name.has(name):
			continue
		var p: FOILProfile = profiles_by_name[name]
		if p.confidence > best_confidence:
			best_confidence = p.confidence
			best_name = name
	return best_name
