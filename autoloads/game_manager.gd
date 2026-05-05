extends Node

# Autoload: GameManager
# Global game state — scene transitions, save/load, top-level flags.

const SAVE_PATH: String    = "user://save.json"
const SAVE_VERSION: int    = 1


func _ready() -> void:
	pass


# =============================================================================
# SAVE / LOAD
# =============================================================================

## Serialize the current endless run to disk.
## Pass only the player units — enemies are regenerated each round.
func save_game(units: Array) -> void:
	var unit_dicts: Array = []
	for unit in units:
		if unit != null:
			unit_dicts.append(unit.to_dict())

	var data: Dictionary = {
		"version":              SAVE_VERSION,
		"endless_round":        SceneManager.get_endless_round(),
		"endless_player_jobs":  SceneManager.get_endless_player_jobs(),
		"endless_player_names": SceneManager.get_endless_player_names(),
		"units":                unit_dicts,
	}

	var json_str: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameManager.save_game: could not open '%s' for writing (err %d)" \
			% [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(json_str)
	file.close()


## Load the save file and return the raw Dictionary, or {} on any failure.
## Callers should check has_save() first if they want to branch on presence.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager.load_game: could not open '%s' (err %d)" \
			% [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var json_str: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error("GameManager.load_game: JSON parse error — %s" % json.get_error_message())
		return {}
	var data = json.get_data()
	if not data is Dictionary:
		push_error("GameManager.load_game: root is not a Dictionary")
		return {}
	return data as Dictionary


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Remove the save file (call on run end or new-game start).
func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("save.json")
