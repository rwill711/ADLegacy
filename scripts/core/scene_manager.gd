extends Node
## Lightweight data bus for passing state between scenes.
## consume_* methods clear after reading so stale data never bleeds.


var _player_jobs: Array  = []
var _enemy_jobs: Array   = []
var _player_names: Array = []
var _enemy_names: Array  = []
var _map_template_name: String = ""
var _terrain_intensity: float = 1.0


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


func set_player_names(names: Array) -> void:
	_player_names = names.duplicate()

func consume_player_names() -> Array:
	var out := _player_names.duplicate()
	_player_names.clear()
	return out


func set_enemy_names(names: Array) -> void:
	_enemy_names = names.duplicate()

func consume_enemy_names() -> Array:
	var out := _enemy_names.duplicate()
	_enemy_names.clear()
	return out


func set_map_template(name: String) -> void:
	_map_template_name = name

func consume_map_template() -> String:
	var out := _map_template_name
	_map_template_name = ""
	return out


func set_terrain_intensity(value: float) -> void:
	_terrain_intensity = value

func consume_terrain_intensity() -> float:
	var out := _terrain_intensity
	_terrain_intensity = 1.0
	return out
