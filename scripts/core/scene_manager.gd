extends Node
## Lightweight data bus for passing state between scenes.
## consume_* methods clear after reading so stale data never bleeds.


var _player_jobs: Array  = []
var _enemy_jobs: Array   = []
var _player_names: Array = []
var _enemy_names: Array  = []
var _map_template_name: String = ""
var _terrain_intensity: float = 1.0

## Endless mode run state — persists across battle reloads.
var _pending_mode: String = "single"   # "single" | "endless"
var _endless_mode: bool  = false
var _endless_round: int  = 0
var _endless_player_jobs: Array  = []
var _endless_player_names: Array = []


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


# =============================================================================
# PENDING MODE  (set by main menu before entering character select)
# =============================================================================

func set_pending_mode(mode: String) -> void:
	_pending_mode = mode

func get_pending_mode() -> String:
	return _pending_mode

func consume_pending_mode() -> String:
	var out := _pending_mode
	_pending_mode = "single"
	return out


# =============================================================================
# ENDLESS RUN STATE
# =============================================================================

func start_endless_run(jobs: Array, names: Array) -> void:
	_endless_mode = true
	_endless_round = 1
	_endless_player_jobs  = jobs.duplicate()
	_endless_player_names = names.duplicate()

func is_endless_mode() -> bool:
	return _endless_mode

func get_endless_round() -> int:
	return _endless_round

func advance_endless_round() -> void:
	_endless_round += 1

func end_endless_run() -> void:
	_endless_mode = false
	_endless_round = 0
	_endless_player_jobs.clear()
	_endless_player_names.clear()

func get_endless_player_jobs() -> Array:
	return _endless_player_jobs.duplicate()

func get_endless_player_names() -> Array:
	return _endless_player_names.duplicate()
