class_name EnvironmentArt
## Ground textures and prop sprites for the battle grid.
##
## Art comes from two sheets in Art/source_sheets (ground + objects), cut by
## envbuild.py into res://assets/sprites/environment/. Variants (which grass
## tile, which tree) are picked from the tile coord so a map always looks
## the same between loads.

const _Data = preload("res://scripts/grid/environment_art_data.gd")
const _ANIM_SHADER = preload("res://shaders/ground_anim.gdshader")
const DIR: String = "res://assets/sprites/environment/"

## Terrain -> [static tile set name, variant count]. Animated terrains below.
const GROUND_SETS: Dictionary = {
	GridEnums.TerrainType.GRASS:    ["grass", 4],
	GridEnums.TerrainType.FOREST:   ["grass", 4],
	GridEnums.TerrainType.STONE:    ["gravel", 4],
	GridEnums.TerrainType.MOUNTAIN: ["gravel", 4],
	GridEnums.TerrainType.FIRE:     ["burned", 4],
}

## Terrain -> [strip, frames, fps, tint, glow]
const GROUND_ANIMS: Dictionary = {
	GridEnums.TerrainType.WATER:      ["water_flow", 5, 4.0, Color(1, 1, 1), 0.0],
	GridEnums.TerrainType.DEEP_WATER: ["water_flow", 5, 3.0, Color(0.55, 0.6, 0.8), 0.0],
	GridEnums.TerrainType.LAVA:       ["lava_flow", 5, 3.0, Color(1, 1, 1), 0.6],
}

## Colors for the tile column sides (the top gets the texture).
const SIDE_COLORS: Dictionary = {
	GridEnums.TerrainType.GRASS:      Color(0.40, 0.29, 0.19),
	GridEnums.TerrainType.FOREST:     Color(0.40, 0.29, 0.19),
	GridEnums.TerrainType.STONE:      Color(0.44, 0.42, 0.40),
	GridEnums.TerrainType.MOUNTAIN:   Color(0.44, 0.42, 0.40),
	GridEnums.TerrainType.WATER:      Color(0.22, 0.36, 0.62),
	GridEnums.TerrainType.DEEP_WATER: Color(0.12, 0.20, 0.42),
	GridEnums.TerrainType.LAVA:       Color(0.28, 0.12, 0.08),
	GridEnums.TerrainType.FIRE:       Color(0.27, 0.21, 0.17),
}

## Weighted picks for props: [name, weight].
const TREES: Array = [["oak", 40], ["pine", 35], ["birch", 20], ["dead_tree", 5]]
const ROCKS: Array = [
	["rock_a", 40], ["rock_small", 15], ["iron_ore", 15], ["iron_ore_b", 10],
	["gold_ore", 8], ["gold_ore_c", 6], ["gem_rock", 3], ["gem_rock_c", 3],
]

## World units per source pixel, by prop family.
const PIXEL_SIZE_TREE: float = 0.017
const PIXEL_SIZE_ROCK: float = 0.011
const PIXEL_SIZE_CHEST: float = 0.0085
const PIXEL_SIZE_TORCH: float = 0.007

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


# =============================================================================
# GROUND
# =============================================================================

## Material for a tile's top face, or null if the terrain has no art (VOID).
static func ground_material(terrain: GridEnums.TerrainType, coord: Vector2i) -> Material:
	if GROUND_ANIMS.has(terrain):
		var key := "anim_%d" % terrain
		if not _mat_cache.has(key):
			var spec: Array = GROUND_ANIMS[terrain]
			var sm := ShaderMaterial.new()
			sm.shader = _ANIM_SHADER
			sm.set_shader_parameter("strip", _tex("ground/%s.png" % spec[0]))
			sm.set_shader_parameter("frames", int(spec[1]))
			sm.set_shader_parameter("fps", float(spec[2]))
			var tint: Color = spec[3]
			sm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
			sm.set_shader_parameter("glow", float(spec[4]))
			_mat_cache[key] = sm
		return _mat_cache[key]

	if not GROUND_SETS.has(terrain):
		return null
	var set_name: String = GROUND_SETS[terrain][0]
	var variant: int = pick_index(coord, int(GROUND_SETS[terrain][1]), 11)
	var key2 := "%s_%d_%d" % [set_name, variant, terrain]
	if not _mat_cache.has(key2):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _tex("ground/%s_%d.png" % [set_name, variant])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.roughness = 1.0
		_mat_cache[key2] = m
	return _mat_cache[key2]


static func side_color(terrain: GridEnums.TerrainType) -> Color:
	return SIDE_COLORS.get(terrain, GridEnums.terrain_color(terrain))


# =============================================================================
# PROPS
# =============================================================================

## Tree for a forest tile — idle/sway frames loop slowly so trees breathe.
static func make_tree(coord: Vector2i) -> Node3D:
	var kind: String = _weighted(TREES, coord, 3)
	if kind == "dead_tree":
		return make_sprite(["dead_tree"], PIXEL_SIZE_TREE)
	var spr := make_sprite([kind + "_idle", kind + "_sway"], PIXEL_SIZE_TREE, 0.7)
	# Offset each tree's sway so the forest doesn't move in lockstep.
	(spr as AnimatedSprite3D).frame_progress = float(pick_index(coord, 100, 5)) / 100.0
	return spr


static func make_rock(coord: Vector2i) -> Node3D:
	return make_sprite([_weighted(ROCKS, coord, 7)], PIXEL_SIZE_ROCK)


static func make_chest(loot_tag: String) -> Node3D:
	var name := "golden_chest_closed" if loot_tag == "elite" else "chest_closed"
	return make_sprite([name], PIXEL_SIZE_CHEST)


static func make_torch() -> Node3D:
	return make_sprite(["torch_0", "torch_1", "torch_2", "torch_3", "torch_4"], PIXEL_SIZE_TORCH, 8.0)


## Billboard sprite standing on its base. One name = static Sprite3D,
## several = looping AnimatedSprite3D at `fps`.
static func make_sprite(names: Array, pixel_size: float, fps: float = 5.0) -> SpriteBase3D:
	var atlas: Texture2D = _tex("objects.png")
	var spr: SpriteBase3D
	var first: Array = _Data.OBJECTS[names[0]]
	if names.size() == 1:
		var s := Sprite3D.new()
		s.texture = _region(atlas, first)
		spr = s
	else:
		var a := AnimatedSprite3D.new()
		var sf := SpriteFrames.new()
		sf.set_animation_speed(&"default", fps)
		sf.set_animation_loop(&"default", true)
		for n in names:
			sf.add_frame(&"default", _region(atlas, _Data.OBJECTS[n]))
		a.sprite_frames = sf
		a.autoplay = "default"
		spr = a
	spr.pixel_size = pixel_size
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.double_sided = true
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Same draw setup as units: depth-correct overlap, and drawn after the
	# tile highlight overlay so highlights don't tint props.
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.render_priority = 2
	# Base of the art sits on the node origin, anchor column on the center.
	var w: float = float(first[2])
	var h: float = float(first[3])
	spr.offset = Vector2(w * 0.5 - float(first[4]), h * 0.5)
	return spr


# =============================================================================
# HELPERS
# =============================================================================

## Stable pseudo-random index for a coord (salt separates independent picks).
static func pick_index(coord: Vector2i, count: int, salt: int = 0) -> int:
	if count <= 1:
		return 0
	var h: int = (coord.x * 73856093) ^ (coord.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16)) % count


static func _weighted(table: Array, coord: Vector2i, salt: int) -> String:
	var total: int = 0
	for e in table:
		total += int(e[1])
	var roll: int = pick_index(coord, total, salt)
	for e in table:
		roll -= int(e[1])
		if roll < 0:
			return e[0]
	return table[0][0]


static func _region(atlas: Texture2D, r: Array) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = atlas
	at.region = Rect2(r[0], r[1], r[2], r[3])
	return at


static func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(DIR + path)
	return _tex_cache[path]
