class_name SceneLibrary

const SCENES_DIR: String = "user://scenes/"
const FILE_EXT:   String = ".scene.json"


static func save_scene(data: SceneData, filename: String) -> bool:
	if filename.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(SCENES_DIR)
	var path: String = SCENES_DIR + filename + FILE_EXT
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SceneLibrary: cannot open '%s' for writing." % path)
		return false
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	file.close()
	return true


static func load_scene(filename: String) -> SceneData:
	var path: String = SCENES_DIR + filename
	if not FileAccess.file_exists(path):
		push_error("SceneLibrary: file not found — '%s'." % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SceneLibrary: cannot open '%s' for reading." % path)
		return null
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SceneLibrary: invalid JSON in '%s'." % path)
		return null
	return SceneData.from_dict(parsed)


static func list_scenes() -> Array:
	var dir := DirAccess.open(SCENES_DIR)
	if dir == null:
		return []
	var out: Array = []
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(FILE_EXT):
			out.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


static func list_scene_names() -> Array:
	var out: Array = []
	for fname in list_scenes():
		out.append(fname.trim_suffix(FILE_EXT))
	return out


static func delete_scene(filename: String) -> void:
	var path: String = SCENES_DIR + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func scene_exists(filename: String) -> bool:
	return FileAccess.file_exists(SCENES_DIR + filename)
