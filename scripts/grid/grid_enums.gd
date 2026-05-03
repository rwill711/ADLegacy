class_name GridEnums
## Shared enums, constants, and lookup tables for the grid / terrain system.
##
## All rendering-independent knowledge about tile kinds lives here so the
## visualizer, pathfinder, and battle system can pull the same values from
## one source of truth.


## --- Terrain Types -----------------------------------------------------------
## Kept aligned with the original C# GridTile.cs reference so designers can
## carry over existing numbers when we flesh out real biomes.
enum TerrainType {
	GRASS,
	STONE,
	FOREST,
	MOUNTAIN,
	WATER,
	DEEP_WATER,
	LAVA,
	FIRE,
	VOID,
}


## --- Highlight States --------------------------------------------------------
## The visualizer renders an overlay layer in these colors on top of the base
## terrain color. Only one highlight state is active per tile at a time.
enum HighlightState {
	NONE,
	HOVER,
	MOVE_RANGE,
	ATTACK_RANGE,
	PATH,
	TARGET,
	DEPLOY_ZONE,
}


## --- World-space constants ---------------------------------------------------
## Size (in world units) of one grid tile. The rest of the rendering pipeline
## derives from this — change it here only, never hardcode elsewhere.
const TILE_WORLD_SIZE: float = 1.0

## Vertical distance between two consecutive elevation steps.
## Small enough that a 3-tile hill reads as a hill, not a tower.
const HEIGHT_STEP: float = 0.3

## Base thickness below height-0 tiles so the floor has visual presence.
const FLOOR_THICKNESS: float = 0.2


## --- Terrain properties ------------------------------------------------------
## Base walkability (before occupancy checks).
## FOREST = tree (impassable), MOUNTAIN = rock (impassable),
## WATER = passable but costs 2x movement.
const TERRAIN_WALKABLE: Dictionary = {
	TerrainType.GRASS:      true,
	TerrainType.STONE:      true,
	TerrainType.FOREST:     false,  # tree — blocks movement
	TerrainType.MOUNTAIN:   false,  # rock — blocks movement
	TerrainType.WATER:      true,   # shallow water — wading is slow but possible
	TerrainType.DEEP_WATER: false,
	TerrainType.LAVA:       true,   # walkable but damaging
	TerrainType.FIRE:       true,   # ditto
	TerrainType.VOID:       false,
}

## Movement cost multiplier. Water is wading-speed (2x). Trees/rocks are walls.
const TERRAIN_MOVEMENT_COST: Dictionary = {
	TerrainType.GRASS:      1.0,
	TerrainType.STONE:      1.0,
	TerrainType.FOREST:     1.0,   # never reached (not walkable)
	TerrainType.MOUNTAIN:   1.0,   # never reached (not walkable)
	TerrainType.WATER:      2.0,   # wading costs twice as much
	TerrainType.DEEP_WATER: 1.0,
	TerrainType.LAVA:       1.0,
	TerrainType.FIRE:       1.0,
	TerrainType.VOID:       1.0,
}

## Which terrain types block line-of-sight for ranged (non-magic) attacks.
const TERRAIN_BLOCKS_LOS: Dictionary = {
	TerrainType.GRASS:      false,
	TerrainType.STONE:      false,
	TerrainType.FOREST:     true,   # trees block LOS
	TerrainType.MOUNTAIN:   false,  # rocks don't block LOS
	TerrainType.WATER:      false,
	TerrainType.DEEP_WATER: false,
	TerrainType.LAVA:       false,
	TerrainType.FIRE:       false,
	TerrainType.VOID:       false,
}

## Damage inflicted on any unit that ends its turn on this tile.
const TERRAIN_DAMAGE_PER_TURN: Dictionary = {
	TerrainType.GRASS:      0,
	TerrainType.STONE:      0,
	TerrainType.FOREST:     0,
	TerrainType.MOUNTAIN:   0,
	TerrainType.WATER:      0,
	TerrainType.DEEP_WATER: 0,
	TerrainType.LAVA:       10,
	TerrainType.FIRE:       5,
	TerrainType.VOID:       0,
}

## Display colors for placeholder flat-shaded tiles.
## Used by the visualizer until art lands.
const TERRAIN_COLORS: Dictionary = {
	TerrainType.GRASS:      Color(0.4, 0.75, 0.4),
	TerrainType.STONE:      Color(0.6, 0.6, 0.6),
	TerrainType.FOREST:     Color(0.2, 0.5, 0.25),
	TerrainType.MOUNTAIN:   Color(0.5, 0.42, 0.33),
	TerrainType.WATER:      Color(0.3, 0.5, 0.85),
	TerrainType.DEEP_WATER: Color(0.15, 0.28, 0.6),
	TerrainType.LAVA:       Color(0.95, 0.3, 0.05),
	TerrainType.FIRE:       Color(1.0, 0.55, 0.1),
	TerrainType.VOID:       Color(0.05, 0.05, 0.08),
}

## Overlay colors used by SetHighlight. Alpha blends over the terrain color.
const HIGHLIGHT_COLORS: Dictionary = {
	HighlightState.NONE:         Color(0, 0, 0, 0),
	HighlightState.HOVER:        Color(1.0, 1.0, 0.5, 0.55),
	HighlightState.MOVE_RANGE:   Color(1.0, 0.55, 0.1, 0.75),
	HighlightState.ATTACK_RANGE: Color(1.0, 0.4, 0.4, 0.55),
	HighlightState.PATH:         Color(0.3, 1.0, 0.3, 0.7),
	HighlightState.TARGET:       Color(1.0, 0.2, 0.2, 0.75),
	HighlightState.DEPLOY_ZONE:  Color(0.3, 0.6, 1.0, 0.45),
}


## --- Helpers -----------------------------------------------------------------
static func terrain_color(terrain: TerrainType) -> Color:
	return TERRAIN_COLORS.get(terrain, Color(1, 0, 1))  # magenta = missing entry


static func highlight_color(state: HighlightState) -> Color:
	return HIGHLIGHT_COLORS.get(state, Color(0, 0, 0, 0))


static func is_terrain_walkable(terrain: TerrainType) -> bool:
	return TERRAIN_WALKABLE.get(terrain, false)


static func terrain_movement_cost(terrain: TerrainType) -> float:
	return TERRAIN_MOVEMENT_COST.get(terrain, 1.0)


static func terrain_damage_per_turn(terrain: TerrainType) -> int:
	return TERRAIN_DAMAGE_PER_TURN.get(terrain, 0)


static func terrain_blocks_los(terrain: TerrainType) -> bool:
	return TERRAIN_BLOCKS_LOS.get(terrain, false)
