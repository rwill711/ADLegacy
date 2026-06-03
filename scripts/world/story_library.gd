class_name StoryLibrary
## On-disk storage for story scripts.
## Reads and writes user://stories/*.story.json.
## All methods are static — no instance needed.

const STORIES_DIR: String = "user://stories/"
const FILE_EXT:    String = ".story.json"


static func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(STORIES_DIR):
		DirAccess.make_dir_recursive_absolute(STORIES_DIR)


## Save a story script to disk. filename is the bare name (no extension).
static func save_story(filename: String, story_name: String, acts: Array) -> bool:
	if filename.strip_edges().is_empty():
		push_error("StoryLibrary.save_story: empty filename")
		return false
	ensure_dir()
	var path: String = STORIES_DIR + filename.strip_edges() + FILE_EXT
	var data: Dictionary = {
		"version":    1,
		"story_name": story_name,
		"acts":       acts.duplicate(true),
	}
	var json_str: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("StoryLibrary.save_story: cannot open '%s'" % path)
		return false
	file.store_string(json_str)
	file.close()
	return true


## Load a story by bare filename or full filename (with extension).
## Returns empty Dictionary on failure.
static func load_story(filename: String) -> Dictionary:
	var fname: String = filename if filename.ends_with(FILE_EXT) \
		else filename.strip_edges() + FILE_EXT
	var path: String = STORIES_DIR + fname
	if not FileAccess.file_exists(path):
		push_error("StoryLibrary.load_story: not found — '%s'" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error("StoryLibrary.load_story: JSON error in '%s'" % path)
		return {}
	var data = json.get_data()
	if not data is Dictionary:
		return {}
	return data as Dictionary


## Returns sorted list of full filenames (with extension).
static func list_stories() -> Array:
	ensure_dir()
	var result: Array = []
	var dir := DirAccess.open(STORIES_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(FILE_EXT):
			result.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


## Returns bare names (extension stripped) for display.
static func list_story_names() -> Array:
	return list_stories().map(func(f): return f.trim_suffix(FILE_EXT))


static func delete_story(filename: String) -> void:
	var fname: String = filename if filename.ends_with(FILE_EXT) \
		else filename.strip_edges() + FILE_EXT
	if FileAccess.file_exists(STORIES_DIR + fname):
		var dir := DirAccess.open(STORIES_DIR)
		if dir != null:
			dir.remove(fname)
