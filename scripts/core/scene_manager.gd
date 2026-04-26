extends Node
## Lightweight data bus for passing state between scenes.
## consume_* methods clear after reading so stale data never bleeds.


var _player_jobs: Array = []
var _enemy_jobs: Array  = []
var _map_template_name: String = ""


func set_player_jobs(jobs: Array) -> void:
	_player_jobs = jobs.duplicate()

func consume_player_jobs() -> Array:
	var out := _player_jobs.duplicate()
	_player_jobs.clear()
	return out


func set_enemy_jobs(jobs: Array) -> void:
	_enemy_jobs = jobs.duplicate()

func consume_enemy_jobs() -> Array:
	var out := _enemy_jobs.duplicate()
	_enemy_jobs.clear()
	return out


func set_map_template(name: String) -> void:
	_map_template_name = name

func consume_map_template() -> String:
	var out := _map_template_name
	_map_template_name = ""
	return out
