extends Node
## Lightweight data bus for passing state between scenes.
## consume_* methods clear after reading so stale data never bleeds.


var _player_jobs: Array = []
var _enemy_jobs: Array  = []


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
