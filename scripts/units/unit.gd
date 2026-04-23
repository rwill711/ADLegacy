class_name Unit extends Node3D
## A unit on the tactical grid. Data + visuals combined so each unit is a
## single scene node that can be placed, moved, and queried.
##
## Phase 2 scope: placement, facing, stats, skill listing, HP/MP plumbing.
## Phase 3 adds movement along a path; Phase 3C adds ability execution.


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
## Job template; never mutated. Per-unit stats are a duplicated instance.
var job: JobData = null
var stats: UnitStats = null
var skills: Array = []


## --- Grid state -------------------------------------------------------------
var coord: Vector2i = Vector2i.ZERO
var facing: UnitEnums.Facing = UnitEnums.Facing.SOUTH
var state: UnitEnums.UnitState = UnitEnums.UnitState.IDLE


## --- Visuals (built in _ready) ----------------------------------------------
var _body_mesh: MeshInstance3D = null
var _facing_arrow: MeshInstance3D = null
var _body_material: StandardMaterial3D = null


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
	stats = p_job.instantiate_stats()
	skills = p_job.get_starting_skills()
	coord = p_coord
	facing = p_facing

	# If we're already in the tree, apply visuals now. Otherwise _ready will.
	if is_inside_tree() and _body_mesh != null:
		_apply_visual_state()


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


func _apply_visual_state() -> void:
	# World position: on top of the tile at this unit's coord, including height.
	# Unit nodes don't know the grid's elevation here — the spawner calls
	# place_on_tile() for the correct world y. This method just handles facing
	# and tint; position is set externally.
	_apply_tint()
	rotation.y = UnitEnums.facing_to_y_rotation(facing)


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
	hp_changed.emit(stats.hp, stats.max_hp)
	if not stats.is_alive():
		set_state(UnitEnums.UnitState.DEFEATED)
		defeated.emit()
	return lost


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
