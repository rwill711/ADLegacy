extends Node3D
## Alpha entry scene. Wires together the grid data + visualizer + camera so we
## have something that renders on `godot --run`.
##
## Responsibilities kept small: build the test map, hand it to the visualizer,
## subscribe to hover/click so debug logging works. Battle/turn wiring belongs
## to a later phase (see ALPHA_BUILD_ROADMAP.md Phases 3–4).


@export var log_tile_events: bool = true

@onready var _visualizer: GridVisualizer = $GridVisualizer
@onready var _camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	var map := AlphaTestMap.build()
	_visualizer.set_grid(map)

	_visualizer.tile_hovered.connect(_on_tile_hovered)
	_visualizer.tile_unhovered.connect(_on_tile_unhovered)
	_visualizer.tile_clicked.connect(_on_tile_clicked)

	# Center the camera on the grid. Later, the turn system replaces this with
	# camera_rig.set_focus(active_unit.world_position) at each turn start.
	_camera_rig.set_focus(_grid_center_world(map), true)


func _grid_center_world(map: GridMap) -> Vector3:
	return Vector3(
		(float(map.width) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
		0.0,
		(float(map.height) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
	)


func _on_tile_hovered(coord: Vector2i) -> void:
	var map := _visualizer.get_grid()
	if map != null:
		map.set_highlight(coord, GridEnums.HighlightState.HOVER)


func _on_tile_unhovered(coord: Vector2i) -> void:
	var map := _visualizer.get_grid()
	if map != null:
		map.set_highlight(coord, GridEnums.HighlightState.NONE)


func _on_tile_clicked(coord: Vector2i, button_index: int) -> void:
	if not log_tile_events:
		return
	var map := _visualizer.get_grid()
	if map == null:
		return
	var tile := map.get_tile(coord)
	if tile == null:
		return
	print("[tile %s] terrain=%d height=%d walkable=%s button=%d" % [
		coord, int(tile.terrain), tile.height, tile.is_walkable(), button_index
	])
