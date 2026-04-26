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

## Track the last tile the cursor entered so fast mouse movement doesn't leave
## stale hover highlights. When entering a new tile we emit unhover for the old
## one before emitting hover for the new one.
var _last_hovered: Vector2i = Vector2i(-1, -1)

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

	# --- Terrain prop (tree or rock sits on top of tile) ---
	_add_terrain_prop(mesh_instance, tile.terrain, size_y)

	# --- Overlay quad sitting just above the tile's top surface ---
	var overlay := MeshInstance3D.new()
	overlay.name = "Overlay"
	var quad := QuadMesh.new()
	quad.size = Vector2(size_xy, size_xy)
	overlay.mesh = quad
	overlay.rotation_degrees = Vector3(-90, 0, 0)
	overlay.position = Vector3(0, size_y * 0.5 + 0.015, 0)

	var overlay_mat := StandardMaterial3D.new()
	overlay_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_mat.albedo_color = Color(0, 0, 0, 0)
	overlay_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_mat.no_depth_test = true
	overlay.material_override = overlay_mat
	overlay.visible = false
	mesh_instance.add_child(overlay)

	# --- Picking area ---
	var area := Area3D.new()
	area.name = "Pick"
	area.input_ray_pickable = true
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_xy, size_y, size_xy)
	collider.shape = shape
	area.add_child(collider)
	mesh_instance.add_child(area)

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
	if tile == null:
		return
	# Full rebuild handles terrain prop changes (tree/rock appear or disappear).
	var entry = _tile_nodes.get(coord, null)
	if entry != null:
		entry["mesh"].queue_free()  # defer so in-flight mouse_entered signals finish safely
		_tile_nodes.erase(coord)
	_build_tile_node(tile)


func _on_occupancy_changed(_coord: Vector2i) -> void:
	# Occupancy doesn't affect tile rendering directly; unit nodes render
	# themselves. Hook reserved for future footprint effects (occupied tile
	# subtle tint) so downstream systems can connect cleanly.
	pass


# =============================================================================
# TERRAIN PROPS (tree / rock meshes on top of tiles)
# =============================================================================

func _add_terrain_prop(
	parent: MeshInstance3D,
	terrain: GridEnums.TerrainType,
	size_y: float
) -> void:
	match terrain:
		GridEnums.TerrainType.FOREST:
			# Trunk
			var trunk := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.05
			cyl.bottom_radius = 0.09
			cyl.height = 0.35
			trunk.mesh = cyl
			trunk.position = Vector3(0, size_y * 0.5 + 0.175, 0)
			var trunk_mat := StandardMaterial3D.new()
			trunk_mat.albedo_color = Color(0.42, 0.28, 0.14)
			trunk_mat.roughness = 1.0
			trunk.material_override = trunk_mat
			parent.add_child(trunk)
			# Canopy
			var canopy := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.3
			sph.height = 0.55
			canopy.mesh = sph
			canopy.position = Vector3(0, size_y * 0.5 + 0.62, 0)
			var canopy_mat := StandardMaterial3D.new()
			canopy_mat.albedo_color = Color(0.12, 0.52, 0.14)
			canopy_mat.roughness = 0.95
			canopy.material_override = canopy_mat
			parent.add_child(canopy)

		GridEnums.TerrainType.MOUNTAIN:
			var rock := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.28
			sph.height = 0.38
			rock.mesh = sph
			rock.scale = Vector3(1.1, 0.8, 0.95)
			rock.position = Vector3(0.05, size_y * 0.5 + 0.16, -0.05)
			var rock_mat := StandardMaterial3D.new()
			rock_mat.albedo_color = Color(0.55, 0.52, 0.48)
			rock_mat.roughness = 1.0
			rock.material_override = rock_mat
			parent.add_child(rock)


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
	if _last_hovered != Vector2i(-1, -1) and _last_hovered != coord:
		tile_unhovered.emit(_last_hovered)
	_last_hovered = coord
	tile_hovered.emit(coord)


func _on_area_mouse_exited(coord: Vector2i) -> void:
	if _last_hovered == coord:
		_last_hovered = Vector2i(-1, -1)
	tile_unhovered.emit(coord)


func _on_area_input_event(coord: Vector2i, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		tile_clicked.emit(coord, event.button_index)
