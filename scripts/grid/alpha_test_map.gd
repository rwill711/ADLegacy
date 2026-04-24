class_name AlphaTestMap
## Factory for the Alpha test battlefield.
## Fixed: 12×12 grid with a central 3×3 stone hill.
## Randomized each instance: a handful of trees, rocks, and water tiles
## scattered around the map, keeping spawn zones and the hill clear.


const WIDTH: int = 12
const HEIGHT: int = 12

const HILL_ORIGIN: Vector2i = Vector2i(5, 5)
const HILL_SIZE: int = 3
const HILL_ELEVATION: int = 1

## How many of each terrain object to scatter per instance.
const TREE_COUNT:  int = 5
const ROCK_COUNT:  int = 4
const WATER_COUNT: int = 3


## Build the standard Alpha test map with randomized terrain.
static func build() -> BattleGrid:
	var map := BattleGrid.create(WIDTH, HEIGHT)

	# Fixed: central 3×3 elevated stone hill.
	for dy in HILL_SIZE:
		for dx in HILL_SIZE:
			var coord := Vector2i(HILL_ORIGIN.x + dx, HILL_ORIGIN.y + dy)
			var tile := map.get_tile(coord)
			if tile == null:
				continue
			tile.height = HILL_ELEVATION
			tile.terrain = GridEnums.TerrainType.STONE

	# Randomized terrain objects placed on clear tiles.
	var reserved := _reserved_coords()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var candidates := _candidate_coords(map, reserved)
	_place_terrain(map, candidates, rng, GridEnums.TerrainType.FOREST,   TREE_COUNT)
	_place_terrain(map, candidates, rng, GridEnums.TerrainType.MOUNTAIN, ROCK_COUNT)
	_place_terrain(map, candidates, rng, GridEnums.TerrainType.WATER,    WATER_COUNT)

	return map


## Alpha spawn points. Keep these in one place so the battle scene doesn't
## hardcode coordinates that drift out of sync with the map layout.
static func player_spawn_points() -> Array:
	return [
		Vector2i(1, 10),
		Vector2i(2, 11),
		Vector2i(3, 10),
	]


static func enemy_spawn_points() -> Array:
	return [
		Vector2i(10, 1),
		Vector2i(11, 2),
		Vector2i(10, 3),
	]


# =============================================================================
# HELPERS
# =============================================================================

## Coords that must stay clear: spawn points, hill tiles, and a 1-tile buffer
## around spawn zones so units don't spawn surrounded by obstacles.
static func _reserved_coords() -> Dictionary:
	var reserved: Dictionary = {}

	var all_spawns: Array = player_spawn_points() + enemy_spawn_points()
	for coord in all_spawns:
		reserved[coord] = true
		# 1-tile buffer around each spawn
		for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			reserved[coord + off] = true

	# Hill tiles
	for dy in HILL_SIZE:
		for dx in HILL_SIZE:
			reserved[Vector2i(HILL_ORIGIN.x + dx, HILL_ORIGIN.y + dy)] = true

	return reserved


## All in-bounds, GRASS tiles not in the reserved set.
static func _candidate_coords(map: BattleGrid, reserved: Dictionary) -> Array:
	var out: Array = []
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if reserved.has(c):
				continue
			var tile := map.get_tile(c)
			if tile != null and tile.terrain == GridEnums.TerrainType.GRASS:
				out.append(c)
	return out


## Pick `count` random candidates (without replacement) and set their terrain.
## Removes placed coords from `candidates` so subsequent calls don't overlap.
static func _place_terrain(
	map: BattleGrid,
	candidates: Array,
	rng: RandomNumberGenerator,
	terrain: GridEnums.TerrainType,
	count: int
) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and candidates.size() > 0 and attempts < 200:
		attempts += 1
		var idx: int = rng.randi_range(0, candidates.size() - 1)
		var coord: Vector2i = candidates[idx]
		candidates.remove_at(idx)
		var tile := map.get_tile(coord)
		if tile == null:
			continue
		tile.terrain = terrain
		placed += 1


static func _set_terrain(map: BattleGrid, coord: Vector2i, terrain: GridEnums.TerrainType) -> void:
	var tile := map.get_tile(coord)
	if tile == null:
		return
	tile.terrain = terrain
