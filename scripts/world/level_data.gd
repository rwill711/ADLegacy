class_name LevelData
## Hand-crafted battle level. Stores per-tile data plus spawn and structure lists.
## Created via LevelData.create(); saved/loaded through LevelLibrary.

const DEFAULT_WIDTH:  int = 12
const DEFAULT_HEIGHT: int = 12

var level_name:    String = "New Level"
var width:         int    = DEFAULT_WIDTH
var height:        int    = DEFAULT_HEIGHT
var player_spawns: Array  = []   # Array[Vector2i]
var enemy_spawns:  Array  = []   # Array[Vector2i]
var structures:    Array  = []   # Array[{name:String, origin:Vector2i}]

var _tiles: Dictionary = {}   # Vector2i → {terrain:int, elevation:int, chest_tag:String}


static func create(name: String, w: int = DEFAULT_WIDTH, h: int = DEFAULT_HEIGHT) -> LevelData:
	var d := LevelData.new()
	d.level_name = name
	d.width      = w
	d.height     = h
	return d


func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < width and coord.y >= 0 and coord.y < height


func get_tile_data(coord: Vector2i) -> Dictionary:
	return _tiles.get(coord, {})


func set_tile_terrain(coord: Vector2i, terrain: int) -> void:
	if not is_in_bounds(coord):
		return
	var td: Dictionary = _tiles.get(coord, {})
	td["terrain"] = terrain
	_tiles[coord] = td


func set_tile_elevation(coord: Vector2i, elevation: int) -> void:
	if not is_in_bounds(coord):
		return
	var td: Dictionary = _tiles.get(coord, {})
	td["elevation"] = clampi(elevation, 0, 7)
	_tiles[coord] = td


func set_tile_chest(coord: Vector2i, tag: String) -> void:
	if not is_in_bounds(coord):
		return
	var td: Dictionary = _tiles.get(coord, {})
	if tag.is_empty():
		td.erase("chest_tag")
	else:
		td["chest_tag"] = tag
	_tiles[coord] = td


func add_structure(name: String, origin: Vector2i) -> void:
	structures.append({"name": name, "origin": origin})


func remove_structure(coord: Vector2i) -> void:
	for i in range(structures.size() - 1, -1, -1):
		if structures[i].get("origin") == coord:
			structures.remove_at(i)
			return


func to_dict() -> Dictionary:
	var tiles_arr: Array = []
	for coord in _tiles:
		var td: Dictionary = _tiles[coord].duplicate()
		td["x"] = (coord as Vector2i).x
		td["y"] = (coord as Vector2i).y
		tiles_arr.append(td)

	var spawns_p: Array = []
	for c: Vector2i in player_spawns:
		spawns_p.append({"x": c.x, "y": c.y})

	var spawns_e: Array = []
	for c: Vector2i in enemy_spawns:
		spawns_e.append({"x": c.x, "y": c.y})

	var structs_arr: Array = []
	for s in structures:
		structs_arr.append({"name": s["name"], "ox": (s["origin"] as Vector2i).x, "oy": (s["origin"] as Vector2i).y})

	return {
		"version":       1,
		"level_name":    level_name,
		"width":         width,
		"height":        height,
		"tiles":         tiles_arr,
		"player_spawns": spawns_p,
		"enemy_spawns":  spawns_e,
		"structures":    structs_arr,
	}


static func from_dict(data: Dictionary) -> LevelData:
	var d := LevelData.new()
	d.level_name = data.get("level_name", "Unknown")
	d.width      = int(data.get("width",  DEFAULT_WIDTH))
	d.height     = int(data.get("height", DEFAULT_HEIGHT))

	for td in data.get("tiles", []):
		var coord := Vector2i(int(td["x"]), int(td["y"]))
		var entry: Dictionary = {}
		if td.has("terrain"):
			entry["terrain"] = int(td["terrain"])
		if td.has("elevation"):
			entry["elevation"] = int(td["elevation"])
		if td.has("chest_tag") and String(td["chest_tag"]) != "":
			entry["chest_tag"] = String(td["chest_tag"])
		d._tiles[coord] = entry

	for sp in data.get("player_spawns", []):
		d.player_spawns.append(Vector2i(int(sp["x"]), int(sp["y"])))

	for se in data.get("enemy_spawns", []):
		d.enemy_spawns.append(Vector2i(int(se["x"]), int(se["y"])))

	for s in data.get("structures", []):
		d.structures.append({"name": String(s["name"]), "origin": Vector2i(int(s["ox"]), int(s["oy"]))})

	return d
