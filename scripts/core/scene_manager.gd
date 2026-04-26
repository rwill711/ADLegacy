extends Node
## Lightweight data bus for passing state between scenes.
## Autoloaded as SceneManager so any scene can read/write without coupling.
##
## consume_* methods clear the value after reading so stale data never
## bleeds into a second load.


var _player_jobs: Array = []


## Called by CharacterSelect to hand off the chosen roster before loading main.
func set_player_jobs(jobs: Array) -> void:
	_player_jobs = jobs.duplicate()


## Called by main.gd in _ready(). Returns the selection and clears it.
## Returns [] if no selection was made (direct launch / fallback to default).
func consume_player_jobs() -> Array:
	var out: Array = _player_jobs.duplicate()
	_player_jobs.clear()
	return out
