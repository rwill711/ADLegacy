class_name AlphaTestMap
## Factory for the Alpha test battlefield.
## Fixed: 12×12 grid with a central 3×3 stone hill.
## Randomized each instance: scattered trees, rocks, a connected water cluster,
## and gentle elevation variation (no adjacent tiles differ by more than 1h).


const WIDTH: int = 12
const HEIGHT: int = 12

const HILL_ORIGIN: Vector2i = Vector2i(5, 5)
const HILL_SIZE: int = 3
const HILL_ELEVATION: int = 1

## How many of each terrain object to scatter per instance.
const TREE_COUNT:  int = 5
const ROCK_COUNT:  int = 4
const WATER_COUNT: int = 9  # tripled; placed as a connected cluster


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

	var reserved := _reserved_coords()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var candidates := _candidate_coords(map, reserved)

	# Water first so it stays at height 0 and elevation pass skips it.
	_place_water_cluster(map, candidates, rng, WATER_COUNT)
	_place_terrain(map, candidates, rng, GridEnums.TerrainType.FOREST,   TREE_COUNT)
	_place_terrain(map, candidates, rng, GridEnums.TerrainType.MOUNTAIN, ROCK_COUNT)

	# Gentle elevation randomization — stays within 1h of adjacent tiles.
	_randomize_elevation(map, reserved, rng)

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


## Place water as a single connected cluster by growing from a random seed.
## Removes placed coords from `candidates` so subsequent terrain passes skip them.
static func _place_water_cluster(
	map: BattleGrid,
	candidates: Array,
	rng: RandomNumberGenerator,
	count: int
) -> void:
	if candidates.is_empty() or count <= 0:
		return

	# Pick random seed from candidates.
	var seed_idx: int = rng.randi_range(0, candidates.size() - 1)
	var seed: Vector2i = candidates[seed_idx]
	candidates.remove_at(seed_idx)
	var tile := map.get_tile(seed)
	if tile != null:
		tile.terrain = GridEnums.TerrainType.WATER

	var placed: Array = [seed]
	var frontier: Array = [seed]

	while placed.size() < count and not frontier.is_empty():
		var fi: int = rng.randi_range(0, frontier.size() - 1)
		var fc: Vector2i = frontier[fi]

		# Collect adjacent tiles still in candidates.
		var adj: Array = []
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = fc + off
			if candidates.has(nc):
				adj.append(nc)

		if adj.is_empty():
			frontier.remove_at(fi)
			continue

		var ai: int = rng.randi_range(0, adj.size() - 1)
		var nc: Vector2i = adj[ai]
		candidates.erase(nc)
		var ntile := map.get_tile(nc)
		if ntile != null:
			ntile.terrain = GridEnums.TerrainType.WATER
		placed.append(nc)
		frontier.append(nc)


## Randomize elevation for non-reserved, non-water tiles so the map has gentle
## undulation. Uses a probabilistic pass then smooths so no adjacent tiles
## differ by more than 1 in height.
static func _randomize_elevation(
	map: BattleGrid,
	reserved: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	# Initial random assignment: ~65% stay flat, ~30% rise to 1, ~5% rise to 2.
	# Hill tiles and spawn/reserved tiles keep their existing heights.
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if reserved.has(c):
				continue
			var tile := map.get_tile(c)
			if tile == null:
				continue
			if tile.terrain == GridEnums.TerrainType.WATER:
				tile.height = 0
				continue
			if tile.terrain == GridEnums.TerrainType.STONE:
				continue  # hill stays at HILL_ELEVATION
			var roll: float = rng.randf()
			if roll < 0.65:
				tile.height = 0
			elif roll < 0.95:
				tile.height = 1
			else:
				tile.height = 2

	# Smooth until no adjacent pair differs by more than 1 (up to 15 passes).
	var offsets: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for _pass in range(15):
		var changed: bool = false
		for y in map.height:
			for x in map.width:
				var c := Vector2i(x, y)
				var tile := map.get_tile(c)
				if tile == null:
					continue
				if tile.terrain == GridEnums.TerrainType.STONE:
					continue  # hill is fixed
				for off in offsets:
					var nb := map.get_tile(c + off)
					if nb == null:
						continue
					if absi(tile.height - nb.height) > 1:
						# Lower the higher tile to be exactly 1 above the lower.
						if tile.height > nb.height:
							tile.height = nb.height + 1
						else:
							tile.height = nb.height - 1
						changed = true
		if not changed:
			break

	# Water always stays at height 0 after smoothing.
	for y in map.height:
		for x in map.width:
			var tile := map.get_tile(Vector2i(x, y))
			if tile != null and tile.terrain == GridEnums.TerrainType.WATER:
				tile.height = 0
