class_name LevelLoader
## Converts a LevelData into a BattleGrid deterministically — no randomization.
## Used for hand-crafted story levels instead of MapBuilder.
##
## Spawn points are exposed separately so main.gd can hand them to UnitSpawner
## without hard-coding Alpha map coordinates.

const _StructureLibrary = preload("res://scripts/world/structure_library.gd")


## Build a BattleGrid from a LevelData. Every tile is set exactly as authored;
## structures are placed from StructureLibrary by label.
static func build(data: LevelData) -> BattleGrid:
	if data == null:
		push_error("LevelLoader.build: data is null")
		return null

	var grid := BattleGrid.create(data.width, data.height)

	# Apply per-tile terrain, elevation, and chest tag.
	for y in data.height:
		for x in data.width:
			var coord := Vector2i(x, y)
			var td: Dictionary = data.get_tile_data(coord)
			var tile := grid.get_tile(coord)
			if tile == null:
				continue
			tile.terrain        = td.get("terrain", int(GridEnums.TerrainType.GRASS)) \
				as GridEnums.TerrainType
			tile.height         = td.get("elevation", 0)
			tile.chest_loot_tag = td.get("chest_tag", "")

	# Place structures. StructureLibrary.get_structure() looks up by label.
	for entry in data.structures:
		var struct_data: StructureData = _StructureLibrary.get_structure(entry["name"])
		if struct_data == null:
			push_warning("LevelLoader: unknown structure '%s', skipping" % entry["name"])
			continue
		# LevelData.structures stores {"name":…, "origin": Vector2i} — use that key.
		var origin: Vector2i = entry.get("origin", Vector2i.ZERO)
		if not grid.place_structure(struct_data, origin):
			push_warning("LevelLoader: could not place '%s' at %s (overlap or OOB)" \
				% [entry["name"], origin])

	return grid


## Player spawn list from this level. Falls back to the Alpha default if none defined.
static func player_spawn_points(data: LevelData) -> Array:
	if data == null or data.player_spawns.is_empty():
		return [
			Vector2i(0,  9), Vector2i(2,  9), Vector2i(4,  9), Vector2i(6,  9),
			Vector2i(1, 11), Vector2i(3, 11), Vector2i(5, 11),
		]
	return data.player_spawns.duplicate()


## Enemy spawn list from this level. Falls back to the Alpha default if none defined.
static func enemy_spawn_points(data: LevelData) -> Array:
	if data == null or data.enemy_spawns.is_empty():
		return [Vector2i(10, 1), Vector2i(11, 2), Vector2i(10, 3)]
	return data.enemy_spawns.duplicate()
