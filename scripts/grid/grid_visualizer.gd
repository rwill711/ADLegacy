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

	# --- Textured top face (the box itself only shows side color) ---
	var top_mat: Material = EnvironmentArt.ground_material(tile.terrain, tile.coord)
	if top_mat != null:
		var top := MeshInstance3D.new()
		top.name = "Top"
		var top_quad := QuadMesh.new()
		top_quad.size = Vector2(size_xy, size_xy)
		top.mesh = top_quad
		top.rotation_degrees = Vector3(-90, 0, 0)
		top.position = Vector3(0, size_y * 0.5 + 0.002, 0)
		top.material_override = top_mat
		mesh_instance.add_child(top)

	# --- Terrain prop (tree or rock sits on top of tile) ---
	_add_terrain_prop(mesh_instance, tile, size_y)

	# --- Chest prop ---
	if not tile.chest_loot_tag.is_empty():
		_add_chest_prop(mesh_instance, size_y, tile.chest_loot_tag)

	# --- Structure wall prop ---
	if tile.structure_id != &"":
		_add_structure_prop(mesh_instance, size_y, tile.is_entrance)

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
# TERRAIN PROPS (tree / rock sprites on top of tiles)
# =============================================================================

func _add_terrain_prop(
	parent: MeshInstance3D,
	tile: GridTile,
	size_y: float
) -> void:
	var prop: Node3D = null
	match tile.terrain:
		GridEnums.TerrainType.FOREST:
			prop = EnvironmentArt.make_tree(tile.coord)
		GridEnums.TerrainType.MOUNTAIN:
			prop = EnvironmentArt.make_rock(tile.coord)
	if prop == null:
		return
	prop.name = "Prop"
	prop.position = Vector3(0, size_y * 0.5, 0)
	parent.add_child(prop)


## Stone wall block rising from the tile, with an arch cut-out on the entrance.
func _add_structure_prop(parent: MeshInstance3D, size_y: float, is_entrance: bool = false) -> void:
	var wall_h: float = 2.0
	var tile_size: float = GridEnums.TILE_WORLD_SIZE * 0.98

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.54, 0.48)  # stone grey-beige
	mat.roughness = 1.0

	if not is_entrance:
		# Solid wall block
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(tile_size, wall_h, tile_size)
		wall.mesh = box
		wall.position = Vector3(0.0, size_y * 0.5 + wall_h * 0.5, 0.0)
		wall.material_override = mat
		parent.add_child(wall)
	else:
		# Entrance tile: two side pillars + lintel, leaving a gap in the centre.
		var pillar_w: float = tile_size * 0.25
		var gap:      float = tile_size * 0.45
		var lintel_h: float = 0.25
		var arch_h:   float = wall_h * 0.65

		for side in [-1, 1]:
			var pillar := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(pillar_w, wall_h, tile_size)
			pillar.mesh = pb
			pillar.position = Vector3(side * (gap * 0.5 + pillar_w * 0.5),
				size_y * 0.5 + wall_h * 0.5, 0.0)
			pillar.material_override = mat
			parent.add_child(pillar)

		# Lintel above the gap
		var lintel := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(gap, lintel_h, tile_size)
		lintel.mesh = lb
		lintel.position = Vector3(0.0, size_y * 0.5 + arch_h + lintel_h * 0.5, 0.0)
		lintel.material_override = mat
		parent.add_child(lintel)

		# Gold entrance marker above the door
		var marker := MeshInstance3D.new()
		var mb := BoxMesh.new()
		mb.size = Vector3(gap * 0.6, 0.08, tile_size * 0.15)
		marker.mesh = mb
		marker.position = Vector3(0.0, size_y * 0.5 + arch_h + lintel_h + 0.1, 0.0)
		var mmat := StandardMaterial3D.new()
		mmat.albedo_color = Color(0.9, 0.72, 0.15)
		mmat.roughness = 0.3
		mmat.emission_enabled = true
		mmat.emission = Color(0.9, 0.72, 0.15) * 0.4
		marker.material_override = mmat
		parent.add_child(marker)

		# Wall torches flanking the doorway, on both faces, plus a warm light.
		var torch_y: float = size_y * 0.5 + arch_h * 0.55
		for side in [-1, 1]:
			for face in [-1, 1]:
				var torch := EnvironmentArt.make_torch()
				torch.position = Vector3(side * (gap * 0.5 + pillar_w * 0.5),
					torch_y, face * (tile_size * 0.5 + 0.04))
				parent.add_child(torch)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.65, 0.3)
		glow.light_energy = 1.2
		glow.omni_range = 2.5
		glow.shadow_enabled = false
		glow.position = Vector3(0.0, torch_y, 0.0)
		parent.add_child(glow)



func _add_chest_prop(parent: MeshInstance3D, size_y: float, loot_tag: String = "") -> void:
	var chest := EnvironmentArt.make_chest(loot_tag)
	chest.name = "Chest"
	chest.position = Vector3(0.0, size_y * 0.5, 0.0)
	parent.add_child(chest)


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
	mat.albedo_color = EnvironmentArt.side_color(terrain)
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
