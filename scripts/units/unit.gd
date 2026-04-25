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

	stats = p_job.instantiate_stats()
	skills = p_job.get_starting_skills()
	coord = p_coord
	facing = p_facing

	# If we're already in the tree, apply visuals now. Otherwise _ready will.
	if is_inside_tree() and _body_mesh != null:
		_apply_visual_state()


## Recalculate derived stats from current base_attributes. Call after
## level-ups, equipment changes, or any event that modifies attributes.
## Preserves current HP/MP ratios so a mid-battle re-derive doesn't
## accidentally full-heal the unit.
func rederive_stats() -> void:
	if base_attributes == null or job == null:
		return
	var hp_ratio: float = float(stats.hp) / float(stats.max_hp) if stats.max_hp > 0 else 1.0
	var mp_ratio: float = float(stats.mp) / float(stats.max_mp) if stats.max_mp > 0 else 1.0

	stats = StatFormulas.derive(base_attributes, job.base_move_range, job.base_jump)

	# Restore HP/MP to same percentage of new max
	stats.hp = clampi(int(hp_ratio * float(stats.max_hp)), 1 if hp_ratio > 0.0 else 0, stats.max_hp)
	stats.mp = clampi(int(mp_ratio * float(stats.max_mp)), 0, stats.max_mp)

	hp_changed.emit(stats.hp, stats.max_hp)
	mp_changed.emit(stats.mp, stats.max_mp)


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
	label.position = Vector3(0, capsule.height + 0.25, 0)
	_body_mesh.add_child(label)


func _apply_visual_state() -> void:
	# World position: on top of the tile at this unit's coord, including height.
	# Unit nodes don't know the grid's elevation here — the spawner calls
	# place_on_tile() for the correct world y. This method just handles facing
	# and tint; position is set externally.
	_apply_tint()
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
	if not stats.is_alive():
		set_state(UnitEnums.UnitState.DEFEATED)
		defeated.emit()
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
