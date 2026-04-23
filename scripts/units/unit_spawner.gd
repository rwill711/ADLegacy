class_name UnitSpawner extends Node
## Spawns the Alpha roster: 3 player jobs + 3 enemy jobs onto the grid.
## Kept as a Node so it can live in the main scene and survive reload.
##
## Spawn points come from AlphaTestMap so map layout + unit placement can't
## drift out of sync. Enemy jobs mirror the player roster for now; FOIL's
## LoadoutBuilder will take over enemy selection once the battle setup path
## is wired up in Phase 6.


## --- Config -----------------------------------------------------------------
@export var log_spawns: bool = true


## --- State ------------------------------------------------------------------
var _units: Array = []


## --- Spawn order / jobs -----------------------------------------------------
## Parallel arrays: player_jobs[i] spawns at player_spawn_points()[i], etc.
const PLAYER_JOB_ORDER: Array = [
	&"rogue", &"squire", &"white_mage",
]

## Enemy roster intentionally mirrors player for Alpha so combat is legible.
## FOIL will override this at battle setup when Phase 6 lands.
const ENEMY_JOB_ORDER: Array = [
	&"rogue", &"squire", &"white_mage",
]


# =============================================================================
# PUBLIC API
# =============================================================================

## Populate the grid with the Alpha roster. Returns the full unit list.
## Parent is the Node3D the Unit instances get added under — the spawner
## doesn't care what it is, the main scene just passes itself.
func spawn_alpha_roster(grid: GridMap, parent: Node3D) -> Array:
	_units.clear()

	var player_spawns: Array = AlphaTestMap.player_spawn_points()
	var enemy_spawns: Array = AlphaTestMap.enemy_spawn_points()

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

	for i in ENEMY_JOB_ORDER.size():
		var job_name: StringName = ENEMY_JOB_ORDER[i]
		var coord: Vector2i = enemy_spawns[i]
		var unit := _spawn_one(
			job_name, UnitEnums.Team.ENEMY,
			"enemy_%s" % job_name, coord,
			grid, parent
		)
		if unit != null:
			_units.append(unit)

	# Face each unit toward the opposite side of the map so initial facing reads
	# correctly from any camera angle — no one is awkwardly looking off-board.
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


# =============================================================================
# INTERNALS
# =============================================================================

func _spawn_one(
	job_name: StringName,
	team: UnitEnums.Team,
	unit_id: StringName,
	coord: Vector2i,
	grid: GridMap,
	parent: Node3D
) -> Unit:
	var job := JobLibrary.get_job(job_name)
	if job == null:
		push_error("UnitSpawner: no job '%s'" % job_name)
		return null

	var tile := grid.get_tile(coord)
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
		print("[spawn] %s (%s) team=%s at %s" % [
			unit_id, job.display_name, _team_label(team), coord
		])

	return unit


## Face player units toward the enemy side of the map and vice versa.
## Simple heuristic: compute the average coord of the other team and face
## each unit toward it. Keeps placeholder arrows reading correctly.
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
