class_name MapBuilder
## Generates a BattleGrid from a MapTemplate.
## Extracted from AlphaTestMap so the same procedural logic works for any
## template. AlphaTestMap.build() is kept as a convenience wrapper.


## Build a grid from the given template. Uses a fresh RNG each call.
static func build(template: MapTemplate) -> BattleGrid:
	var map := BattleGrid.create(template.width, template.height)

	# --- Fixed stone hill (optional) ----------------------------------------
	if template.hill_size > 0:
		for dy in template.hill_size:
			for dx in template.hill_size:
				var coord := Vector2i(template.hill_origin.x + dx, template.hill_origin.y + dy)
				var tile := map.get_tile(coord)
				if tile == null:
					continue
				tile.height  = template.hill_elevation
				tile.terrain = GridEnums.TerrainType.STONE

	var reserved := _reserved_coords(template)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var candidates := _candidate_coords(map, reserved)

	_place_water_cluster(map, candidates, rng, template.water_count)
	_place_terrain(map, candidates, rng, GridEnums.TerrainType.FOREST,   template.tree_count)
	_place_terrain(map, candidates, rng, GridEnums.TerrainType.MOUNTAIN, template.rock_count)

	_randomize_elevation(map, template, reserved, rng)

	return map


# =============================================================================
# SPAWN POINTS  (fixed; don't change with template)
# =============================================================================

static func player_spawn_points() -> Array:
	return [Vector2i(1, 10), Vector2i(2, 11), Vector2i(3, 10)]


static func enemy_spawn_points() -> Array:
	return [Vector2i(10, 1), Vector2i(11, 2), Vector2i(10, 3)]


# =============================================================================
# HELPERS
# =============================================================================

static func _reserved_coords(template: MapTemplate) -> Dictionary:
	var reserved: Dictionary = {}

	for coord in player_spawn_points() + enemy_spawn_points():
		reserved[coord] = true
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			reserved[coord + off] = true

	if template.hill_size > 0:
		for dy in template.hill_size:
			for dx in template.hill_size:
				reserved[Vector2i(template.hill_origin.x + dx, template.hill_origin.y + dy)] = true

	return reserved


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


static func _place_water_cluster(
	map: BattleGrid,
	candidates: Array,
	rng: RandomNumberGenerator,
	count: int
) -> void:
	if candidates.is_empty() or count <= 0:
		return

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


static func _randomize_elevation(
	map: BattleGrid,
	template: MapTemplate,
	reserved: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var mid_threshold: float = template.elev_flat_chance + template.elev_mid_chance

	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if reserved.has(c):
				continue
			var t := map.get_tile(c)
			if t == null:
				continue
			if t.terrain == GridEnums.TerrainType.WATER:
				t.height = 0
				continue
			if t.terrain == GridEnums.TerrainType.STONE:
				continue
			var roll: float = rng.randf()
			if roll < template.elev_flat_chance:
				t.height = 0
			elif roll < mid_threshold:
				t.height = 1
			else:
				t.height = 2

	var offsets: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for _pass in range(15):
		var changed: bool = false
		for y in map.height:
			for x in map.width:
				var c := Vector2i(x, y)
				var t := map.get_tile(c)
				if t == null or t.terrain == GridEnums.TerrainType.STONE:
					continue
				for off in offsets:
					var nb := map.get_tile(c + off)
					if nb == null:
						continue
					if absi(t.height - nb.height) > 1:
						if t.height > nb.height:
							t.height = nb.height + 1
						else:
							t.height = nb.height - 1
						changed = true
		if not changed:
			break

	for y in map.height:
		for x in map.width:
			var t := map.get_tile(Vector2i(x, y))
			if t != null and t.terrain == GridEnums.TerrainType.WATER:
				t.height = 0
