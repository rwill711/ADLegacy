class_name LevelLibrary
## On-disk storage for hand-crafted levels.
## Reads and writes user://levels/*.level.json.
## All methods are static — no instance needed.

const LEVELS_DIR: String = "user://levels/"
const FILE_EXT:   String = ".level.json"


static func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		DirAccess.make_dir_recursive_absolute(LEVELS_DIR)


static func save_level(level: LevelData, filename: String) -> bool:
	if filename.strip_edges().is_empty():
		push_error("LevelLibrary.save_level: empty filename")
		return false
	ensure_dir()
	var path: String = LEVELS_DIR + filename.strip_edges() + FILE_EXT
	var json_str: String = JSON.stringify(level.to_dict(), "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("LevelLibrary.save_level: cannot open '%s'" % path)
		return false
	file.store_string(json_str)
	file.close()
	return true


static func load_level(filename: String) -> LevelData:
	var fname: String = filename if filename.ends_with(FILE_EXT) \
		else filename.strip_edges() + FILE_EXT
	var path: String = LEVELS_DIR + fname
	if not FileAccess.file_exists(path):
		push_error("LevelLibrary.load_level: not found — '%s'" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error("LevelLibrary.load_level: JSON error in '%s'" % path)
		return null
	var data = json.get_data()
	if not data is Dictionary:
		return null
	return LevelData.from_dict(data as Dictionary)


## Bare names (no extension) for display in the level editor picker.
static func list_levels() -> Array:
	return list_level_names()


## Sorted list of bare level names (extension stripped).
static func list_level_names() -> Array:
	ensure_dir()
	var result: Array = []
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(FILE_EXT):
			result.append(fname.trim_suffix(FILE_EXT))
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


static func delete_level(filename: String) -> void:
	var fname: String = filename if filename.ends_with(FILE_EXT) \
		else filename.strip_edges() + FILE_EXT
	if FileAccess.file_exists(LEVELS_DIR + fname):
		var dir := DirAccess.open(LEVELS_DIR)
		if dir != null:
			dir.remove(fname)
