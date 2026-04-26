class_name StructureLibrary
## Catalog of named StructureData presets.


static func all_structures() -> Array:
	return [cabin(), watchtower(), vault()]


static func random_structure(rng: RandomNumberGenerator) -> StructureData:
	var pool := all_structures()
	return pool[rng.randi_range(0, pool.size() - 1)]


# =============================================================================
# PRESETS
# =============================================================================

## 3×3 building. Door on south face, centre tile.
static func cabin() -> StructureData:
	return StructureData.create(
		"Cabin",
		[
			Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
			Vector2i(0,1), Vector2i(1,1), Vector2i(2,1),
			Vector2i(0,2), Vector2i(1,2), Vector2i(2,2),
		],
		Vector2i(1, 2),   # entrance on south-centre tile
		Vector2i(0, 1),   # approach is one step south
		2.2,
		"standard"
	)


## 2×2 tower. Door on south face, east tile.
static func watchtower() -> StructureData:
	return StructureData.create(
		"Watchtower",
		[
			Vector2i(0,0), Vector2i(1,0),
			Vector2i(0,1), Vector2i(1,1),
		],
		Vector2i(1, 1),   # entrance on south-east tile
		Vector2i(0, 1),   # approach is one step south
		3.2,              # taller
		"elite"
	)


## 3×3 sealed vault. Door on east face, centre tile.
static func vault() -> StructureData:
	return StructureData.create(
		"Vault",
		[
			Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
			Vector2i(0,1), Vector2i(1,1), Vector2i(2,1),
			Vector2i(0,2), Vector2i(1,2), Vector2i(2,2),
		],
		Vector2i(2, 1),   # entrance on east-centre tile
		Vector2i(1, 0),   # approach is one step east
		2.0,
		"elite"
	)
