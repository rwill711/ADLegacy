class_name UnitEnums
## Shared enums and helpers for units — team alignment, facing direction, state.
## Kept separate from GridEnums so unit-specific changes don't churn the grid.


## --- Team alignment ----------------------------------------------------------
## Units owned by each side in a battle. NEUTRAL is for monsters / story NPCs
## that don't belong to either the player or the main enemy force.
enum Team {
	PLAYER,
	ENEMY,
	NEUTRAL,
}


## --- Facing direction --------------------------------------------------------
## 4 cardinal directions, chosen by the player at end of turn.
## Ordering matters: NORTH, EAST, SOUTH, WEST (clockwise starting from -Y in
## grid coordinates, i.e. "up the screen"). This pairs cleanly with the grid's
## +X = east / +Y = south convention.
enum Facing {
	NORTH,
	EAST,
	SOUTH,
	WEST,
}


## --- Unit state --------------------------------------------------------------
enum UnitState {
	IDLE,       # Waiting for their turn / between actions
	MOVING,     # Walking a path
	ACTING,     # Executing a skill / ability
	DEFEATED,   # HP hit 0
}


## --- Team display colors -----------------------------------------------------
## Used by the placeholder capsule renderer until real art lands.
const TEAM_COLORS: Dictionary = {
	Team.PLAYER:  Color(0.25, 0.55, 1.0),   # cool blue
	Team.ENEMY:   Color(0.95, 0.35, 0.35),  # warm red
	Team.NEUTRAL: Color(0.85, 0.85, 0.4),   # yellow
}


# =============================================================================
# FACING HELPERS
# =============================================================================

## Unit vector (grid coordinate delta) for a given facing.
## +X = east, +Y = south (screen-space-like) matches GridMap convention.
static func facing_to_vector(facing: Facing) -> Vector2i:
	match facing:
		Facing.NORTH: return Vector2i(0, -1)
		Facing.EAST:  return Vector2i(1, 0)
		Facing.SOUTH: return Vector2i(0, 1)
		Facing.WEST:  return Vector2i(-1, 0)
	return Vector2i.ZERO


## Y-axis rotation (radians) that a facing arrow or model should use.
## Paired with grid→world axis mapping (world.z ← grid.y), NORTH = looking
## toward -Z = rotation 0; each subsequent facing adds 90°.
static func facing_to_y_rotation(facing: Facing) -> float:
	match facing:
		Facing.NORTH: return 0.0
		Facing.EAST:  return -PI * 0.5
		Facing.SOUTH: return PI
		Facing.WEST:  return PI * 0.5
	return 0.0


## Best facing to look from `from` toward `to`. If tied (diagonal), picks the
## axis with the larger absolute delta — stable for equal deltas.
static func facing_toward(from: Vector2i, to: Vector2i) -> Facing:
	var delta: Vector2i = to - from
	if absi(delta.x) >= absi(delta.y):
		return Facing.EAST if delta.x >= 0 else Facing.WEST
	return Facing.SOUTH if delta.y >= 0 else Facing.NORTH


## The facing opposite to the given one. Used for rear-attack detection.
static func opposite_facing(facing: Facing) -> Facing:
	match facing:
		Facing.NORTH: return Facing.SOUTH
		Facing.EAST:  return Facing.WEST
		Facing.SOUTH: return Facing.NORTH
		Facing.WEST:  return Facing.EAST
	return Facing.NORTH


## Angle (in "facing steps") between two facings, always 0..2.
## 0 = same facing, 1 = perpendicular (flank), 2 = opposite (rear).
## Used by the battle system to pick front/side/rear damage modifiers.
static func facing_delta(a: Facing, b: Facing) -> int:
	var diff: int = absi(int(a) - int(b))
	# Mod 4, then fold: facing_delta(N, W) should be 1, not 3.
	diff = diff % 4
	if diff > 2:
		diff = 4 - diff
	return diff


## Which side (front / flank / rear) is `attacker` striking `defender` from?
## Returns 0 = front, 1 = flank, 2 = rear. Uses the attacker's position
## relative to the defender and the defender's facing.
## If attacker and defender are on the same tile, defaults to flank.
static func attack_side(
	attacker_coord: Vector2i,
	defender_coord: Vector2i,
	defender_facing: Facing
) -> int:
	if attacker_coord == defender_coord:
		return 1
	var approach := facing_toward(defender_coord, attacker_coord)
	return facing_delta(defender_facing, approach)


# =============================================================================
# TEAM HELPERS
# =============================================================================

static func team_color(team: Team) -> Color:
	return TEAM_COLORS.get(team, Color.WHITE)


static func teams_are_hostile(a: Team, b: Team) -> bool:
	if a == b:
		return false
	# Neutrals are hostile to everyone for now. Tune later if we want faction
	# relationships (e.g., undead hostile only to living).
	return true
