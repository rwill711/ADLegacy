class_name Pathfinder
## A* + Dijkstra utilities for grid movement.
##
## All methods are static. The grid is queried read-only; no mutation of tiles
## or occupancy — the caller (move controller) updates the grid when a move
## actually commits.
##
## Ruleset:
##   - Walkability: tile must be terrain-walkable AND not occupied by another
##     unit (friend OR foe — Creative ruling: no pass-through).
##   - Jump: can step from tile A → B only if |A.height - B.height| <= unit.jump.
##   - Cost: each step costs the destination tile's terrain movement_cost.
##     Forest = 1.5, mountain = 2.0, grass/stone = 1.0.
##
## The unit's own current tile is always considered passable (so we can
## leave it) and is never included in the reachable set (no "staying in place"
## disguised as a move).


# =============================================================================
# PUBLIC API
# =============================================================================

## Return the set of tiles reachable by `unit` from its current coord within
## its move budget. Dictionary maps Vector2i → float cost-to-reach.
## The unit's starting coord is NOT in the returned set.
##
## `passable_ids` — unit_ids of allies the unit can walk through (but not
## end their turn on). Populated by the caller from the ally unit list.
static func reachable_tiles(
	grid: BattleGrid,
	unit: Unit,
	passable_ids: Dictionary = {}
) -> Dictionary:
	var out: Dictionary = {}
	if grid == null or unit == null or unit.stats == null:
		return out

	var start: Vector2i = unit.coord
	var budget: float = float(unit.stats.move_range)
	var jump: int = unit.stats.jump

	# Dijkstra: each tile's lowest-cost reach gets recorded.
	# Priority-less ordered insertion via a sorted list is fine at grid scales
	# we're dealing with (12x12 = 144 max). If maps grow past ~50x50 we'll
	# swap to a binary heap.
	var frontier: Array = [{"coord": start, "cost": 0.0}]
	var best_cost: Dictionary = {start: 0.0}

	while not frontier.is_empty():
		var current: Dictionary = _pop_lowest_cost(frontier)
		var coord: Vector2i = current["coord"]
		var cost: float = current["cost"]

		# Stale entry (we found a cheaper path after queuing this one).
		if cost > best_cost.get(coord, INF):
			continue

		for neighbor in grid.neighbors(coord):
			if not _can_step_to(grid, unit, coord, neighbor.coord, jump, passable_ids):
				continue
			var step_cost: float = neighbor.movement_cost()
			var new_cost: float = cost + step_cost
			if new_cost > budget:
				continue
			if new_cost >= best_cost.get(neighbor.coord, INF):
				continue
			best_cost[neighbor.coord] = new_cost
			frontier.append({"coord": neighbor.coord, "cost": new_cost})

	# Strip the start tile — "don't move" isn't a move.
	best_cost.erase(start)

	# Strip ally-occupied tiles — unit can pass through allies but not stop on them.
	for coord in best_cost.keys():
		var tile := grid.get_tile(coord)
		if tile != null and tile.occupant_id != &"" and passable_ids.has(tile.occupant_id):
			best_cost.erase(coord)

	return best_cost


## A* pathfind from the unit's current coord to `goal`.
## Returns an Array[Vector2i] including start and goal, or [] if unreachable
## within the unit's jump constraints and occupancy rules.
##
## IMPORTANT: this ignores the unit's move budget. Use it for path computation
## to a tile already known to be in the reachable set; the caller is
## responsible for budget-checking via reachable_tiles() first.
static func find_path(
	grid: BattleGrid,
	unit: Unit,
	goal: Vector2i,
	passable_ids: Dictionary = {}
) -> Array:
	if grid == null or unit == null or unit.stats == null:
		return []

	var start: Vector2i = unit.coord
	if start == goal:
		return [start]
	if grid.get_tile(goal) == null:
		return []

	var jump: int = unit.stats.jump

	var open_set: Array = [{"coord": start, "f": 0.0}]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}

	while not open_set.is_empty():
		var current_entry: Dictionary = _pop_lowest_f(open_set)
		var current: Vector2i = current_entry["coord"]

		if current == goal:
			return _reconstruct_path(came_from, current)

		var current_g: float = g_score.get(current, INF)

		for neighbor in grid.neighbors(current):
			if not _can_step_to(grid, unit, current, neighbor.coord, jump, passable_ids):
				continue
			var tentative_g: float = current_g + neighbor.movement_cost()
			if tentative_g >= g_score.get(neighbor.coord, INF):
				continue
			came_from[neighbor.coord] = current
			g_score[neighbor.coord] = tentative_g
			var f: float = tentative_g + float(BattleGrid.manhattan(neighbor.coord, goal))
			open_set.append({"coord": neighbor.coord, "f": f})

	return []


# =============================================================================
# PREDICATES
# =============================================================================

## Can `unit` step from `from` to `to` this turn?
## Considers: terrain walkable, occupancy, jump delta.
## Special case: a tile currently occupied by `unit` itself is passable
## (we're the one leaving it). Tiles occupied by a unit_id in `passable_ids`
## (allies) can be stepped through but not stopped on — reachable_tiles
## strips those from the final output.
static func _can_step_to(
	grid: BattleGrid,
	unit: Unit,
	from: Vector2i,
	to: Vector2i,
	jump: int,
	passable_ids: Dictionary = {}
) -> bool:
	var from_tile := grid.get_tile(from)
	var to_tile := grid.get_tile(to)
	if to_tile == null or from_tile == null:
		return false

	# Terrain check.
	if not to_tile.is_terrain_walkable():
		return false

	# Occupancy check — allow own tile and passable allies; block everything else.
	if to_tile.occupant_id != &"" and to_tile.occupant_id != unit.unit_id:
		if not passable_ids.has(to_tile.occupant_id):
			return false
	if to_tile.object_id != &"":
		return false

	# Elevation / jump check.
	if absi(from_tile.height - to_tile.height) > jump:
		return false

	return true


# =============================================================================
# HELPERS
# =============================================================================

## Pop the entry with the smallest 'cost' key from an array-of-dicts queue.
static func _pop_lowest_cost(queue: Array) -> Dictionary:
	var best_idx: int = 0
	var best_cost: float = queue[0]["cost"]
	for i in range(1, queue.size()):
		var c: float = queue[i]["cost"]
		if c < best_cost:
			best_cost = c
			best_idx = i
	var winner: Dictionary = queue[best_idx]
	queue.remove_at(best_idx)
	return winner


## Same pattern but for A*'s f-score.
static func _pop_lowest_f(queue: Array) -> Dictionary:
	var best_idx: int = 0
	var best_f: float = queue[0]["f"]
	for i in range(1, queue.size()):
		var f: float = queue[i]["f"]
		if f < best_f:
			best_f = f
			best_idx = i
	var winner: Dictionary = queue[best_idx]
	queue.remove_at(best_idx)
	return winner


static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
