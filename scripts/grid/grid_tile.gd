class_name GridTile extends Resource
## One square on the tactical grid.
## Pure data — no rendering and no input. The visualizer reads this, not vice versa.
## Uniform coord system: +X = east, +Y = south (screen-space-ish, FFTA convention).


## --- Identity ---------------------------------------------------------------
@export var coord: Vector2i = Vector2i.ZERO

## Elevation in height-steps above the floor. A unit's Jump stat is compared
## against the delta between two adjacent tiles' heights to decide traversability.
@export var height: int = 0


## --- Terrain / movement rules -----------------------------------------------
@export var terrain: GridEnums.TerrainType = GridEnums.TerrainType.GRASS

## Per-tile override of walkability. When true, this tile is walkable
## regardless of terrain default (e.g., a bridge tile over water).
## Kept as a tri-state: empty string = use terrain default, "true"/"false" force.
## Stored as String because @export of Variant isn't clean in Godot 4.
@export var walkable_override: String = ""


## --- Occupancy --------------------------------------------------------------
## ID (not the object itself) of whoever currently sits on this tile.
## StringName for cheap equality; empty = unoccupied.
## Using an ID rather than a reference to Unit lets the grid module stay
## independent of whatever Unit class eventually gets built.
@export var occupant_id: StringName = &""

## For obstacles/objects that aren't units (chests, decorations, props).
@export var object_id: StringName = &""


## --- Presentation state -----------------------------------------------------
## Not persisted. Runtime-only. The visualizer watches this.
@export var highlight_state: GridEnums.HighlightState = GridEnums.HighlightState.NONE


# =============================================================================
# QUERIES
# =============================================================================

func is_walkable() -> bool:
	## Tile can accept a unit right now: terrain walkable, not occupied, no object.
	if not is_terrain_walkable():
		return false
	if occupant_id != &"":
		return false
	if object_id != &"":
		return false
	return true


func is_terrain_walkable() -> bool:
	## Terrain-only walkability, ignores occupancy.
	if walkable_override == "true":
		return true
	if walkable_override == "false":
		return false
	return GridEnums.is_terrain_walkable(terrain)


func is_occupied() -> bool:
	return occupant_id != &"" or object_id != &""


func movement_cost() -> float:
	return GridEnums.terrain_movement_cost(terrain)


func damage_per_turn() -> int:
	return GridEnums.terrain_damage_per_turn(terrain)


# =============================================================================
# WORLD-SPACE CONVERSION
# =============================================================================

## Center of the tile's TOP surface in world space.
## Units stand on this point. +X east, +Z south, +Y up.
func top_world_position() -> Vector3:
	return Vector3(
		float(coord.x) * GridEnums.TILE_WORLD_SIZE,
		float(height) * GridEnums.HEIGHT_STEP,
		float(coord.y) * GridEnums.TILE_WORLD_SIZE,
	)


## Center point of the tile's bounding box (for the mesh instance origin).
func mesh_center_position() -> Vector3:
	var total_h: float = float(height) * GridEnums.HEIGHT_STEP + GridEnums.FLOOR_THICKNESS
	return Vector3(
		float(coord.x) * GridEnums.TILE_WORLD_SIZE,
		(total_h * 0.5) - GridEnums.FLOOR_THICKNESS,
		float(coord.y) * GridEnums.TILE_WORLD_SIZE,
	)


## Full Y-extent of the tile column (for the BoxMesh size).
func mesh_height() -> float:
	return float(height) * GridEnums.HEIGHT_STEP + GridEnums.FLOOR_THICKNESS


# =============================================================================
# FACTORY
# =============================================================================

static func create(
	p_coord: Vector2i,
	p_terrain: GridEnums.TerrainType = GridEnums.TerrainType.GRASS,
	p_height: int = 0
) -> GridTile:
	var tile := GridTile.new()
	tile.coord = p_coord
	tile.terrain = p_terrain
	tile.height = p_height
	return tile


# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"coord": {"x": coord.x, "y": coord.y},
		"height": height,
		"terrain": int(terrain),
		"walkable_override": walkable_override,
		"occupant_id": String(occupant_id),
		"object_id": String(object_id),
	}


static func from_dict(data: Dictionary) -> GridTile:
	var tile := GridTile.new()
	var c = data.get("coord", {"x": 0, "y": 0})
	tile.coord = Vector2i(c["x"], c["y"])
	tile.height = data.get("height", 0)
	tile.terrain = data.get("terrain", GridEnums.TerrainType.GRASS)
	tile.walkable_override = data.get("walkable_override", "")
	tile.occupant_id = StringName(data.get("occupant_id", ""))
	tile.object_id = StringName(data.get("object_id", ""))
	return tile
