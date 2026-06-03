class_name LevelEditor extends CanvasLayer

const _StructureLibrary = preload("res://scripts/world/structure_library.gd")

const TILE_PX: int = 52
const GRID_COLS: int = LevelData.DEFAULT_WIDTH
const GRID_ROWS: int = LevelData.DEFAULT_HEIGHT

enum ToolMode {
	TERRAIN,
	ELEV_UP,
	ELEV_DOWN,
	SPAWN_PLAYER,
	SPAWN_ENEMY,
	SPAWN_CLEAR,
	STRUCTURE,
	STRUCTURE_REMOVE,
	CHEST_STD,
	CHEST_ELITE,
	CHEST_CLEAR,
}

# ── state ─────────────────────────────────────────────────────────────────────
var _level: LevelData = null
var _tool: ToolMode   = ToolMode.TERRAIN
var _paint_terrain: int = GridEnums.TerrainType.GRASS
var _paint_structure: String = ""
var _mouse_down: bool = false

# ── ui refs ───────────────────────────────────────────────────────────────────
var _name_edit:    LineEdit     = null
var _status_lbl:   Label        = null
var _grid_root:    GridContainer = null
var _tile_btns:    Array        = []   # Array[Button], row-major
var _tile_styles:  Array        = []   # Array[StyleBoxFlat], parallel to _tile_btns
var _load_picker:  OptionButton = null
var _tool_buttons: Dictionary   = {}   # ToolMode → Button (for toggle highlight)


func _ready() -> void:
	_level = LevelData.create("New Level", GRID_COLS, GRID_ROWS)
	_build_ui()


# =============================================================================
# UI BUILD
# =============================================================================

func _build_ui() -> void:
	# Root panel fills the whole viewport.
	var root := PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var vbox := VBoxContainer.new()
	root.add_child(vbox)

	_build_top_bar(vbox)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_build_tool_panel(hbox)
	_build_grid_area(hbox)
	_build_status_bar(vbox)


func _build_top_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	parent.add_child(bar)

	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	bar.add_child(name_lbl)

	_name_edit = LineEdit.new()
	_name_edit.text = _level.level_name
	_name_edit.custom_minimum_size = Vector2(200, 0)
	_name_edit.text_changed.connect(func(t): _level.level_name = t)
	bar.add_child(_name_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_new_level)
	bar.add_child(new_btn)

	_load_picker = OptionButton.new()
	_load_picker.custom_minimum_size = Vector2(160, 0)
	_refresh_load_picker()
	bar.add_child(_load_picker)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_load_level_by_name)
	bar.add_child(load_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_level)
	bar.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_go_back)
	bar.add_child(back_btn)


func _build_tool_panel(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(170, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_build_terrain_section(vbox)
	_build_elevation_section(vbox)
	_build_spawn_section(vbox)
	_build_structure_section(vbox)
	_build_chest_section(vbox)


func _build_terrain_section(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "─ Terrain ─"
	parent.add_child(lbl)

	var terrain_dict: Dictionary = GridEnums.TerrainType
	for key in terrain_dict:
		var terrain_val: int = terrain_dict[key]
		var btn := Button.new()
		btn.text = key.capitalize()
		btn.toggle_mode = true
		btn.pressed.connect(_select_terrain.bind(terrain_val, btn))
		parent.add_child(btn)
		_tool_buttons[str("terrain_", terrain_val)] = btn
		if terrain_val == _paint_terrain:
			btn.button_pressed = true


func _build_elevation_section(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "─ Elevation ─"
	parent.add_child(lbl)

	var up_btn := Button.new()
	up_btn.text = "Raise (+1)"
	up_btn.toggle_mode = true
	up_btn.pressed.connect(_select_tool.bind(ToolMode.ELEV_UP, up_btn))
	parent.add_child(up_btn)
	_tool_buttons[ToolMode.ELEV_UP] = up_btn

	var dn_btn := Button.new()
	dn_btn.text = "Lower (−1)"
	dn_btn.toggle_mode = true
	dn_btn.pressed.connect(_select_tool.bind(ToolMode.ELEV_DOWN, dn_btn))
	parent.add_child(dn_btn)
	_tool_buttons[ToolMode.ELEV_DOWN] = dn_btn


func _build_spawn_section(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "─ Spawn Zones ─"
	parent.add_child(lbl)

	var p_btn := Button.new()
	p_btn.text = "Player Spawn"
	p_btn.toggle_mode = true
	p_btn.pressed.connect(_select_tool.bind(ToolMode.SPAWN_PLAYER, p_btn))
	parent.add_child(p_btn)
	_tool_buttons[ToolMode.SPAWN_PLAYER] = p_btn

	var e_btn := Button.new()
	e_btn.text = "Enemy Spawn"
	e_btn.toggle_mode = true
	e_btn.pressed.connect(_select_tool.bind(ToolMode.SPAWN_ENEMY, e_btn))
	parent.add_child(e_btn)
	_tool_buttons[ToolMode.SPAWN_ENEMY] = e_btn

	var clr_btn := Button.new()
	clr_btn.text = "Clear Spawn"
	clr_btn.toggle_mode = true
	clr_btn.pressed.connect(_select_tool.bind(ToolMode.SPAWN_CLEAR, clr_btn))
	parent.add_child(clr_btn)
	_tool_buttons[ToolMode.SPAWN_CLEAR] = clr_btn


func _build_structure_section(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "─ Structures ─"
	parent.add_child(lbl)

	var structs: Array = _StructureLibrary.all_structures()
	for s in structs:
		var btn := Button.new()
		btn.text = s.label
		btn.toggle_mode = true
		btn.pressed.connect(_select_structure.bind(s.label, btn))
		parent.add_child(btn)
		_tool_buttons[str("struct_", s.label)] = btn

	var rem_btn := Button.new()
	rem_btn.text = "Remove Structure"
	rem_btn.toggle_mode = true
	rem_btn.pressed.connect(_select_tool.bind(ToolMode.STRUCTURE_REMOVE, rem_btn))
	parent.add_child(rem_btn)
	_tool_buttons[ToolMode.STRUCTURE_REMOVE] = rem_btn


func _build_chest_section(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "─ Chests ─"
	parent.add_child(lbl)

	var std_btn := Button.new()
	std_btn.text = "Standard Chest"
	std_btn.toggle_mode = true
	std_btn.pressed.connect(_select_tool.bind(ToolMode.CHEST_STD, std_btn))
	parent.add_child(std_btn)
	_tool_buttons[ToolMode.CHEST_STD] = std_btn

	var eli_btn := Button.new()
	eli_btn.text = "Elite Chest"
	eli_btn.toggle_mode = true
	eli_btn.pressed.connect(_select_tool.bind(ToolMode.CHEST_ELITE, eli_btn))
	parent.add_child(eli_btn)
	_tool_buttons[ToolMode.CHEST_ELITE] = eli_btn

	var clr_btn := Button.new()
	clr_btn.text = "Clear Chest"
	clr_btn.toggle_mode = true
	clr_btn.pressed.connect(_select_tool.bind(ToolMode.CHEST_CLEAR, clr_btn))
	parent.add_child(clr_btn)
	_tool_buttons[ToolMode.CHEST_CLEAR] = clr_btn


func _build_grid_area(parent: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	_grid_root = GridContainer.new()
	_grid_root.columns = GRID_COLS
	scroll.add_child(_grid_root)

	_tile_btns.clear()
	_tile_styles.clear()

	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var coord := Vector2i(col, row)
			var style := StyleBoxFlat.new()
			style.bg_color = _terrain_color(GridEnums.TerrainType.GRASS)

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(TILE_PX, TILE_PX)
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover",  style)
			btn.add_theme_stylebox_override("pressed", style)
			btn.button_down.connect(_on_tile_pressed.bind(coord))
			btn.mouse_entered.connect(_on_tile_hover.bind(coord))
			_grid_root.add_child(btn)
			_tile_btns.append(btn)
			_tile_styles.append(style)

	_rebuild_grid()


func _build_status_bar(parent: VBoxContainer) -> void:
	_status_lbl = Label.new()
	_status_lbl.text = "Hover a tile to inspect."
	parent.add_child(_status_lbl)


# =============================================================================
# TOOL SELECTION
# =============================================================================

func _deselect_all_tool_buttons() -> void:
	for key in _tool_buttons:
		var btn: Button = _tool_buttons[key]
		btn.button_pressed = false


func _select_tool(mode: ToolMode, pressed_btn: Button) -> void:
	_deselect_all_tool_buttons()
	_tool = mode
	pressed_btn.button_pressed = true


func _select_terrain(terrain_val: int, pressed_btn: Button) -> void:
	_deselect_all_tool_buttons()
	_tool = ToolMode.TERRAIN
	_paint_terrain = terrain_val
	pressed_btn.button_pressed = true


func _select_structure(label: String, pressed_btn: Button) -> void:
	_deselect_all_tool_buttons()
	_tool = ToolMode.STRUCTURE
	_paint_structure = label
	pressed_btn.button_pressed = true


# =============================================================================
# INPUT — drag painting
# =============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed


func _on_tile_pressed(coord: Vector2i) -> void:
	_mouse_down = true
	_apply_tool(coord)


func _on_tile_hover(coord: Vector2i) -> void:
	_update_status(coord)
	if _mouse_down:
		_apply_tool(coord)


# =============================================================================
# TOOL APPLICATION
# =============================================================================

func _apply_tool(coord: Vector2i) -> void:
	if not _level.is_in_bounds(coord):
		return

	match _tool:
		ToolMode.TERRAIN:
			_level.set_tile_terrain(coord, _paint_terrain)

		ToolMode.ELEV_UP:
			var td: Dictionary = _level.get_tile_data(coord)
			_level.set_tile_elevation(coord, td.get("elevation", 0) + 1)

		ToolMode.ELEV_DOWN:
			var td: Dictionary = _level.get_tile_data(coord)
			_level.set_tile_elevation(coord, maxi(0, td.get("elevation", 0) - 1))

		ToolMode.SPAWN_PLAYER:
			if coord not in _level.player_spawns:
				_level.player_spawns.append(coord)
				if coord in _level.enemy_spawns:
					_level.enemy_spawns.erase(coord)

		ToolMode.SPAWN_ENEMY:
			if coord not in _level.enemy_spawns:
				_level.enemy_spawns.append(coord)
				if coord in _level.player_spawns:
					_level.player_spawns.erase(coord)

		ToolMode.SPAWN_CLEAR:
			_level.player_spawns.erase(coord)
			_level.enemy_spawns.erase(coord)

		ToolMode.STRUCTURE:
			if _paint_structure != "" and _structure_entry_at(coord) == null:
				_level.add_structure(_paint_structure, coord)

		ToolMode.STRUCTURE_REMOVE:
			_level.remove_structure(coord)

		ToolMode.CHEST_STD:
			_level.set_tile_chest(coord, "standard")

		ToolMode.CHEST_ELITE:
			_level.set_tile_chest(coord, "elite")

		ToolMode.CHEST_CLEAR:
			_level.set_tile_chest(coord, "")

	_refresh_tile(coord)


# =============================================================================
# GRID RENDERING
# =============================================================================

func _rebuild_grid() -> void:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			_refresh_tile(Vector2i(col, row))


func _refresh_tile(coord: Vector2i) -> void:
	var idx: int = coord.y * GRID_COLS + coord.x
	if idx < 0 or idx >= _tile_btns.size():
		return

	var td: Dictionary = _level.get_tile_data(coord)
	var terrain: int   = td.get("terrain", GridEnums.TerrainType.GRASS)
	var elev: int      = td.get("elevation", 0)
	var chest: String  = td.get("chest_tag", "")

	var style: StyleBoxFlat = _tile_styles[idx]
	style.bg_color = _terrain_color(terrain)

	var btn: Button = _tile_btns[idx]
	var lbl_parts: Array = []

	if elev > 0:
		lbl_parts.append(str(elev))

	var p_idx: int = _level.player_spawns.find(coord)
	var e_idx: int = _level.enemy_spawns.find(coord)
	if p_idx >= 0:
		lbl_parts.append("P%d" % (p_idx + 1))
	elif e_idx >= 0:
		lbl_parts.append("E%d" % (e_idx + 1))

	var struct_entry = _structure_entry_at(coord)
	if struct_entry != null:
		lbl_parts.append(struct_entry.get("name", "S")[0])

	if chest == "standard":
		lbl_parts.append("C")
	elif chest == "elite":
		lbl_parts.append("C!")

	btn.text = "\n".join(lbl_parts)


func _structure_entry_at(coord: Vector2i):
	for entry in _level.structures:
		if entry.get("origin") == coord:
			return entry
	return null


# =============================================================================
# STATUS BAR
# =============================================================================

func _update_status(coord: Vector2i) -> void:
	if not _level.is_in_bounds(coord):
		return
	var td: Dictionary = _level.get_tile_data(coord)
	var terrain: int   = td.get("terrain", 0)
	var elev: int      = td.get("elevation", 0)
	var chest: String  = td.get("chest_tag", "")

	var terrain_name: String = "UNKNOWN"
	for key in GridEnums.TerrainType:
		if GridEnums.TerrainType[key] == terrain:
			terrain_name = key.capitalize()
			break

	var spawn_tag: String = ""
	var ps_idx: int = _level.player_spawns.find(coord)
	var es_idx: int = _level.enemy_spawns.find(coord)
	if ps_idx >= 0:
		spawn_tag = " | Player Spawn %d" % (ps_idx + 1)
	elif es_idx >= 0:
		spawn_tag = " | Enemy Spawn %d" % (es_idx + 1)

	var chest_tag: String = ""
	if chest == "standard":
		chest_tag = " | Standard Chest"
	elif chest == "elite":
		chest_tag = " | Elite Chest"

	var struct_tag: String = ""
	var se = _structure_entry_at(coord)
	if se != null:
		struct_tag = " | Structure: " + se.get("name", "?")

	_status_lbl.text = "(%d,%d)  Terrain: %s  Elev: %d%s%s%s" % [
		coord.x, coord.y, terrain_name, elev, spawn_tag, chest_tag, struct_tag
	]


# =============================================================================
# TERRAIN COLOR PALETTE
# =============================================================================

func _terrain_color(terrain: int) -> Color:
	match terrain:
		GridEnums.TerrainType.GRASS:      return Color(0.35, 0.65, 0.30)
		GridEnums.TerrainType.STONE:      return Color(0.60, 0.58, 0.52)
		GridEnums.TerrainType.FOREST:     return Color(0.15, 0.45, 0.15)
		GridEnums.TerrainType.MOUNTAIN:   return Color(0.55, 0.50, 0.45)
		GridEnums.TerrainType.WATER:      return Color(0.20, 0.45, 0.80)
		GridEnums.TerrainType.DEEP_WATER: return Color(0.10, 0.25, 0.60)
		GridEnums.TerrainType.LAVA:       return Color(0.90, 0.30, 0.05)
		GridEnums.TerrainType.FIRE:       return Color(0.95, 0.55, 0.10)
		GridEnums.TerrainType.VOID:       return Color(0.10, 0.05, 0.15)
		_:                                return Color(0.50, 0.50, 0.50)


# =============================================================================
# SAVE / LOAD / NEW
# =============================================================================

func _new_level() -> void:
	_level = LevelData.create("New Level", GRID_COLS, GRID_ROWS)
	_name_edit.text = _level.level_name
	_rebuild_grid()
	_status_lbl.text = "New level created."
	_refresh_load_picker()


func _save_level() -> void:
	var fname: String = _level.level_name.strip_edges()
	if fname.is_empty():
		_status_lbl.text = "Error: Level name cannot be empty."
		return
	# Sanitize: replace spaces with underscores for filename safety.
	fname = fname.replace(" ", "_")
	var ok: bool = LevelLibrary.save_level(_level, fname)
	if ok:
		_status_lbl.text = "Saved: %s" % fname
		_refresh_load_picker()
	else:
		_status_lbl.text = "Error: Save failed."


func _load_level_by_name() -> void:
	if _load_picker.item_count == 0:
		_status_lbl.text = "No saved levels found."
		return
	var fname: String = _load_picker.get_item_text(_load_picker.selected)
	var loaded: LevelData = LevelLibrary.load_level(fname)
	if loaded == null:
		_status_lbl.text = "Error: Could not load '%s'." % fname
		return
	_level = loaded
	_name_edit.text = _level.level_name
	_rebuild_grid()
	_status_lbl.text = "Loaded: %s" % fname


func _refresh_load_picker() -> void:
	_load_picker.clear()
	var names: Array = LevelLibrary.list_levels()
	for n in names:
		_load_picker.add_item(n)


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
