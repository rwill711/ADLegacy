extends Node3D
## Alpha entry scene. Builds the grid, spawns the roster, and wires basic
## hover/click feedback. Battle loop wiring belongs to Phase 3+.


@export var log_tile_events: bool = true

@onready var _visualizer: GridVisualizer = $GridVisualizer
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _unit_spawner: UnitSpawner = $UnitSpawner
@onready var _units_root: Node3D = $Units

var _grid: GridMap = null


func _ready() -> void:
	_grid = AlphaTestMap.build()
	_visualizer.set_grid(_grid)

	_visualizer.tile_hovered.connect(_on_tile_hovered)
	_visualizer.tile_unhovered.connect(_on_tile_unhovered)
	_visualizer.tile_clicked.connect(_on_tile_clicked)

	# Spawn the Alpha roster onto the grid.
	_unit_spawner.spawn_alpha_roster(_grid, _units_root)

	# Center the camera on the grid. Later, the turn system replaces this with
	# camera_rig.set_focus(active_unit.world_position) at each turn start.
	_camera_rig.set_focus(_grid_center_world(_grid), true)


func _grid_center_world(map: GridMap) -> Vector3:
	return Vector3(
		(float(map.width) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
		0.0,
		(float(map.height) - 1.0) * 0.5 * GridEnums.TILE_WORLD_SIZE,
	)


func _on_tile_hovered(coord: Vector2i) -> void:
	if _grid != null:
		_grid.set_highlight(coord, GridEnums.HighlightState.HOVER)


func _on_tile_unhovered(coord: Vector2i) -> void:
	if _grid != null:
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
			occupant_info = " occupant=%s(%s hp=%d/%d)" % [
				u.unit_id, u.display_name, u.stats.hp, u.stats.max_hp
			]
	print("[tile %s] terrain=%d height=%d walkable=%s button=%d%s" % [
		coord, int(tile.terrain), tile.height, tile.is_walkable(),
		button_index, occupant_info
	])
