extends Node3D
## Alpha entry scene. Builds the grid, spawns the roster, starts the battle,
## wires hover/click feedback, and drives the camera from the active unit.
##
## Phase 3A scope: turn system is live but MOVE/ACT are stubs. SPACE ends
## the current unit's turn. Enemy turns auto-end after a short delay so
## the CT queue keeps rotating during manual testing.


@export var log_tile_events: bool = true
@export var enemy_auto_end_delay: float = 0.5  # seconds before enemies auto-end-turn

@onready var _visualizer: GridVisualizer = $GridVisualizer
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _unit_spawner: UnitSpawner = $UnitSpawner
@onready var _units_root: Node3D = $Units
@onready var _turn_manager: TurnManager = $TurnManager
@onready var _turn_hud: TurnHUD = $TurnHUD
@onready var _move_controller: MoveController = $MoveController

var _grid: GridMap = null


func _ready() -> void:
	_register_battle_input_actions()

	_grid = AlphaTestMap.build()
	_visualizer.set_grid(_grid)

	_visualizer.tile_hovered.connect(_on_tile_hovered)
	_visualizer.tile_unhovered.connect(_on_tile_unhovered)
	_visualizer.tile_clicked.connect(_on_tile_clicked)

	var units: Array = _unit_spawner.spawn_alpha_roster(_grid, _units_root)

	_camera_rig.set_focus(_grid_center_world(_grid), true)

	_turn_manager.turn_started.connect(_on_turn_started)
	_turn_manager.battle_ended.connect(_on_battle_ended)

	_turn_hud.bind_turn_manager(_turn_manager)
	_move_controller.bind(_grid, _visualizer, _turn_manager)

	_turn_manager.begin_battle(units)


# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# Block turn input during a movement animation so SPACE mid-tween can't
	# rotate to the next unit before the current move commits.
	if _move_controller != null and _move_controller.is_executing():
		return
	if event.is_action_pressed("end_turn"):
		_turn_manager.end_turn()
	elif event.is_action_pressed("wait_turn"):
		_turn_manager.wait_and_end_turn()
	elif event.is_action_pressed("stub_act"):
		_turn_manager.declare_acted()


## Register testing input actions at runtime so project.godot stays clean.
## Move is now real (click a highlighted tile). Act stays stubbed until 3C.
func _register_battle_input_actions() -> void:
	_ensure_action("end_turn", KEY_SPACE)
	_ensure_action("wait_turn", KEY_W)
	_ensure_action("stub_act", KEY_A)


static func _ensure_action(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	# De-dupe binding on hot reload.
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)


# =============================================================================
# TURN-DRIVEN CAMERA + AI STUB
# =============================================================================

func _on_turn_started(unit: Unit) -> void:
	_camera_rig.set_focus(unit.global_position)

	# Phase 3A placeholder: enemies don't have AI yet, so we auto-end their
	# turn so the CT queue keeps rotating during testing. Replace in Phase 3C
	# when we wire up actual enemy decision-making.
	if unit.team != UnitEnums.Team.PLAYER:
		_auto_end_enemy_turn(unit)


func _auto_end_enemy_turn(unit: Unit) -> void:
	var tween := get_tree().create_tween()
	tween.tween_interval(enemy_auto_end_delay)
	tween.tween_callback(func():
		# Guard against the unit dying or the battle ending mid-delay.
		if _turn_manager.get_active_unit() == unit \
		and _turn_manager.get_phase() == TurnEnums.TurnPhase.AWAITING_ACTION:
			_turn_manager.wait_and_end_turn()
	)


func _on_battle_ended(outcome: int) -> void:
	print("[battle] ended with outcome=%d" % outcome)


# =============================================================================
# TILE INPUT FEEDBACK (from Phase 1A, unchanged)
# =============================================================================

func _grid_center_world(map: GridMap) -> Vector3:
	return Vector3(
		(float(map.width) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
		0.0,
		(float(map.height) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
	)


func _on_tile_hovered(coord: Vector2i) -> void:
	if _grid == null:
		return
	# During a move-range preview, a reachable tile shows PATH color on hover
	# (this is my move destination if I click); non-reachable tiles still get
	# the normal HOVER tint so the rest of the board stays interactable.
	if _move_controller != null and _move_controller.is_preview_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.PATH)
	else:
		_grid.set_highlight(coord, GridEnums.HighlightState.HOVER)


func _on_tile_unhovered(coord: Vector2i) -> void:
	if _grid == null:
		return
	# Restore the preview color if the tile is still in the reachable set.
	# Otherwise clear to NONE.
	if _move_controller != null and _move_controller.is_preview_tile(coord):
		_grid.set_highlight(coord, GridEnums.HighlightState.MOVE_RANGE)
	else:
		_grid.set_highlight(coord, GridEnums.HighlightState.NONE)


func _on_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if not log_tile_events or _grid == null:
		return
	var tile := _grid.get_tile(coord)
	if tile == null:
		return
	var occupant_info: String = ""
	if tile.occupant_id != &"":
		var u := _unit_spawner.get_unit(tile.occupant_id)
		if u != null:
			occupant_info = " occupant=%s(%s hp=%d/%d ct=%d)" % [
				u.unit_id, u.display_name,
				u.stats.hp, u.stats.max_hp,
				_turn_manager.get_ct(u.unit_id),
			]
	print("[tile %s] terrain=%d height=%d walkable=%s button=%d%s" % [
		coord, int(tile.terrain), tile.height, tile.is_walkable(),
		button_index, occupant_info
	])
