class_name GridVisualizer extends Node3D
## Renders a BattleGrid as 3D box tiles and handles hover/click input.
##
## Data flow is one-way: BattleGrid is the source of truth, this node only reads
## and re-renders when `tile_changed` fires. Never mutate the map from here.
##
## Input: a Camera3D in the scene handles raycast picking via Area3D children,
## one per tile. Hover/click events are emitted as signals; the battle/UI
## layer decides what to do with them.


## --- Signals -----------------------------------------------------------------
signal tile_hovered(coord: Vector2i)
signal tile_unhovered(coord: Vector2i)
signal tile_clicked(coord: Vector2i, button_index: int)


## --- Config ------------------------------------------------------------------
## The grid being rendered. Assign via set_grid() so signals wire up correctly.
var _grid: BattleGrid = null

## Map coord → {mesh: MeshInstance3D, overlay: MeshInstance3D, area: Area3D, material: StandardMaterial3D}
var _tile_nodes: Dictionary = {}

## Shared floor material cache so we don't allocate N copies of identical
## StandardMaterial3D when the whole map is one terrain type.
var _material_cache: Dictionary = {}


# =============================================================================
# PUBLIC API
# =============================================================================

func set_grid(grid: BattleGrid) -> void:
	if _grid == grid:
		return
	if _grid != null:
		if _grid.tile_changed.is_connected(_on_tile_changed):
			_grid.tile_changed.disconnect(_on_tile_changed)
		if _grid.occupancy_changed.is_connected(_on_occupancy_changed):
			_grid.occupancy_changed.disconnect(_on_occupancy_changed)

	_grid = grid
	_rebuild_all()

	if _grid != null:
		_grid.tile_changed.connect(_on_tile_changed)
		_grid.occupancy_changed.connect(_on_occupancy_changed)


func get_grid() -> BattleGrid:
	return _grid


# =============================================================================
# REBUILD
# =============================================================================

func _rebuild_all() -> void:
	for child in get_children():
		child.queue_free()
	_tile_nodes.clear()

	if _grid == null:
		return

	for row in _grid.tiles:
		for tile in row:
			_build_tile_node(tile)


func _build_tile_node(tile: GridTile) -> void:
	var size_y: float = tile.mesh_height()
	var size_xy: float = GridEnums.TILE_WORLD_SIZE * 0.98  # tiny gap so grid lines read

	# --- Base mesh (the colored box that represents the tile column) ---
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Tile_%d_%d" % [tile.coord.x, tile.coord.y]
	var box := BoxMesh.new()
	box.size = Vector3(size_xy, size_y, size_xy)
	mesh_instance.mesh = box
	mesh_instance.position = tile.mesh_center_position()

	var material := _get_terrain_material(tile.terrain)
	mesh_instance.material_override = material

	add_child(mesh_instance)

	# --- Overlay quad sitting just above the tile's top surface ---
	# Used for highlight states (hover, move range, etc.). Hidden until set.
	var overlay := MeshInstance3D.new()
	overlay.name = "Overlay"
	var quad := QuadMesh.new()
	quad.size = Vector2(size_xy, size_xy)
	overlay.mesh = quad
	overlay.rotation_degrees = Vector3(-90, 0, 0)  # lay flat
	overlay.position = tile.top_world_position() + Vector3(0, 0.015, 0)

	var overlay_mat := StandardMaterial3D.new()
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.albedo_color = Color(0, 0, 0, 0)
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.no_depth_test = false
	overlay.material_override = overlay_mat
	overlay.visible = false
	mesh_instance.add_child(overlay)

	# --- Picking area so the camera's mouse raycast can hit the tile ---
	var area := Area3D.new()
	area.name = "Pick"
	area.input_ray_pickable = true
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_xy, size_y, size_xy)
	collider.shape = shape
	area.add_child(collider)
	mesh_instance.add_child(area)

	# Capture the coord so the signal callback knows which tile fired.
	var coord_copy: Vector2i = tile.coord
	area.mouse_entered.connect(func(): _on_area_mouse_entered(coord_copy))
	area.mouse_exited.connect(func(): _on_area_mouse_exited(coord_copy))
	area.input_event.connect(
		func(_camera, event, _pos, _normal, _shape_idx):
			_on_area_input_event(coord_copy, event)
	)

	_apply_highlight(overlay, overlay_mat, tile.highlight_state)

	_tile_nodes[tile.coord] = {
		"mesh": mesh_instance,
		"overlay": overlay,
		"overlay_material": overlay_mat,
		"area": area,
	}


# =============================================================================
# INCREMENTAL UPDATES
# =============================================================================

func _on_tile_changed(coord: Vector2i) -> void:
	if _grid == null:
		return
	var tile := _grid.get_tile(coord)
	var entry = _tile_nodes.get(coord, null)
	if entry == null or tile == null:
		return

	var mesh_instance: MeshInstance3D = entry["mesh"]
	var overlay: MeshInstance3D = entry["overlay"]
	var overlay_mat: StandardMaterial3D = entry["overlay_material"]

	# Terrain might have been swapped at runtime (e.g., debug console).
	mesh_instance.material_override = _get_terrain_material(tile.terrain)

	# Elevation change: resize the box and reposition.
	var size_y: float = tile.mesh_height()
	var size_xy: float = GridEnums.TILE_WORLD_SIZE * 0.98
	var box: BoxMesh = mesh_instance.mesh as BoxMesh
	if box != null:
		box.size = Vector3(size_xy, size_y, size_xy)
	mesh_instance.position = tile.mesh_center_position()
	overlay.position = tile.top_world_position() + Vector3(0, 0.015, 0)

	_apply_highlight(overlay, overlay_mat, tile.highlight_state)


func _on_occupancy_changed(_coord: Vector2i) -> void:
	# Occupancy doesn't affect tile rendering directly; unit nodes render
	# themselves. Hook reserved for future footprint effects (occupied tile
	# subtle tint) so downstream systems can connect cleanly.
	pass


# =============================================================================
# HIGHLIGHT APPLICATION
# =============================================================================

func _apply_highlight(
	overlay: MeshInstance3D,
	overlay_mat: StandardMaterial3D,
	state: GridEnums.HighlightState
) -> void:
	if state == GridEnums.HighlightState.NONE:
		overlay.visible = false
		return
	overlay.visible = true
	overlay_mat.albedo_color = GridEnums.highlight_color(state)


# =============================================================================
# MATERIAL CACHE
# =============================================================================

func _get_terrain_material(terrain: GridEnums.TerrainType) -> StandardMaterial3D:
	if _material_cache.has(terrain):
		return _material_cache[terrain]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GridEnums.terrain_color(terrain)
	mat.roughness = 0.9
	_material_cache[terrain] = mat
	return mat


# =============================================================================
# INPUT CALLBACKS (from per-tile Area3D)
# =============================================================================

func _on_area_mouse_entered(coord: Vector2i) -> void:
	tile_hovered.emit(coord)


func _on_area_mouse_exited(coord: Vector2i) -> void:
	tile_unhovered.emit(coord)


func _on_area_input_event(coord: Vector2i, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		tile_clicked.emit(coord, event.button_index)
