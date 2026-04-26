class_name StructureData extends Resource
## Defines one building type: its tile footprint, entrance location, and label.
##
## Coordinate system: footprint coords are relative to the structure's origin
## (top-left corner). MapBuilder translates them to world coords when placing.
##
## The entrance_offset is the footprint tile that has the visual door/arch.
## The approach tile (where a unit stands to trigger Enter) is one step outside
## the footprint in the entrance_facing direction.


@export var label: String = "Building"

## Tiles the structure occupies, relative to placement origin.
## All are set as impassable on the grid via structure_id.
@export var footprint: Array = []  # Array[Vector2i]

## Which footprint tile has the door visual (relative to origin).
@export var entrance_offset: Vector2i = Vector2i.ZERO

## Direction a unit stands to approach — points OUTWARD from the entrance.
## e.g. Vector2i(0, 1) means the approach tile is one step south of entrance.
@export var entrance_facing: Vector2i = Vector2i(0, 1)

## Height of the structure in world units (visual only).
@export var wall_height: float = 2.2

## Loot table tag for interior contents ("standard", "elite", or "").
@export var interior_loot: String = "standard"


static func create(
	p_label: String,
	p_footprint: Array,
	p_entrance_offset: Vector2i,
	p_entrance_facing: Vector2i,
	p_wall_height: float = 2.2,
	p_interior_loot: String = "standard"
) -> StructureData:
	var s := StructureData.new()
	s.label            = p_label
	s.footprint        = p_footprint
	s.entrance_offset  = p_entrance_offset
	s.entrance_facing  = p_entrance_facing
	s.wall_height      = p_wall_height
	s.interior_loot    = p_interior_loot
	return s


## Returns the world-space approach coord given where the structure was placed.
func approach_coord(origin: Vector2i) -> Vector2i:
	return origin + entrance_offset + entrance_facing


## Returns the world-space entrance coord (the door tile itself).
func entrance_coord(origin: Vector2i) -> Vector2i:
	return origin + entrance_offset
