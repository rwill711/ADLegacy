class_name BattleGrid extends Resource
## Container for the tactical grid. Owns the 2D array of GridTile and exposes
## queries the pathfinder, battle manager, and visualizer consume.
##
## All coordinates are Vector2i with (x, y) semantics. The 2D array is stored
## as rows-of-columns internally so iteration order is (y outer, x inner).
##
## Resource so it can be saved, inspected in the editor, and duplicated for
## tests without touching the file system.


## --- Dimensions --------------------------------------------------------------
@export var width: int = 0
@export var height: int = 0

## 2D grid, stored as Array of Array. Untyped at the outer level because
## Godot 4's typed-array spec does not yet support nested type parameters
## (`Array[Array[GridTile]]` is rejected by the parser).
@export var tiles: Array = []


## --- Signals (runtime only, not persisted) -----------------------------------
signal tile_changed(coord: Vector2i)
signal occupancy_changed(coord: Vector2i)


# =============================================================================
# CONSTRUCTION
# =============================================================================

## Build an empty map of the given size, every tile GRASS at height 0.
## Call this or pass tiles in manually; do NOT leave tiles empty and query.
static func create(p_width: int, p_height: int) -> BattleGrid:
	var map := BattleGrid.new()
	map.width = p_width
	map.height = p_height
	map.tiles = []
	for y in p_height:
		var row: Array = []
		for x in p_width:
			row.append(GridTile.create(Vector2i(x, y)))
		map.tiles.append(row)
	return map


# =============================================================================
# TILE ACCESS
# =============================================================================

func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.y >= 0 and coord.x < width and coord.y < height


func get_tile(coord: Vector2i) -> GridTile:
	if not is_in_bounds(coord):
		return null
	return tiles[coord.y][coord.x]


func set_tile(coord: Vector2i, tile: GridTile) -> void:
	if not is_in_bounds(coord):
		push_error("BattleGrid.set_tile: out of bounds %s" % [coord])
		return
	tile.coord = coord
	tiles[coord.y][coord.x] = tile
	tile_changed.emit(coord)


## Change a tile's terrain type and notify the visualizer.
func set_terrain(coord: Vector2i, terrain: GridEnums.TerrainType) -> void:
	var tile := get_tile(coord)
	if tile == null:
		return
	tile.terrain = terrain
	tile_changed.emit(coord)


## Remove a chest from a tile and notify the visualizer so the prop disappears.
func clear_chest(coord: Vector2i) -> void:
	var tile := get_tile(coord)
	if tile == null:
		return
	tile.chest_loot_tag = ""
	tile_changed.emit(coord)


## Iterate every tile once. Order: row-major (y then x).
func iter_tiles() -> Array:
	var out: Array = []
	for row in tiles:
		for tile in row:
			out.append(tile)
	return out


# =============================================================================
# NEIGHBORS / DISTANCE
# =============================================================================

const NEIGHBOR_OFFSETS: Array = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

## 4-connected neighbors (no diagonals). Out-of-bounds entries are skipped.
func neighbors(coord: Vector2i) -> Array:
	var result: Array = []
	for offset in NEIGHBOR_OFFSETS:
		var n_coord: Vector2i = coord + offset
		if is_in_bounds(n_coord):
			result.append(tiles[n_coord.y][n_coord.x])
	return result


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## All tiles within `radius` manhattan steps (inclusive). The origin is included.
## This is a cheap query for ability range previews; does NOT respect walls,
## elevation, or occupancy — just geometric distance.
func tiles_in_range(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for y in range(maxi(0, center.y - radius), mini(height, center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(width, center.x + radius + 1)):
			var c := Vector2i(x, y)
			if manhattan(center, c) <= radius:
				out.append(tiles[y][x])
	return out


# =============================================================================
# OCCUPANCY
# =============================================================================

func set_occupant(coord: Vector2i, id: StringName) -> bool:
	var tile := get_tile(coord)
	if tile == null:
		return false
	tile.occupant_id = id
	occupancy_changed.emit(coord)
	return true


func clear_occupant(coord: Vector2i) -> void:
	var tile := get_tile(coord)
	if tile == null:
		return
	tile.occupant_id = &""
	occupancy_changed.emit(coord)


func get_occupant(coord: Vector2i) -> StringName:
	var tile := get_tile(coord)
	return tile.occupant_id if tile != null else &""


## Search the grid for the tile currently occupied by a given id.
## Returns the coord, or Vector2i(-1, -1) if not found.
func find_occupant(id: StringName) -> Vector2i:
	if id == &"":
		return Vector2i(-1, -1)
	for row in tiles:
		for tile in row:
			if tile.occupant_id == id:
				return tile.coord
	return Vector2i(-1, -1)


# =============================================================================
# HIGHLIGHTS (runtime UI state, not persisted)
# =============================================================================

func set_highlight(coord: Vector2i, state: GridEnums.HighlightState) -> void:
	var tile := get_tile(coord)
	if tile == null:
		return
	if tile.highlight_state == state:
		return
	tile.highlight_state = state
	tile_changed.emit(coord)


## Bulk clear — call between UI phases (e.g., after a move finishes).
func clear_all_highlights() -> void:
	for row in tiles:
		for tile in row:
			if tile.highlight_state != GridEnums.HighlightState.NONE:
				tile.highlight_state = GridEnums.HighlightState.NONE
				tile_changed.emit(tile.coord)


# =============================================================================
# ELEVATION / JUMP RULES
# =============================================================================

## Can a unit with the given jump tolerance step from `from` into `to`?
## Only checks height delta; caller is responsible for walkability/occupancy.
func can_step_between(from: Vector2i, to: Vector2i, jump: int) -> bool:
	var a := get_tile(from)
	var b := get_tile(to)
	if a == null or b == null:
		return false
	return absi(a.height - b.height) <= jump
