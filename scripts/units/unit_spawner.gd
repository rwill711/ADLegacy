class_name UnitSpawner extends Node
## Spawns the Alpha roster: 3 player jobs + 3 enemy units onto the grid.
##
## Phase 6: the enemy half of the roster now comes from a FOIL loadout
## Dictionary (produced by FOILBattleSetup). When no loadout is supplied
## the spawner falls back to the Alpha default (mirrored roster), so the
## project still runs standalone without FOIL data.
##
## ADR-004: Stats are now derived from BaseAttributes via StatFormulas.
## Consumable bonuses have been rescaled to match the tighter stat ranges.


## --- Config -----------------------------------------------------------------
@export var log_spawns: bool = true


## --- State ------------------------------------------------------------------
var _units: Array = []


## --- Spawn order / jobs -----------------------------------------------------
const PLAYER_JOB_ORDER: Array = [
	&"rogue", &"squire", &"white_mage",
]

## Enemy default — used when no FOIL loadout is supplied (first battle, FOIL 0,
## or when FOIL has insufficient data and falls back internally).
const DEFAULT_ENEMY_JOB_ORDER: Array = [
	&"rogue", &"squire", &"white_mage",
]


## --- Loadout vocabulary translation -----------------------------------------
## The FOILLoadoutBuilder returns symbolic role tags like "ranged_kiter".
## Alpha only ships 3 jobs, so every role maps to one of those three. The
## choice is a tactical approximation — the *behavior* will be close even if
## the name doesn't exactly match (e.g., "silencer" → Rogue because Rogue is
## the fastest disruption piece we have).
## When Phase 10+ adds more jobs, this table grows without changing the
## builder.
const ROLE_TO_JOB_NAME: Dictionary = {
	# MELEE_AGGRO counters (stay at range or burst fast)
	"ranged_kiter":      &"white_mage",
	"spear_user":        &"squire",
	"burst_mage":        &"white_mage",
	# RANGED_KITE counters (close the gap)
	"rusher":            &"rogue",
	"dash_assassin":     &"rogue",
	"barrier_tank":      &"squire",
	# MAGIC_OFFENSE counters (disrupt casters)
	"silencer":          &"rogue",
	"magic_resist_tank": &"squire",
	"mp_drainer":        &"rogue",
	# HEALER_SUPPORT counters (finish them fast)
	"burst_damage":      &"rogue",
	"assassin":          &"rogue",
	# TANK_WALL counters (bypass defense)
	"armor_breaker":     &"rogue",
	"true_damage":       &"rogue",
	"status_caster":     &"white_mage",
	# AOE_BLASTER counters (spread out / shield)
	"spread_skirmisher": &"rogue",
	"stealth_operator":  &"rogue",
	"reflective_mage":   &"white_mage",
	# DEBUFFER counters (cleanse / resist)
	"cleansing_support": &"white_mage",
	"resist_tank":       &"squire",
	# HYBRID counters (balanced)
	"generalist":        &"squire",
	"flex_support":      &"squire",
	"balanced_damage":   &"squire",
}


## Consumable → stat bonus map for FOIL level 1+. Applied to each enemy at
## spawn as a flat stat boost. Elite variants (FOIL 4) scale x2.
##
## ADR-004: Rescaled from the old 75–110 HP era to the new 30–50 HP era.
## A defense_potion giving +5 DEF when max DEF is ~10 would be +50%, which
## is absurd. New values are tuned to be noticeable but not dominant (~15-20%
## of a typical stat).
const CONSUMABLE_STAT_BONUSES: Dictionary = {
	"defense_potion":       {"defense": 2},
	"speed_potion":         {"speed": 2},
	"magic_resist_potion":  {"resistance": 2},
	"armor_pierce_elixir":  {"attack": 2},
	"generic_elixir":       {"max_hp": 5, "hp": 5},
	# Status-dependent — leave empty until the status system lands.
	"silence_scroll":       {},
	"reflect_shield":       {},
	"purity_charm":         {},
}


# =============================================================================
# PUBLIC API
# =============================================================================

## Populate the grid with the Alpha roster.
## `enemy_loadout` is the Dictionary returned by FOILLoadoutBuilder
## (via FOILBattleSetup.build_encounter). If null or empty, the default
## mirrored roster is used — keeps FOIL optional.
func spawn_alpha_roster(
	grid: BattleGrid,
	parent: Node3D,
	enemy_loadout: Dictionary = {}
) -> Array:
	_units.clear()

	var player_spawns: Array = AlphaTestMap.player_spawn_points()
	var enemy_spawns: Array = AlphaTestMap.enemy_spawn_points()

	# --- Player side (unchanged) -----------------------------------------
	for i in PLAYER_JOB_ORDER.size():
		var job_name: StringName = PLAYER_JOB_ORDER[i]
		var coord: Vector2i = player_spawns[i]
		var unit := _spawn_one(
			job_name, UnitEnums.Team.PLAYER,
			"player_%s" % job_name, coord,
			grid, parent
		)
		if unit != null:
			_units.append(unit)

	# --- Enemy side (FOIL-aware) -----------------------------------------
	var enemy_entries: Array = _resolve_enemy_entries(enemy_loadout)
	var ai_hints: Dictionary = enemy_loadout.get("ai_hints", {})

	for i in enemy_entries.size():
		if i >= enemy_spawns.size():
			break  # more enemies requested than spawn points
		var entry: Dictionary = enemy_entries[i]
		var coord: Vector2i = enemy_spawns[i]
		var unit := _spawn_one(
			entry["job_name"], UnitEnums.Team.ENEMY,
			"enemy_%d_%s" % [i, entry["job_name"]], coord,
			grid, parent
		)
		if unit == null:
			continue

		_apply_consumable(unit, entry.get("consumable", ""))
		_apply_ai_hints(unit, ai_hints)
		# gear_hint skipped for Alpha — no equipment system yet. It's stored
		# for the record so post-Alpha code can wire it without changing
		# the builder's contract.
		unit.gear_hint = entry.get("gear_hint", "")

		_units.append(unit)

	_auto_face_units(_units)

	return _units


## Retrieve a spawned unit by ID. Returns null if not found.
func get_unit(unit_id: StringName) -> Unit:
	for unit in _units:
		if unit.unit_id == unit_id:
			return unit
	return null


func get_units_on_team(team: UnitEnums.Team) -> Array:
	var out: Array = []
	for unit in _units:
		if unit.team == team:
			out.append(unit)
	return out


func get_all_units() -> Array:
	return _units.duplicate()


## Preview what the Phase 6 loadout would produce given the current FOIL
## state. Used by the debug overlay's FOIL tab.
static func default_base_enemy_pool() -> Array:
	var out: Array = []
	for job_name in DEFAULT_ENEMY_JOB_ORDER:
		out.append({"job": String(job_name), "role": "default"})
	return out


# =============================================================================
# LOADOUT RESOLUTION
# =============================================================================

## Walk the loadout's enemies[] array and resolve each entry to a concrete
## job + consumable + gear hint. Falls back to the default roster if no
## loadout was supplied.
func _resolve_enemy_entries(loadout: Dictionary) -> Array:
	var enemies: Array = loadout.get("enemies", [])
	if enemies.is_empty():
		# No loadout data → default mirrored roster, no consumables, no hints.
		var fallback: Array = []
		for job_name in DEFAULT_ENEMY_JOB_ORDER:
			fallback.append({
				"job_name": job_name,
				"consumable": "",
				"gear_hint": "",
			})
		return fallback

	var resolved: Array = []
	for entry in enemies:
		var job_name: StringName = _resolve_job_name(entry)
		resolved.append({
			"job_name": job_name,
			"consumable": entry.get("consumable", ""),
			"gear_hint": entry.get("gear_hint", ""),
		})
	return resolved


## If the builder left `job` set (from base pool), prefer it. Otherwise
## look up the role → job mapping. Falls back to Squire as the "neutral
## generalist" job if nothing matches — every enemy needs a valid job.
static func _resolve_job_name(entry: Dictionary) -> StringName:
	var raw_job: String = String(entry.get("job", ""))
	if not raw_job.is_empty():
		return StringName(raw_job)
	var role: String = String(entry.get("role", ""))
	if role.is_empty() or role == "default":
		return &"squire"
	if ROLE_TO_JOB_NAME.has(role):
		return ROLE_TO_JOB_NAME[role]
	push_warning("UnitSpawner: unknown role '%s', defaulting to squire" % role)
	return &"squire"


# =============================================================================
# CONSUMABLE / AI HINT APPLICATION
# =============================================================================

## Apply a consumable's stat bonus to a freshly-spawned enemy. Handles the
## `elite_<name>` prefix (FOIL 4) by doubling the bonus.
func _apply_consumable(unit: Unit, consumable_tag: String) -> void:
	if unit == null or unit.stats == null or consumable_tag.is_empty():
		return

	var elite: bool = consumable_tag.begins_with("elite_")
	var base_tag: String = consumable_tag.substr(6) if elite else consumable_tag

	unit.consumable_tag = consumable_tag  # stored for inspection / UI

	if not CONSUMABLE_STAT_BONUSES.has(base_tag):
		return
	var bonus: Dictionary = CONSUMABLE_STAT_BONUSES[base_tag]
	var multiplier: int = 2 if elite else 1

	for stat_name in bonus:
		var delta: int = int(bonus[stat_name]) * multiplier
		match stat_name:
			"attack":     unit.stats.attack += delta
			"defense":    unit.stats.defense += delta
			"magic":      unit.stats.magic += delta
			"resistance": unit.stats.resistance += delta
			"speed":      unit.stats.speed += delta
			"max_hp":     unit.stats.max_hp += delta
			"hp":         unit.stats.hp = mini(unit.stats.max_hp, unit.stats.hp + delta)
			"max_mp":     unit.stats.max_mp += delta
			"mp":         unit.stats.mp = mini(unit.stats.max_mp, unit.stats.mp + delta)


## Stash AI hints on the unit so ActionController's enemy-scoring code can
## read them when it's this unit's turn. Team-level hints (formation,
## defensive_posture) are duplicated onto every enemy for simplicity —
## the AI reads them off `active_unit.ai_hints`.
func _apply_ai_hints(unit: Unit, ai_hints: Dictionary) -> void:
	if unit == null:
		return
	unit.ai_hints = ai_hints.duplicate(true)


# =============================================================================
# INTERNALS — SPAWN + FACING
# =============================================================================

func _spawn_one(
	job_name: StringName,
	team: UnitEnums.Team,
	unit_id: StringName,
	coord: Vector2i,
	grid: BattleGrid,
	parent: Node3D
) -> Unit:
	var job := JobLibrary.get_job(job_name)
	if job == null:
		push_error("UnitSpawner: no job '%s'" % job_name)
		return null

	var tile: GridTile = grid.get_tile(coord)
	if tile == null:
		push_error("UnitSpawner: spawn coord %s out of bounds" % [coord])
		return null

	if tile.is_occupied():
		push_warning("UnitSpawner: tile %s already occupied; skipping %s" % [coord, unit_id])
		return null

	var unit := Unit.new()
	unit.name = String(unit_id)
	parent.add_child(unit)
	unit.initialize(unit_id, job.display_name, team, job, coord)
	unit.place_on_tile(tile, true)

	grid.set_occupant(coord, unit_id)

	if log_spawns:
		print("[spawn] %s (%s) team=%s at %s | HP:%d ATK:%d DEF:%d SPD:%d" % [
			unit_id, job.display_name, _team_label(team), coord,
			unit.stats.max_hp, unit.stats.attack, unit.stats.defense, unit.stats.speed
		])

	return unit


func _auto_face_units(units: Array) -> void:
	var player_centroid := _centroid_of_team(units, UnitEnums.Team.PLAYER)
	var enemy_centroid := _centroid_of_team(units, UnitEnums.Team.ENEMY)

	for unit in units:
		var look_at: Vector2i = enemy_centroid if unit.team == UnitEnums.Team.PLAYER else player_centroid
		unit.face_toward(look_at)


func _centroid_of_team(units: Array, team: UnitEnums.Team) -> Vector2i:
	var sum := Vector2i.ZERO
	var count := 0
	for unit in units:
		if unit.team == team:
			sum += unit.coord
			count += 1
	if count == 0:
		return Vector2i.ZERO
	return Vector2i(sum.x / count, sum.y / count)


static func _team_label(team: UnitEnums.Team) -> String:
	match team:
		UnitEnums.Team.PLAYER:  return "PLAYER"
		UnitEnums.Team.ENEMY:   return "ENEMY"
		UnitEnums.Team.NEUTRAL: return "NEUTRAL"
	return "?"
