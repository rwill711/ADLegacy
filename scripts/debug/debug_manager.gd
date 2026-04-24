extends Node
## DebugManager — autoload singleton that owns the debug command registry,
## the panel registry, and the persistent log buffer.
##
## EXTENSIBILITY CONTRACT (CD mandate — modular, not a fixed tool):
##   Any system can, without touching the debugger itself:
##     1. register_command(name, callable, description) — adds a console command
##     2. register_panel(name, control)                 — adds a tab to the overlay
##     3. log(category, text)                           — pushes an entry to the log
##   New systems just call these APIs during their _ready() (or at bind time).
##
## Scene-lifecycle: this node persists across scene reloads (autoload), but
## its scene REFS (grid, units, turn manager, etc.) are re-bound each time
## main.gd starts. Commands that need scene state look them up via the
## scene-ref getters below — they return null between reloads, so every
## command guards against null.


signal log_added(entry: Dictionary)
signal command_registered(name: String)
signal panel_registered(name: String)
signal scene_bound()


## --- Registries -------------------------------------------------------------
## name → {callable: Callable, description: String}
var _commands: Dictionary = {}
## name → Control
var _panels: Dictionary = {}
## Array[{category: String, text: String, timestamp: int}]
var _log: Array = []
## Ring-buffer cap. Keeps memory bounded without dropping recent context.
var _log_max: int = 500


## --- Scene refs (re-bound every scene load) ---------------------------------
var grid: GridMap = null
var unit_spawner: UnitSpawner = null
var turn_manager: TurnManager = null
var move_controller: MoveController = null
var action_controller: ActionController = null
var camera_rig: CameraRig = null
var main_scene: Node3D = null

var _built_in_registered: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Log our own startup so the first overlay open shows something.
	log(DebugEnums.CATEGORY_SYSTEM, "DebugManager online")


## Called by main.gd._ready after the battle scene is assembled.
## Re-call is safe — refs overwrite, built-in command registration is idempotent.
func bind_scene(
	p_grid: GridMap,
	p_spawner: UnitSpawner,
	p_turn_mgr: TurnManager,
	p_move_ctrl: MoveController,
	p_action_ctrl: ActionController,
	p_camera_rig: CameraRig,
	p_main: Node3D
) -> void:
	grid = p_grid
	unit_spawner = p_spawner
	turn_manager = p_turn_mgr
	move_controller = p_move_ctrl
	action_controller = p_action_ctrl
	camera_rig = p_camera_rig
	main_scene = p_main

	if not _built_in_registered:
		DebugCommands.register_all(self)
		_built_in_registered = true

	log(DebugEnums.CATEGORY_SYSTEM, "Scene bound (grid=%dx%d, units=%d)" % [
		grid.width if grid != null else 0,
		grid.height if grid != null else 0,
		unit_spawner.get_all_units().size() if unit_spawner != null else 0,
	])
	scene_bound.emit()


# =============================================================================
# COMMAND REGISTRATION
# =============================================================================

## Register a console command. `callable` receives `args: PackedStringArray`
## and returns a String (displayed in the console).
func register_command(name: String, callable: Callable, description: String = "") -> void:
	_commands[name] = {
		"callable": callable,
		"description": description,
	}
	command_registered.emit(name)


func has_command(name: String) -> bool:
	return _commands.has(name)


func get_commands_sorted() -> Array:
	var names: Array = _commands.keys()
	names.sort()
	return names


func get_command_description(name: String) -> String:
	var entry: Dictionary = _commands.get(name, {})
	return entry.get("description", "")


## Parse a single line of user input into `[command, arg1, arg2, ...]` and
## invoke the registered callable. Returns the command's String output
## (or a diagnostic string for unknown / erroring commands).
func execute_command(line: String) -> String:
	var trimmed: String = line.strip_edges()
	if trimmed.is_empty():
		return ""

	var parts: PackedStringArray = _split_args(trimmed)
	if parts.is_empty():
		return ""

	var name: String = parts[0]
	if not _commands.has(name):
		return "unknown command: '%s' — try 'help'" % name

	var args: PackedStringArray = parts.slice(1)
	var entry: Dictionary = _commands[name]
	var callable: Callable = entry["callable"]
	var output: Variant = callable.call(args)
	return str(output) if output != null else ""


# =============================================================================
# PANEL REGISTRATION
# =============================================================================

func register_panel(name: String, control: Control) -> void:
	_panels[name] = control
	panel_registered.emit(name)


func get_panels() -> Dictionary:
	return _panels.duplicate()


# =============================================================================
# LOG
# =============================================================================

func log(category: String, text: String) -> void:
	var entry: Dictionary = {
		"category": category,
		"text": text,
		"timestamp": Time.get_unix_time_from_system(),
	}
	_log.append(entry)
	while _log.size() > _log_max:
		_log.pop_front()
	log_added.emit(entry)


func get_log(filter_category: String = "") -> Array:
	if filter_category.is_empty():
		return _log.duplicate()
	return _log.filter(func(e): return e["category"] == filter_category)


func clear_log() -> void:
	_log.clear()


## Write the current log buffer to user://debug_log_<timestamp>.txt.
## Returns the path written. Called by the log_export command.
func export_log() -> String:
	var path: String = "user://debug_log_%d.txt" % int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	for entry in _log:
		file.store_line("[%s] [%s] %s" % [
			str(entry["timestamp"]),
			entry["category"],
			entry["text"],
		])
	file.close()
	return path


# =============================================================================
# HELPERS
# =============================================================================

## Very simple arg split — whitespace separated, no quoted strings for now.
## Good enough for Alpha debug commands (`heal rogue 50`). Can swap to a
## proper tokenizer later if commands need multi-word args.
static func _split_args(line: String) -> PackedStringArray:
	var parts: PackedStringArray = []
	for token in line.split(" ", false):
		var t: String = token.strip_edges()
		if not t.is_empty():
			parts.append(t)
	return parts
