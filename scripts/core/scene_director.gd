class_name SceneDirector extends Node
## Executes a SceneData step list in order.
## Add as a child of the battle scene; call start() to begin.

signal finished()
signal camera_pan(world_pos: Vector3)

const STEP_DURATION: float = 0.30   # seconds per tile when walking

var _grid = null          # BattleGrid — passed into start()
var _role_map: Dictionary = {}  # String → Unit
var _dialogue_box: DialogueBox = null
var _skip_overlay: CanvasLayer = null
var _running: bool = false
var _skip_requested: bool = false


func start(scene_data: SceneData, role_to_unit: Dictionary, grid) -> void:
	if _running:
		return
	_running = true
	_grid    = grid
	_role_map = role_to_unit
	_create_skip_overlay()
	_run_steps(scene_data.steps)


## Immediately ends the scene — dismisses dialogue and skips remaining steps.
func stop() -> void:
	_skip_requested = true
	if _dialogue_box != null:
		_dialogue_box.dismiss()


func _create_skip_overlay() -> void:
	_skip_overlay = CanvasLayer.new()
	_skip_overlay.layer = 21   # must be above DialogueBox (layer 20)
	get_tree().root.add_child(_skip_overlay)
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_overlay.add_child(root_ctrl)
	var btn := Button.new()
	btn.text = "Skip Scene"
	btn.custom_minimum_size = Vector2(120, 36)
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	# Sit just above the 220px-tall DialogueBox panel (10px gap).
	btn.offset_left   = -130
	btn.offset_top    = -266   # 220 (dialogue) + 10 (gap) + 36 (btn height)
	btn.offset_right  = -10
	btn.offset_bottom = -230   # 220 (dialogue) + 10 (gap)
	btn.pressed.connect(stop)
	root_ctrl.add_child(btn)


func _run_steps(steps: Array) -> void:
	for step in steps:
		if _skip_requested:
			break
		await _execute_step(step)
	_cleanup()
	finished.emit()


func _execute_step(step: Dictionary) -> void:
	match step.get("type", ""):
		"MOVE":     await _step_move(step)
		"FACE":     _step_face(step)
		"DIALOGUE": await _step_dialogue(step)
		"WAIT":     await _step_wait(step)
		"CAMERA":   _step_camera(step)


# =============================================================================
# STEP HANDLERS
# =============================================================================

func _step_move(step: Dictionary) -> void:
	var unit = _unit_for_role(step.get("actor_role", ""))
	if unit == null:
		return
	var dest := Vector2i(int(step.get("to_x", 0)), int(step.get("to_y", 0)))
	var path: Array = _simple_path(unit.coord, dest)
	for coord in path:
		var tile = _grid.get_tile(coord)
		if tile == null:
			continue
		unit.place_on_tile(tile, false)
		await get_tree().create_timer(STEP_DURATION).timeout


func _step_face(step: Dictionary) -> void:
	var unit = _unit_for_role(step.get("actor_role", ""))
	if unit == null:
		return
	unit.set_facing(_parse_facing(step.get("direction", "S")))


func _step_dialogue(step: Dictionary) -> void:
	var role: String  = step.get("actor_role", "")
	if role.is_empty():
		role = "Narrator"
	var text: String  = step.get("text", "")
	var color: Color  = DialogueBox.portrait_color_for(role)
	if _dialogue_box == null:
		_dialogue_box = DialogueBox.new()
		get_tree().root.add_child(_dialogue_box)
	_dialogue_box.show_line(role, text, color)
	await _dialogue_box.advanced


func _step_wait(step: Dictionary) -> void:
	var remaining: float = float(step.get("duration", 1.0))
	while remaining > 0.0 and not _skip_requested:
		var tick := minf(0.05, remaining)
		await get_tree().create_timer(tick).timeout
		remaining -= tick


func _step_camera(step: Dictionary) -> void:
	if _grid == null:
		return
	if step.get("camera_target", "coord") == "unit":
		var unit = _unit_for_role(step.get("actor_role", ""))
		if unit == null:
			return
		var tile = _grid.get_tile(unit.coord)
		if tile != null:
			camera_pan.emit(tile.top_world_position())
	else:
		var coord := Vector2i(int(step.get("target_x", 0)), int(step.get("target_y", 0)))
		var tile = _grid.get_tile(coord)
		if tile != null:
			camera_pan.emit(tile.top_world_position())


# =============================================================================
# HELPERS
# =============================================================================

func _unit_for_role(role: String):
	return _role_map.get(role, null)


## Rectilinear path from `from` to `to` (X-axis first, then Y-axis).
func _simple_path(from: Vector2i, to: Vector2i) -> Array:
	var path: Array = []
	var cur := from
	var dx: int = sign(to.x - from.x)
	var dy: int = sign(to.y - from.y)
	while cur.x != to.x:
		cur.x += dx
		path.append(cur)
	while cur.y != to.y:
		cur.y += dy
		path.append(cur)
	return path


func _parse_facing(dir: String) -> UnitEnums.Facing:
	match dir.to_upper():
		"N": return UnitEnums.Facing.NORTH
		"E": return UnitEnums.Facing.EAST
		"W": return UnitEnums.Facing.WEST
		_:   return UnitEnums.Facing.SOUTH


func _cleanup() -> void:
	_running = false
	if _dialogue_box != null:
		_dialogue_box.queue_free()
		_dialogue_box = null
	if _skip_overlay != null:
		_skip_overlay.queue_free()
		_skip_overlay = null
