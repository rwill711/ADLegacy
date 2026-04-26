class_name LootLibrary
## Central catalog of loot tables for enemies and chests.


# =============================================================================
# ENEMY DROP TABLES  (by job name)
# =============================================================================

static func enemy_drops(job_name: StringName) -> LootTable:
	match job_name:
		&"rogue":
			return LootTable.create([
				{"tag": "health_potion",  "weight": 50},
				{"tag": "speed_potion",   "weight": 30},
				{"tag": "gold_small",     "weight": 20},
			], 1, 60)
		&"squire":
			return LootTable.create([
				{"tag": "health_potion",  "weight": 40},
				{"tag": "defense_potion", "weight": 35},
				{"tag": "gold_small",     "weight": 25},
			], 1, 60)
		&"white_mage":
			return LootTable.create([
				{"tag": "mana_potion",    "weight": 50},
				{"tag": "health_potion",  "weight": 30},
				{"tag": "gold_small",     "weight": 20},
			], 1, 60)
		_:
			return LootTable.create([
				{"tag": "gold_small", "weight": 100},
			], 1, 40)


# =============================================================================
# CHEST LOOT TABLES
# =============================================================================

static func standard_chest() -> LootTable:
	return LootTable.create([
		{"tag": "health_potion",         "weight": 35},
		{"tag": "mana_potion",           "weight": 25},
		{"tag": "defense_potion",        "weight": 15},
		{"tag": "speed_potion",          "weight": 10},
		{"tag": "armor_pierce_elixir",   "weight": 10},
		{"tag": "gold_medium",           "weight": 5},
	], 2, 100)  # always drops, 2 items


static func elite_chest() -> LootTable:
	return LootTable.create([
		{"tag": "health_potion",         "weight": 20},
		{"tag": "mana_potion",           "weight": 20},
		{"tag": "generic_elixir",        "weight": 20},
		{"tag": "armor_pierce_elixir",   "weight": 15},
		{"tag": "speed_potion",          "weight": 10},
		{"tag": "gold_large",            "weight": 15},
	], 3, 100)  # always drops, 3 items


# =============================================================================
# DISPLAY NAMES  (for the rewards UI)
# =============================================================================

static func display_name(tag: String) -> String:
	match tag:
		"health_potion":        return "Health Potion"
		"mana_potion":          return "Mana Potion"
		"defense_potion":       return "Defense Potion"
		"speed_potion":         return "Speed Potion"
		"magic_resist_potion":  return "Magic Resist Potion"
		"armor_pierce_elixir":  return "Armor Pierce Elixir"
		"generic_elixir":       return "Elixir"
		"gold_small":           return "Gold (small)"
		"gold_medium":          return "Gold (medium)"
		"gold_large":           return "Gold (large)"
	return tag.capitalize().replace("_", " ")
