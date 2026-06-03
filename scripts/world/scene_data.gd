class_name SceneData

const FORMAT_VERSION: int = 1

enum StepType { MOVE, FACE, DIALOGUE, WAIT, CAMERA }

var scene_name: String = "New Scene"
var actors: Array      = []   # Array[Dictionary] — each: {role: String}
var steps: Array       = []   # Array[Dictionary] — typed step dicts
## World-space start positions for actors before the scene begins.
## Keys are role strings; values are {x:int, y:int} dicts (Vector2i serialised).
## If absent, the SceneDirector uses the unit's current position (dynamic scene).
var actor_start_positions: Dictionary = {}
## Unit slot assignments: role → "player_1"…"player_7" / "enemy_1"…"enemy_7".
## Empty string means unassigned (SceneDirector matches by unit display_name instead).
var actor_unit_slots: Dictionary = {}


static func create(p_name: String) -> SceneData:
	var s := SceneData.new()
	s.scene_name = p_name
	return s


# =============================================================================
# ACTORS
# =============================================================================

func add_actor(role: String) -> void:
	if role.strip_edges().is_empty():
		return
	for a in actors:
		if a.get("role") == role:
			return
	actors.append({"role": role})


func remove_actor(role: String) -> void:
	for i in range(actors.size() - 1, -1, -1):
		if actors[i].get("role") == role:
			actors.remove_at(i)
			break
	actor_start_positions.erase(role)
	actor_unit_slots.erase(role)


func get_actor_roles() -> Array:
	var out: Array = []
	for a in actors:
		out.append(a.get("role", ""))
	return out


func set_actor_start_position(role: String, coord: Vector2i) -> void:
	actor_start_positions[role] = {"x": coord.x, "y": coord.y}


func get_actor_start_position(role: String) -> Vector2i:
	var d: Dictionary = actor_start_positions.get(role, {})
	if d.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))


func clear_actor_start_position(role: String) -> void:
	actor_start_positions.erase(role)


func set_actor_unit_slot(role: String, slot: String) -> void:
	if slot.is_empty():
		actor_unit_slots.erase(role)
	else:
		actor_unit_slots[role] = slot


func get_actor_unit_slot(role: String) -> String:
	return actor_unit_slots.get(role, "")


# =============================================================================
# STEPS — factory helpers
# =============================================================================

static func make_move_step(actor_role: String, to_coord: Vector2i) -> Dictionary:
	return {
		"type":       "MOVE",
		"actor_role": actor_role,
		"to_x":       to_coord.x,
		"to_y":       to_coord.y,
	}


static func make_face_step(actor_role: String, direction: String) -> Dictionary:
	return {
		"type":       "FACE",
		"actor_role": actor_role,
		"direction":  direction,   # "N" | "S" | "E" | "W"
	}


static func make_dialogue_step(actor_role: String, text: String) -> Dictionary:
	return {
		"type":       "DIALOGUE",
		"actor_role": actor_role,
		"text":       text,
	}


static func make_wait_step(duration: float) -> Dictionary:
	return {
		"type":     "WAIT",
		"duration": duration,
	}


static func make_camera_step(target_coord: Vector2i) -> Dictionary:
	return {
		"type":          "CAMERA",
		"camera_target": "coord",
		"target_x":      target_coord.x,
		"target_y":      target_coord.y,
		"actor_role":    "",
	}


static func make_camera_unit_step(actor_role: String) -> Dictionary:
	return {
		"type":          "CAMERA",
		"camera_target": "unit",
		"target_x":      0,
		"target_y":      0,
		"actor_role":    actor_role,
	}


# =============================================================================
# STEPS — mutation
# =============================================================================

func add_step(step: Dictionary) -> void:
	steps.append(step)


func insert_step(idx: int, step: Dictionary) -> void:
	steps.insert(clampi(idx, 0, steps.size()), step)


func remove_step(idx: int) -> void:
	if idx >= 0 and idx < steps.size():
		steps.remove_at(idx)


func move_step(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= steps.size():
		return
	var step: Dictionary = steps[from_idx]
	steps.remove_at(from_idx)
	steps.insert(clampi(to_idx, 0, steps.size()), step)


# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"version":               FORMAT_VERSION,
		"scene_name":            scene_name,
		"actors":                actors.duplicate(true),
		"steps":                 steps.duplicate(true),
		"actor_start_positions": actor_start_positions.duplicate(true),
		"actor_unit_slots":      actor_unit_slots.duplicate(true),
	}


static func from_dict(data: Dictionary) -> SceneData:
	var s := SceneData.new()
	s.scene_name            = data.get("scene_name", "Untitled")
	s.actors                = data.get("actors", []).duplicate(true)
	s.steps                 = data.get("steps",  []).duplicate(true)
	s.actor_start_positions = data.get("actor_start_positions", {}).duplicate(true)
	s.actor_unit_slots      = data.get("actor_unit_slots",      {}).duplicate(true)
	return s
