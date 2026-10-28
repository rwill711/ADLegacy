class_name Unit extends Node3D
## A unit on the tactical grid. Data + visuals combined so each unit is a
## single scene node that can be placed, moved, and queried.
##
## Phase 2 scope: placement, facing, stats, skill listing, HP/MP plumbing.
## Phase 3 adds movement along a path; Phase 3C adds ability execution.
##
## ADR-004: Units now carry base_attributes alongside derived stats. The
## attribute block is the source of truth; stats are re-derivable at any
## time via rederive_stats() (used after level-ups, equipment changes, etc).


## --- Signals ----------------------------------------------------------------
signal hp_changed(new_hp: int, max_hp: int)
signal mp_changed(new_mp: int, max_mp: int)
signal facing_changed(new_facing: UnitEnums.Facing)
signal state_changed(new_state: UnitEnums.UnitState)
signal defeated()


## --- Identity ---------------------------------------------------------------
## Stable ID used by the grid's occupancy system and by FOIL's records.
## Keep it unique within a battle.
@export var unit_id: StringName = &""
@export var display_name: String = ""
@export var team: UnitEnums.Team = UnitEnums.Team.PLAYER


## --- Data refs --------------------------------------------------------------
## Job template; never mutated. Per-unit stats are derived from attributes.
var job: JobData = null
var base_attributes: BaseAttributes = null
var stats: UnitStats = null
var skills: Array = []
var equipment: Equipment = null
var inventory: Inventory = null
var progression: JobProgression = null

## --- Grid state -------------------------------------------------------------
var coord: Vector2i = Vector2i.ZERO
var facing: UnitEnums.Facing = UnitEnums.Facing.SOUTH
var state: UnitEnums.UnitState = UnitEnums.UnitState.IDLE


## --- Battle stats (for end-of-battle summary) -------------------------------
## Accumulated over the course of a single battle. Reset when the unit is
## re-initialized (which happens when the scene reloads on Retry).
var total_damage_dealt: int = 0
var total_damage_taken: int = 0
var actions_taken: int = 0
var kills_scored: int = 0
var skill_usage_counts: Dictionary = {}  # StringName → int


## --- FOIL loadout annotations (Phase 6) -------------------------------------
## For enemy units only. Set by UnitSpawner from the FOILLoadoutBuilder's
## output. ActionController reads ai_hints during the enemy turn's scoring
## pass to respect target_priority ("focus_healer") etc.
## For player units and in non-FOIL builds these stay at their defaults.
var ai_hints: Dictionary = {}
var consumable_tag: String = ""
var gear_hint: String = ""


## --- Visuals (built in _ready) ----------------------------------------------
var _body_mesh: MeshInstance3D = null
var _facing_arrow: MeshInstance3D = null
var _body_material: StandardMaterial3D = null
var _hp_bar_fg: MeshInstance3D = null
var _hp_bar_mat: StandardMaterial3D = null

const _HP_BAR_WIDTH: float = 0.55
const _HP_BAR_HEIGHT: float = 0.07

## Sprite visuals (used when the job has art; capsule is the fallback).
## Global size knob for all unit sprites (1.0 = per-character pixel_size).
const SPRITE_SCALE: float = 1.2
var _capsule: CapsuleMesh = null
var _sprite: AnimatedSprite3D = null
var _sprite_key: String = ""
var _current_anim: String = ""
var _team_ring_mat: StandardMaterial3D = null
var _last_world_pos: Vector3 = Vector3.INF
var _still_time: float = 0.0
var _flash_tween: Tween = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_visuals()
	_apply_visual_state()


## Initialize this unit from a job. Must be called before the unit is used.
## Called by the spawner right after instancing.
func initialize(
	p_unit_id: StringName,
	p_display_name: String,
	p_team: UnitEnums.Team,
	p_job: JobData,
	p_coord: Vector2i,
	p_facing: UnitEnums.Facing = UnitEnums.Facing.SOUTH
) -> void:
	unit_id = p_unit_id
	display_name = p_display_name
	team = p_team
	job = p_job

	# Store a duplicate of the job's base attributes on this unit.
	# Future growth (leveling, events) mutates this copy, not the job template.
	if p_job.base_attributes != null:
		base_attributes = p_job.base_attributes.duplicate(true)
	else:
		push_error("Unit.initialize: job '%s' has no base_attributes" % p_job.job_name)
		base_attributes = BaseAttributes.new()

	equipment = Equipment.new()
	inventory = Inventory.new()
	for item in ItemLibrary.get_starter_equipment(p_job.job_name):
		equipment.equip(item)
	for item in ItemLibrary.get_starter_consumables():
		inventory.add_item(item)

	# Boot the progression record and pre-award starting AP so all of this
	# job's skills are unlocked from turn 1.
	progression = JobProgression.new()
	progression.award_ap(p_job.job_name, JobProgression.STARTING_JOB_AP)

	stats = _derive_stats_with_equipment()
	skills = progression.skills_for_job(p_job.job_name)
	coord = p_coord
	facing = p_facing

	# If we're already in the tree, apply visuals now. Otherwise _ready will.
	if is_inside_tree() and _body_mesh != null:
		_apply_visual_state()


## Recalculate derived stats from current base_attributes. Call after
## level-ups or any event that modifies attributes. Preserves current
## HP/MP ratios so a mid-battle re-derive doesn't accidentally full-heal.
func rederive_stats() -> void:
	if base_attributes == null or job == null:
		return
	var hp_ratio: float = float(stats.hp) / float(stats.max_hp) if stats.max_hp > 0 else 1.0
	var mp_ratio: float = float(stats.mp) / float(stats.max_mp) if stats.max_mp > 0 else 1.0

	stats = _derive_stats_with_equipment()

	# Restore HP/MP to same percentage of new max
	stats.hp = clampi(int(hp_ratio * float(stats.max_hp)), 1 if hp_ratio > 0.0 else 0, stats.max_hp)
	stats.mp = clampi(int(mp_ratio * float(stats.max_mp)), 0, stats.max_mp)

	hp_changed.emit(stats.hp, stats.max_hp)
	mp_changed.emit(stats.mp, stats.max_mp)


# =============================================================================
# JOB PROGRESSION
# =============================================================================

## Switch this unit to a new job. Returns false and does nothing if the job is
## unknown or hasn't been unlocked yet via progression AP requirements.
## Preserves current HP/MP ratios; does NOT reset to full mid-battle.
func change_job(new_job_name: StringName) -> bool:
	var new_job: JobData = JobLibrary.get_job(new_job_name)
	if new_job == null:
		push_warning("Unit.change_job: unknown job '%s'" % new_job_name)
		return false
	if progression != null and not progression.is_job_unlocked(new_job_name):
		return false

	job = new_job
	if new_job.base_attributes != null:
		base_attributes = new_job.base_attributes.duplicate(true)

	skills = progression.skills_for_job(new_job_name) if progression != null \
		else new_job.get_starting_skills()

	rederive_stats()

	if is_inside_tree() and _body_mesh != null:
		_apply_tint()
		_refresh_sprite()

	return true


## Award AP toward a job on this unit's progression record.
## Convenience wrapper so callers don't reach into unit.progression directly.
func award_ap(job_name: StringName, amount: int) -> void:
	if progression == null:
		progression = JobProgression.new()
	progression.award_ap(job_name, amount)


# =============================================================================
# EQUIPMENT HELPERS
# =============================================================================

func equip_item(item: ItemData) -> ItemData:
	if equipment == null:
		equipment = Equipment.new()
	var old: ItemData = equipment.equip(item)
	rederive_stats()
	return old


func unequip_item(slot: ItemEnums.EquipSlot, ring_index: int = 0) -> ItemData:
	if equipment == null:
		return null
	var old: ItemData = equipment.unequip(slot, ring_index)
	if old != null:
		rederive_stats()
	return old


func _derive_stats_with_equipment() -> UnitStats:
	var attrs: BaseAttributes = base_attributes

	if equipment != null and not equipment.is_empty():
		var attr_mods: Dictionary = equipment.get_total_attribute_modifiers()
		if not attr_mods.is_empty():
			attrs = base_attributes.duplicate(true)
			if attr_mods.has("strength"):
				attrs.strength    = clampi(attrs.strength    + int(attr_mods["strength"]),    1, 99)
			if attr_mods.has("dexterity"):
				attrs.dexterity   = clampi(attrs.dexterity   + int(attr_mods["dexterity"]),   1, 99)
			if attr_mods.has("constitution"):
				attrs.constitution = clampi(attrs.constitution + int(attr_mods["constitution"]), 1, 99)
			if attr_mods.has("charisma"):
				attrs.charisma    = clampi(attrs.charisma    + int(attr_mods["charisma"]),    1, 99)
			if attr_mods.has("luck"):
				attrs.luck        = clampi(attrs.luck        + int(attr_mods["luck"]),        1, 99)
			if attr_mods.has("wisdom"):
				attrs.wisdom      = clampi(attrs.wisdom      + int(attr_mods["wisdom"]),      1, 99)

	var s: UnitStats = StatFormulas.derive(attrs, job.base_move_range, job.base_jump)

	if equipment != null and not equipment.is_empty():
		var stat_mods: Dictionary = equipment.get_total_stat_modifiers()
		for stat_name in stat_mods:
			var delta: int = int(stat_mods[stat_name])
			match stat_name:
				"max_hp":     s.max_hp     = maxi(1, s.max_hp     + delta)
				"max_mp":     s.max_mp     = maxi(0, s.max_mp     + delta)
				"attack":     s.attack     = maxi(0, s.attack     + delta)
				"defense":    s.defense    = maxi(0, s.defense    + delta)
				"magic":      s.magic      = maxi(0, s.magic      + delta)
				"resistance": s.resistance = maxi(0, s.resistance + delta)
				"speed":      s.speed      = maxi(1, s.speed      + delta)
				"move_range": s.move_range = maxi(1, s.move_range + delta)
				"jump":       s.jump       = maxi(0, s.jump       + delta)

	s.reset_to_full()
	return s


# =============================================================================
# VISUAL CONSTRUCTION
# =============================================================================

func _build_visuals() -> void:
	# Capsule body. Standing upright, height ~1.2 so it reads as a person.
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.1
	_capsule = capsule
	_body_mesh.mesh = capsule
	# Lift so the capsule's base sits on the tile's top surface.
	_body_mesh.position = Vector3(0, capsule.height * 0.5, 0)

	_body_material = StandardMaterial3D.new()
	_body_material.roughness = 0.8
	_body_mesh.material_override = _body_material

	add_child(_body_mesh)

	# Facing arrow: small prism on the capsule's "front" that points outward.
	# Placed ahead of the body at half-height so it reads from the top-down
	# isometric angle.
	_facing_arrow = MeshInstance3D.new()
	_facing_arrow.name = "FacingArrow"
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.2, 0.15, 0.3)
	arrow.left_to_right = 0.5
	_facing_arrow.mesh = arrow
	# Point the prism's "tip" in -Z (forward in Godot convention) at half height.
	_facing_arrow.position = Vector3(0, capsule.height * 0.6, -(capsule.radius + 0.15))

	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(1, 1, 1)
	arrow_mat.roughness = 0.5
	_facing_arrow.material_override = arrow_mat

	_body_mesh.add_child(_facing_arrow)

	# HP bar — two billboard quads above the unit body.
	var bar_y: float = capsule.height + 0.45
	var bg := MeshInstance3D.new()
	bg.name = "HPBarBG"
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(_HP_BAR_WIDTH, _HP_BAR_HEIGHT)
	bg.mesh = bg_quad
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.5, 0.05, 0.05)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.no_depth_test = true
	# Transparent pass + priorities: draw over tile highlights and sprites,
	# and always draw the fill on top of the background.
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.render_priority = 3
	bg.material_override = bg_mat
	bg.position = Vector3(0, bar_y, 0)
	_body_mesh.add_child(bg)

	_hp_bar_fg = MeshInstance3D.new()
	_hp_bar_fg.name = "HPBarFG"
	var fg_quad := QuadMesh.new()
	fg_quad.size = Vector2(_HP_BAR_WIDTH, _HP_BAR_HEIGHT)
	_hp_bar_fg.mesh = fg_quad
	_hp_bar_mat = StandardMaterial3D.new()
	_hp_bar_mat.albedo_color = Color(0.2, 0.85, 0.2)
	_hp_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar_mat.no_depth_test = true
	_hp_bar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hp_bar_mat.render_priority = 4
	_hp_bar_fg.material_override = _hp_bar_mat
	_hp_bar_fg.position = Vector3(0, bar_y, 0.002)
	_body_mesh.add_child(_hp_bar_fg)

	hp_changed.connect(func(_hp, _max): _update_hp_bar())
	defeated.connect(_on_defeated_visual)

	# Job label — billboard letter above the unit so you can ID them at a glance.
	var label := Label3D.new()
	label.name = "JobLabel"
	label.text = display_name.left(1).to_upper() if display_name != "" else "?"
	label.font_size = 48
	label.modulate = Color(1, 1, 1, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 5
	label.outline_render_priority = 4
	label.position = Vector3(0, capsule.height + 0.25, 0)
	_body_mesh.add_child(label)

	# Team ring on the ground — heroes and enemies share sprite art, so this
	# is how you tell friend from foe at a glance.
	var ring := MeshInstance3D.new()
	ring.name = "TeamRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.40
	torus.rings = 32
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.15, 1.0)
	ring.position = Vector3(0, 0.03, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_team_ring_mat = StandardMaterial3D.new()
	_team_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_team_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_team_ring_mat.render_priority = 1
	ring.material_override = _team_ring_mat
	add_child(ring)

	# Animated billboard sprite. Child of the unit (not the body) so the old
	# body-rotation tweens (defeat / revive) don't tip it over.
	_sprite = AnimatedSprite3D.new()
	_sprite.name = "Sprite"
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Opaque prepass keeps depth-correct overlap with trees/other units; the
	# raised priority draws it after the tile highlight overlay (which has no
	# depth test) so highlights don't tint units standing on them.
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_sprite.render_priority = 2
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite.visible = false
	_sprite.animation_finished.connect(_on_sprite_anim_finished)
	add_child(_sprite)


## Swap between sprite art and the capsule placeholder based on the job.
## Safe to call repeatedly; only rebuilds when the sprite key changes.
func _refresh_sprite() -> void:
	if _sprite == null:
		return
	var key: String = UnitSpriteLibrary.key_for(job.job_name, unit_id) if job != null else ""
	if key == _sprite_key:
		return
	_sprite_key = key
	var frames: SpriteFrames = UnitSpriteLibrary.get_frames(key) if key != "" else null
	var use_sprite: bool = frames != null
	_sprite.visible = use_sprite
	_body_mesh.mesh = null if use_sprite else _capsule
	if _facing_arrow != null:
		# Flat ground marker in front of the unit instead of a chest arrow.
		# Rotating -90 on X lays the prism down with its tip pointing forward.
		if use_sprite:
			_facing_arrow.position = Vector3(0, 0.05, -0.5)
			_facing_arrow.rotation_degrees = Vector3(-90, 0, 0)
			_facing_arrow.scale = Vector3(0.9, 0.9, 0.12)
		else:
			_facing_arrow.position = Vector3(0, _capsule.height * 0.6, -(_capsule.radius + 0.15))
			_facing_arrow.rotation_degrees = Vector3.ZERO
			_facing_arrow.scale = Vector3.ONE

	var top: float = _capsule.height
	if use_sprite:
		var d: Dictionary = UnitSpriteLibrary.info(key)
		_sprite.sprite_frames = frames
		_sprite.pixel_size = float(d["pixel_size"]) * SPRITE_SCALE
		top = float(d["h"]) * _sprite.pixel_size
		_current_anim = ""
		if is_alive() or stats == null:
			play_anim("idle")
		else:
			play_anim("death")
			_sprite.frame = _sprite.sprite_frames.get_frame_count(_sprite.animation) - 1
		_update_sprite_flip()

	# Keep HP bar + job letter just above the art.
	var bar_y: float = top + 0.12
	for n in ["HPBarBG", "HPBarFG"]:
		var bar := _body_mesh.get_node_or_null(n) as Node3D
		if bar != null:
			bar.position.y = bar_y
	var job_label := _body_mesh.get_node_or_null("JobLabel") as Node3D
	if job_label != null:
		job_label.position.y = bar_y + (0.22 if use_sprite else -0.2)


# =============================================================================
# SPRITE ANIMATION
# =============================================================================

## Play a named animation ("idle", "walk", "attack", "attack2", "cast",
## "hit", "death"). Missing ones fall back sensibly (cast -> attack, ...).
func play_anim(anim: String) -> void:
	if _sprite == null or not _sprite.visible or _sprite_key == "":
		return
	var real: String = UnitSpriteLibrary.resolve_anim(_sprite_key, anim)
	_current_anim = anim
	_sprite.play(StringName(real))


## Pick the right swing / spell animation for a skill.
func play_action_anim(skill: SkillData) -> void:
	var anim: String = "attack"
	if skill != null:
		match skill.skill_type:
			SkillEnums.SkillType.MAGIC_DAMAGE, SkillEnums.SkillType.HEALING, \
			SkillEnums.SkillType.BUFF, SkillEnums.SkillType.DEBUFF:
				anim = "cast"
			SkillEnums.SkillType.PHYSICAL_DAMAGE:
				anim = "attack" if skill.skill_name == &"basic_attack" else "attack2"
	play_anim(anim)


## Bring a defeated unit's sprite back up (used by revive items).
func play_revive() -> void:
	if _body_mesh != null:
		_body_mesh.rotation_degrees.z = 0.0
	play_anim("idle")


func _on_sprite_anim_finished() -> void:
	if not is_alive():
		return  # hold the last death frame
	play_anim("idle")


func _process(delta: float) -> void:
	if _sprite == null or not _sprite.visible:
		return
	_update_sprite_flip()

	# Walk while the move tween is carrying us between tiles.
	var pos: Vector3 = global_position
	var moved: bool = _last_world_pos != Vector3.INF \
		and pos.distance_squared_to(_last_world_pos) > 0.000001
	_last_world_pos = pos
	if moved:
		_still_time = 0.0
		if _current_anim == "idle" and is_alive():
			play_anim("walk")
	else:
		_still_time += delta
		if _current_anim == "walk" and _still_time > 0.08:
			play_anim("idle")


## Art faces right; mirror it when the unit faces screen-left.
func _update_sprite_flip() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var forward: Vector3 = -global_transform.basis.z
	var cam_right: Vector3 = cam.global_transform.basis.x
	var dot: float = forward.dot(cam_right)
	if absf(dot) > 0.05:
		_sprite.flip_h = dot < 0.0
	var d: Dictionary = UnitSpriteLibrary.info(_sprite_key)
	if d.is_empty():
		return
	# Keep the feet anchor on the tile center whichever way we face.
	var dx: float = float(d["w"]) * 0.5 - float(d["anchor_x"])
	_sprite.offset = Vector2(-dx if _sprite.flip_h else dx, float(d["h"]) * 0.5)


func _flash_hit() -> void:
	if _sprite == null or not _sprite.visible:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.3)


func _apply_visual_state() -> void:
	# World position: on top of the tile at this unit's coord, including height.
	# Unit nodes don't know the grid's elevation here — the spawner calls
	# place_on_tile() for the correct world y. This method just handles facing
	# and tint; position is set externally.
	_apply_tint()
	_refresh_sprite()
	_update_hp_bar()
	rotation.y = UnitEnums.facing_to_y_rotation(facing)
	var job_label := _body_mesh.get_node_or_null("JobLabel") as Label3D
	if job_label != null:
		job_label.text = display_name.left(1).to_upper() if display_name != "" else "?"


func _update_hp_bar() -> void:
	if _hp_bar_fg == null or stats == null:
		return
	var pct: float = float(stats.hp) / float(stats.max_hp) if stats.max_hp > 0 else 0.0
	pct = clampf(pct, 0.0, 1.0)
	var fg_mesh: QuadMesh = _hp_bar_fg.mesh as QuadMesh
	if fg_mesh != null:
		fg_mesh.size = Vector2(_HP_BAR_WIDTH * pct, _HP_BAR_HEIGHT)
	_hp_bar_fg.position.x = -_HP_BAR_WIDTH * (1.0 - pct) * 0.5
	if pct > 0.5:
		_hp_bar_mat.albedo_color = Color(0.2, 0.85, 0.2)
	elif pct > 0.25:
		_hp_bar_mat.albedo_color = Color(0.9, 0.75, 0.1)
	else:
		_hp_bar_mat.albedo_color = Color(0.85, 0.15, 0.1)


func _on_defeated_visual() -> void:
	if _body_mesh == null:
		return
	if _sprite != null and _sprite.visible:
		play_anim("death")
		return
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_body_mesh, "rotation_degrees:z", 90.0, 0.35)


func _apply_tint() -> void:
	if _body_material == null:
		return
	# Blend team color and job color: team dominates so you always read
	# friend-vs-foe first, but the job tint flavors it.
	var base := UnitEnums.team_color(team)
	var job_color := Color.WHITE if job == null else job.job_color
	_body_material.albedo_color = base.lerp(job_color, 0.35)
	if _team_ring_mat != null:
		var ring_color := base
		ring_color.a = 0.85
		_team_ring_mat.albedo_color = ring_color


# =============================================================================
# PLACEMENT
# =============================================================================

## Position this unit in the world on top of a specific tile.
## Called by the spawner at spawn, and later by the turn system on move.
func place_on_tile(tile: GridTile, instant: bool = true) -> void:
	if tile == null:
		push_error("Unit.place_on_tile: null tile for %s" % unit_id)
		return
	coord = tile.coord
	var target := tile.top_world_position()
	if instant:
		global_position = target
		return
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "global_position", target, 0.18)


# =============================================================================
# FACING
# =============================================================================

func set_facing(new_facing: UnitEnums.Facing) -> void:
	if facing == new_facing:
		return
	facing = new_facing
	rotation.y = UnitEnums.facing_to_y_rotation(facing)
	facing_changed.emit(facing)


func face_toward(target_coord: Vector2i) -> void:
	set_facing(UnitEnums.facing_toward(coord, target_coord))


# =============================================================================
# STATE
# =============================================================================

func set_state(new_state: UnitEnums.UnitState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)


# =============================================================================
# DAMAGE / HEALING
# =============================================================================

func take_damage(amount: int) -> int:
	if stats == null:
		return 0
	var lost := stats.take_damage(amount)
	total_damage_taken += lost
	hp_changed.emit(stats.hp, stats.max_hp)
	if lost > 0:
		_flash_hit()
	if not stats.is_alive():
		set_state(UnitEnums.UnitState.DEFEATED)
		defeated.emit()
	elif lost > 0:
		play_anim("hit")
	return lost


## Call when this unit is the caster of a successful action. Updates the
## summary-screen counters. ActionController aggregates damage per effect
## and passes the totals here.
func record_action_stats(
	skill_name: StringName,
	damage_dealt: int,
	kill_scored: bool
) -> void:
	actions_taken += 1
	total_damage_dealt += damage_dealt
	if kill_scored:
		kills_scored += 1
	skill_usage_counts[skill_name] = skill_usage_counts.get(skill_name, 0) + 1


func heal(amount: int) -> int:
	if stats == null:
		return 0
	var gained := stats.heal(amount)
	hp_changed.emit(stats.hp, stats.max_hp)
	return gained


func spend_mp(amount: int) -> bool:
	if stats == null:
		return amount <= 0
	var paid := stats.spend_mp(amount)
	if paid:
		mp_changed.emit(stats.mp, stats.max_mp)
	return paid


# =============================================================================
# QUERIES
# =============================================================================

func is_alive() -> bool:
	return stats != null and stats.is_alive()


func is_hostile_to(other: Unit) -> bool:
	if other == null:
		return false
	return UnitEnums.teams_are_hostile(team, other.team)


## Skills this unit can currently cast (has enough MP for). Useful for UI.
func get_castable_skills() -> Array:
	var out: Array = []
	if stats == null:
		return out
	for skill in skills:
		if stats.mp >= skill.mp_cost:
			out.append(skill)
	return out


# =============================================================================
# SERIALIZATION
# =============================================================================

## Serialize all persistent campaign state to a plain Dictionary for JSON.
## Derived fields (stats, skills) and per-battle counters are intentionally
## excluded — they're either rederived on load or reset each round.
func to_dict() -> Dictionary:
	return {
		"unit_id":      String(unit_id),
		"display_name": display_name,
		"team":         int(team),
		"job":          String(job.job_name) if job != null else "",
		"base_attributes": {
			"strength":     base_attributes.strength     if base_attributes != null else 5,
			"dexterity":    base_attributes.dexterity    if base_attributes != null else 5,
			"constitution": base_attributes.constitution if base_attributes != null else 5,
			"charisma":     base_attributes.charisma     if base_attributes != null else 5,
			"luck":         base_attributes.luck         if base_attributes != null else 5,
			"wisdom":       base_attributes.wisdom       if base_attributes != null else 5,
		},
		"equipment":  equipment.to_dict()  if equipment  != null else {},
		"inventory":  inventory.to_dict()  if inventory  != null else {"items": []},
		"progression": progression.to_dict() if progression != null else {},
	}


## Restore persistent state onto a unit that has already been initialize()d.
## Call this immediately after spawning to overlay saved progression, gear,
## and inventory over the fresh defaults that initialize() created.
## Stats and skills are rederived at the end so everything is consistent.
func restore_from_save(data: Dictionary) -> void:
	# Base attributes first — equipment stat derivation depends on them.
	if data.has("base_attributes"):
		var a: Dictionary = data["base_attributes"]
		if base_attributes != null:
			base_attributes.strength     = int(a.get("strength",     base_attributes.strength))
			base_attributes.dexterity    = int(a.get("dexterity",    base_attributes.dexterity))
			base_attributes.constitution = int(a.get("constitution", base_attributes.constitution))
			base_attributes.charisma     = int(a.get("charisma",     base_attributes.charisma))
			base_attributes.luck         = int(a.get("luck",         base_attributes.luck))
			base_attributes.wisdom       = int(a.get("wisdom",       base_attributes.wisdom))

	# Equipment — replace the starter loadout with the saved one.
	if data.has("equipment") and not data["equipment"].is_empty():
		equipment = Equipment.from_dict(data["equipment"])

	# Inventory — replace starter consumables with the saved bag.
	if data.has("inventory"):
		inventory = Inventory.from_dict(data["inventory"])

	# Progression — replace the freshly seeded record with the saved one.
	if data.has("progression"):
		progression = JobProgression.from_dict(data["progression"])

	# Rederive stats (attributes + equipment both settled now).
	stats = _derive_stats_with_equipment()

	# Rederive skills from the restored progression.
	if progression != null and job != null:
		skills = progression.skills_for_job(job.job_name)

	if is_inside_tree() and _body_mesh != null:
		_apply_visual_state()
