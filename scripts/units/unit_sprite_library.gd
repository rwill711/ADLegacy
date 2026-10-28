class_name UnitSpriteLibrary
## Maps jobs to character sprite strips and builds SpriteFrames for them.
##
## Art lives in res://assets/sprites/characters/<key>.png — one horizontal
## strip per character, cut from the two source sheets (heroes + monsters).
## Frame layout / animation ranges come from unit_sprite_data.gd.
##
## Hero sheets have male + female variants; which one a unit gets is picked
## from its unit_id so it's stable across reloads.

const _Data = preload("res://scripts/units/unit_sprite_data.gd")
const SPRITE_DIR: String = "res://assets/sprites/characters/"

## Job -> base character. Hero bases get a "_m" / "_f" suffix at lookup.
const JOB_TO_BASE: Dictionary = {
	# Armored melee
	&"squire":     "knight",
	&"soldier":    "knight",
	&"knight":     "knight",
	&"paladin":    "knight",
	# Casters
	&"white_mage": "wizard",
	&"dark_mage":  "wizard",
	&"bishop":     "wizard",
	&"time_mage":  "wizard",
	&"sage":       "wizard",
	# Light / agile
	&"rogue":      "rogue",
	&"archer":     "rogue",
	&"assassin":   "rogue",
	&"ninja":      "rogue",
	&"shadow":     "rogue",
	# Monsters (no gender variants)
	&"slime":      "slime",
	&"panther":    "panther",
	&"dragon":     "dragon",
	&"werewolf":   "werewolf",
	&"wolf":       "wolf",
	&"zombie":     "zombie",
}

const _GENDERED: Array = ["knight", "wizard", "rogue"]

## When an animation is missing for a character, try these instead.
const FALLBACKS: Dictionary = {
	"run":     ["walk", "idle"],
	"walk":    ["idle"],
	"attack2": ["attack", "idle"],
	"cast":    ["attack2", "attack", "idle"],
	"attack":  ["idle"],
	"hit":     ["idle"],
	"death":   ["hit", "idle"],
}

static var _frames_cache: Dictionary = {}


## Sprite key ("knight_f", "dragon", ...) for a job + unit, or "" if none.
static func key_for(job_name: StringName, unit_id: StringName) -> String:
	var base: String = JOB_TO_BASE.get(job_name, "")
	if base == "":
		return ""
	if base in _GENDERED:
		var female: bool = (hash(String(unit_id)) & 1) == 1
		return base + ("_f" if female else "_m")
	return base


static func has_sprite(key: String) -> bool:
	return _Data.DATA.has(key)


static func info(key: String) -> Dictionary:
	return _Data.DATA.get(key, {})


## Resolve an animation name to one this character actually has.
static func resolve_anim(key: String, anim: String) -> String:
	var anims: Dictionary = info(key).get("anims", {})
	if anims.has(anim):
		return anim
	for alt in FALLBACKS.get(anim, []):
		if anims.has(alt):
			return alt
	return "idle"


## Shared SpriteFrames for a character (built once, cached).
static func get_frames(key: String) -> SpriteFrames:
	if _frames_cache.has(key):
		return _frames_cache[key]
	var d: Dictionary = info(key)
	if d.is_empty():
		return null
	var tex: Texture2D = load(SPRITE_DIR + key + ".png")
	if tex == null:
		push_warning("UnitSpriteLibrary: missing texture for '%s'" % key)
		return null

	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var w: int = d["w"]
	var h: int = d["h"]
	var anims: Dictionary = d["anims"]
	for anim_name in anims:
		var spec: Array = anims[anim_name]
		var sname := StringName(anim_name)
		sf.add_animation(sname)
		sf.set_animation_speed(sname, float(spec[2]))
		sf.set_animation_loop(sname, bool(spec[3]))
		for i in int(spec[1]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((int(spec[0]) + i) * w, 0, w, h)
			sf.add_frame(sname, at)
	_frames_cache[key] = sf
	return sf
