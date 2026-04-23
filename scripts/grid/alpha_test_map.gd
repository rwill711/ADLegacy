class_name AlphaTestMap
## Factory for the Alpha test battlefield.
## Per Creative Director open-question #5: 12×12 grid with a central 3×3 hill.
## Plus a splash of water/forest variety so the visualizer sell-tests color,
## walkability, and terrain cost at the same time.


const WIDTH: int = 12
const HEIGHT: int = 12

const HILL_ORIGIN: Vector2i = Vector2i(5, 5)  # top-left of the 3×3 hill
const HILL_SIZE: int = 3
const HILL_ELEVATION: int = 1


## Build the standard Alpha test map.
static func build() -> GridMap:
	var map := GridMap.create(WIDTH, HEIGHT)

	# Central 3x3 hill.
	for dy in HILL_SIZE:
		for dx in HILL_SIZE:
			var coord := Vector2i(HILL_ORIGIN.x + dx, HILL_ORIGIN.y + dy)
			var tile := map.get_tile(coord)
			if tile == null:
				continue
			tile.height = HILL_ELEVATION
			tile.terrain = GridEnums.TerrainType.STONE

	# Two small forest patches on the west side so pathfinding has a cost
	# difference to chew on once Phase 3 lands.
	_set_terrain(map, Vector2i(1, 2), GridEnums.TerrainType.FOREST)
	_set_terrain(map, Vector2i(2, 2), GridEnums.TerrainType.FOREST)
	_set_terrain(map, Vector2i(1, 3), GridEnums.TerrainType.FOREST)

	# Water pond in the top-right corner (proves impassable terrain works).
	_set_terrain(map, Vector2i(9, 1), GridEnums.TerrainType.WATER)
	_set_terrain(map, Vector2i(10, 1), GridEnums.TerrainType.WATER)
	_set_terrain(map, Vector2i(10, 2), GridEnums.TerrainType.WATER)

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


static func _set_terrain(map: GridMap, coord: Vector2i, terrain: GridEnums.TerrainType) -> void:
	var tile := map.get_tile(coord)
	if tile == null:
		return
	tile.terrain = terrain
