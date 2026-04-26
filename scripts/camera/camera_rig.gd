class_name CameraRig extends Node3D
## FFTA-style isometric camera rig.
##
## Structure: this node is the PIVOT. A Camera3D child is positioned at a
## local offset (height + distance) and pitched downward. Rotating THIS node
## around Y orbits the camera around the focus point, keeping the same
## isometric angle. The camera itself is never rotated directly.
##
## Features:
##   - 4-point rotation in 90° snaps (NE, SE, SW, NW), eased over ~0.2s.
##   - Bounded orthographic zoom on mouse wheel / page keys.
##   - set_focus(world_pos) with optional tween — used later by the turn
##     system to follow the active unit.
##   - Action bindings are registered at runtime, so the project file doesn't
##     need hand-edited InputMap serialization (fragile to author by hand).


## --- Signals -----------------------------------------------------------------
signal rotation_changed(index: int)        # 0..3
signal zoom_changed(ortho_size: float)
signal focus_changed(world_position: Vector3)


## --- Config ------------------------------------------------------------------
@export var camera: Camera3D
@export var focus_height_offset: float = 0.0

@export_group("Rotation")
## Y-rotation at index 0. 45° puts corner 0 at NE (FFTA-style diagonal),
## each Q/E step adds/subtracts 90°.
@export var initial_rotation_degrees: float = 45.0
@export var rotation_tween_duration: float = 0.22

@export_group("Zoom")
@export var zoom_min: float = 10.0   ## Min ortho size — keeps view wide enough to see context.
@export var zoom_max: float = 28.0
@export var zoom_step: float = 1.5
@export var default_zoom: float = 16.0
@export var zoom_tween_duration: float = 0.1

@export_group("Focus")
@export var focus_tween_duration: float = 0.25

@export_group("Pan")
## World-units per second when holding a pan key.
@export var pan_speed: float = 8.0


## --- State (runtime) ---------------------------------------------------------
var _rotation_index: int = 0
## Continuous target so crossing 360° tweens the short way (+90 keeps going).
var _target_y_degrees: float = 0.0

var _rotation_tween: Tween = null
var _focus_tween: Tween = null
var _zoom_tween: Tween = null

## World-space point to zoom toward (updated by main.gd from tile_hovered).
var _zoom_target: Vector3 = Vector3.ZERO
var _has_zoom_target: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_register_input_actions()

	_target_y_degrees = initial_rotation_degrees
	rotation_degrees = Vector3(0, _target_y_degrees, 0)

	if camera != null:
		camera.size = default_zoom
		camera.current = true


# =============================================================================
# ROTATION
# =============================================================================

func rotate_left() -> void:
	_rotate_by_step(-1)


func rotate_right() -> void:
	_rotate_by_step(1)


func _rotate_by_step(delta: int) -> void:
	_rotation_index = posmod(_rotation_index + delta, 4)
	_target_y_degrees += float(delta) * 90.0

	if _rotation_tween != null and _rotation_tween.is_running():
		_rotation_tween.kill()
	_rotation_tween = create_tween()
	_rotation_tween.set_ease(Tween.EASE_OUT)
	_rotation_tween.set_trans(Tween.TRANS_CUBIC)
	_rotation_tween.tween_property(
		self, "rotation_degrees:y",
		_target_y_degrees,
		rotation_tween_duration,
	)

	rotation_changed.emit(_rotation_index)


func get_rotation_index() -> int:
	return _rotation_index


# =============================================================================
# FOCUS / FOLLOW
# =============================================================================

## Move the pivot to a new world position. When the turn system lands, call
## this with the active unit's world position at turn start.
func set_focus(world_position: Vector3, instant: bool = false) -> void:
	var target: Vector3 = world_position + Vector3(0, focus_height_offset, 0)

	if instant:
		global_position = target
		focus_changed.emit(target)
		return

	if _focus_tween != null and _focus_tween.is_running():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_ease(Tween.EASE_OUT)
	_focus_tween.set_trans(Tween.TRANS_CUBIC)
	_focus_tween.tween_property(self, "global_position", target, focus_tween_duration)
	_focus_tween.finished.connect(func(): focus_changed.emit(target))


# =============================================================================
# ZOOM
# =============================================================================

## Call from main.gd when a tile is hovered so zoom tracks the cursor.
func set_zoom_target(world_pos: Vector3) -> void:
	_zoom_target = world_pos
	_has_zoom_target = true

func clear_zoom_target() -> void:
	_has_zoom_target = false


func zoom_in() -> void:
	_change_zoom(-zoom_step)


func zoom_out() -> void:
	_change_zoom(zoom_step)


func _change_zoom(delta: float) -> void:
	if camera == null:
		return
	var old_size: float = camera.size
	var new_size: float = clampf(old_size + delta, zoom_min, zoom_max)
	if is_equal_approx(new_size, old_size):
		return

	# Pan pivot toward (or away from) the hovered tile so the cursor stays
	# over the same world point. Only XZ — don't drift vertically.
	if _has_zoom_target:
		var to_target := Vector3(
			_zoom_target.x - global_position.x,
			0.0,
			_zoom_target.z - global_position.z
		)
		# Fraction of the gap to close: (1 - new/old) for zoom-in, negative for zoom-out.
		global_position += to_target * (1.0 - new_size / old_size)

	if _zoom_tween != null and _zoom_tween.is_running():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(camera, "size", new_size, zoom_tween_duration)

	zoom_changed.emit(new_size)


# =============================================================================
# INPUT
# =============================================================================

func _process(delta: float) -> void:
	var pan_dir := Vector3.ZERO
	# Compute local forward/right from current pivot Y rotation.
	var angle: float = deg_to_rad(rotation_degrees.y)
	var fwd  := Vector3(-sin(angle), 0.0, -cos(angle))
	var rgt  := Vector3( cos(angle), 0.0, -sin(angle))

	if Input.is_action_pressed("camera_pan_up"):
		pan_dir += fwd
	if Input.is_action_pressed("camera_pan_down"):
		pan_dir -= fwd
	if Input.is_action_pressed("camera_pan_left"):
		pan_dir -= rgt
	if Input.is_action_pressed("camera_pan_right"):
		pan_dir += rgt

	if pan_dir.length_squared() > 0.0:
		global_position += pan_dir.normalized() * pan_speed * delta


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_rotate_left"):
		rotate_left()
		return
	if event.is_action_pressed("camera_rotate_right"):
		rotate_right()
		return

	# Mouse wheel handled directly — not worth spinning up an InputMap entry.
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()


# =============================================================================
# INPUT ACTION REGISTRATION
# =============================================================================

## Register default bindings for camera rotation. Running at runtime (not
## editor-time) keeps project.godot's [input] section tidy — and the actions
## are idempotent if they already exist.
func _register_input_actions() -> void:
	_ensure_action("camera_rotate_left", [
		_key_event(KEY_Q),
		_joy_button_event(JOY_BUTTON_LEFT_SHOULDER),
	])
	_ensure_action("camera_rotate_right", [
		_key_event(KEY_E),
		_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER),
	])
	_ensure_action("camera_pan_up",    [_key_event(KEY_UP)])
	_ensure_action("camera_pan_down",  [_key_event(KEY_DOWN)])
	_ensure_action("camera_pan_left",  [_key_event(KEY_LEFT)])
	_ensure_action("camera_pan_right", [_key_event(KEY_RIGHT)])


static func _ensure_action(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in events:
		# Avoid duplicating bindings on hot reload.
		var already := false
		for existing in InputMap.action_get_events(action):
			if existing.get_class() == e.get_class() and _event_keys_match(existing, e):
				already = true
				break
		if not already:
			InputMap.action_add_event(action, e)


static func _key_event(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	return ev


static func _joy_button_event(button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


static func _event_keys_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).keycode == (b as InputEventKey).keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	return false
