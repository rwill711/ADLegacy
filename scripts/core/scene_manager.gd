extends Node
## Lightweight data bus for passing state between scenes.
## consume_* methods clear after reading so stale data never bleeds.


var _player_jobs: Array  = []
var _enemy_jobs: Array   = []
var _player_names: Array = []
var _enemy_names: Array  = []
var _map_template_name: String = ""
var _terrain_intensity: float = 1.0

## Endless mode run state — persists across battle reloads.
var _pending_mode: String = "single"   # "single" | "endless"
var _endless_mode: bool  = false
var _endless_round: int  = 0
var _endless_player_jobs: Array  = []
var _endless_player_names: Array = []

## Shared party inventory — one bag for the whole team, persists between rounds.
var _party_inventory: Inventory = null

## Shared equipment stash — unequipped gear available for any unit.
var _party_equipment_stash: Array = []  # Array[ItemData]

## Party gold — earned from kills and chests, spent in the shop.
var _gold: int = 0

## Win condition for the next battle (TurnEnums.WinCondition int).
var _win_condition: int = 0  # DEFEAT_ALL

## Hand-crafted level to load instead of a procedural MapTemplate.
## When non-null, main.gd uses LevelLoader.build() rather than MapBuilder.
var _level_data: LevelData = null

## Recruit tracking — cost escalates per unit purchased this run.
var _recruit_count: int = 0
var _pending_recruit_saves: Array = []

## Pending story file — set by main menu, consumed by character_select before entering main.
var _pending_story: String = ""


func set_player_jobs(jobs: Array) -> void:
	_player_jobs = jobs.duplicate()

func consume_player_jobs() -> Array:
	var out := _player_jobs.duplicate()
	_player_jobs.clear()
	return out


func set_enemy_jobs(jobs: Array) -> void:
	_enemy_jobs = jobs.duplicate()

func consume_enemy_jobs() -> Array:
	var out := _enemy_jobs.duplicate()
	_enemy_jobs.clear()
	return out


func set_player_names(names: Array) -> void:
	_player_names = names.duplicate()

func consume_player_names() -> Array:
	var out := _player_names.duplicate()
	_player_names.clear()
	return out


func set_enemy_names(names: Array) -> void:
	_enemy_names = names.duplicate()

func consume_enemy_names() -> Array:
	var out := _enemy_names.duplicate()
	_enemy_names.clear()
	return out


func set_map_template(name: String) -> void:
	_map_template_name = name

func consume_map_template() -> String:
	var out := _map_template_name
	_map_template_name = ""
	return out


func set_terrain_intensity(value: float) -> void:
	_terrain_intensity = value

func consume_terrain_intensity() -> float:
	var out := _terrain_intensity
	_terrain_intensity = 1.0
	return out


# =============================================================================
# PENDING MODE  (set by main menu before entering character select)
# =============================================================================

func set_pending_mode(mode: String) -> void:
	_pending_mode = mode

func get_pending_mode() -> String:
	return _pending_mode

func consume_pending_mode() -> String:
	var out := _pending_mode
	_pending_mode = "single"
	return out


# =============================================================================
# ENDLESS RUN STATE
# =============================================================================

func start_endless_run(jobs: Array, names: Array) -> void:
	_endless_mode = true
	_endless_round = 1
	_endless_player_jobs  = jobs.duplicate()
	_endless_player_names = names.duplicate()
	_party_inventory = Inventory.new()
	_party_equipment_stash = []
	_gold = 0
	_recruit_count = 0
	_pending_recruit_saves.clear()

func is_endless_mode() -> bool:
	return _endless_mode

func get_endless_round() -> int:
	return _endless_round

func advance_endless_round() -> void:
	_endless_round += 1

func end_endless_run() -> void:
	_endless_mode = false
	_endless_round = 0
	_endless_player_jobs.clear()
	_endless_player_names.clear()
	_party_inventory = null
	_party_equipment_stash.clear()
	_gold = 0
	_recruit_count = 0
	_pending_recruit_saves.clear()

func get_endless_player_jobs() -> Array:
	return _endless_player_jobs.duplicate()

func get_endless_player_names() -> Array:
	return _endless_player_names.duplicate()

## Restore a mid-run state loaded from a save file.
## Sets round directly instead of always resetting to 1.
func restore_endless_run(jobs: Array, names: Array, round: int) -> void:
	_endless_mode = true
	_endless_round = round
	_endless_player_jobs  = jobs.duplicate()
	_endless_player_names = names.duplicate()


# =============================================================================
# PARTY INVENTORY
# =============================================================================

## The shared consumable bag for the whole player team. Created lazily so
## practice-mode scenes also get a valid (empty) inventory without needing
## an explicit init call.
func get_party_inventory() -> Inventory:
	if _party_inventory == null:
		_party_inventory = Inventory.new()
	return _party_inventory

func set_party_inventory(inv: Inventory) -> void:
	_party_inventory = inv


# =============================================================================
# PARTY EQUIPMENT STASH
# =============================================================================

func get_party_equipment_stash() -> Array:
	return _party_equipment_stash

func add_to_equipment_stash(item: ItemData) -> void:
	if item != null:
		_party_equipment_stash.append(item)

func remove_from_equipment_stash(item: ItemData) -> bool:
	var idx: int = _party_equipment_stash.find(item)
	if idx == -1:
		return false
	_party_equipment_stash.remove_at(idx)
	return true

func clear_equipment_stash() -> void:
	_party_equipment_stash.clear()

func set_equipment_stash(items: Array) -> void:
	_party_equipment_stash = items.duplicate()


# =============================================================================
# GOLD
# =============================================================================

func get_gold() -> int:
	return _gold

func add_gold(amount: int) -> void:
	if amount > 0:
		_gold += amount

func spend_gold(amount: int) -> bool:
	if _gold < amount:
		return false
	_gold -= amount
	return true

func set_gold(amount: int) -> void:
	_gold = maxi(0, amount)


# =============================================================================
# WIN CONDITION
# =============================================================================

func set_win_condition(condition: int) -> void:
	_win_condition = condition

func consume_win_condition() -> int:
	var out := _win_condition
	_win_condition = 0
	return out


# =============================================================================
# LEVEL DATA  (hand-crafted story levels)
# =============================================================================

func set_level_data(data: LevelData) -> void:
	_level_data = data

## Returns and clears the pending level data. main.gd calls this at scene load.
func consume_level_data() -> LevelData:
	var out := _level_data
	_level_data = null
	return out

func has_level_data() -> bool:
	return _level_data != null


# =============================================================================
# RECRUIT
# =============================================================================

## Gold cost for the next recruit. Starts at 100 g, +20 g per unit already
## purchased this run so the option gets progressively more expensive.
func get_recruit_cost() -> int:
	return 100 + _recruit_count * 20

## Add a recruited unit to the endless roster. Creates a minimal save dict so
## the unit inherits party-average level when restore_from_save() runs on it
## at the start of the next battle.
func recruit_unit(job_name: StringName, display_name: String, avg_level: int) -> void:
	_endless_player_jobs.append(job_name)
	_endless_player_names.append(display_name)
	_recruit_count += 1
	var levels_gained: int = maxi(0, avg_level - 1)
	_pending_recruit_saves.append({
		"character_level":    avg_level,
		"character_xp":       0,
		"level_bonus_max_hp": levels_gained * Constants.BASE_HP_GROWTH,
		"level_bonus_max_mp": levels_gained * Constants.BASE_MP_GROWTH,
	})

## Called inside save_game() — merges pending recruit dicts into the unit list
## then clears the pending queue so they aren't double-saved.
func consume_pending_recruit_saves() -> Array:
	var out := _pending_recruit_saves.duplicate()
	_pending_recruit_saves.clear()
	return out

func get_recruit_count() -> int:
	return _recruit_count

func set_recruit_count(n: int) -> void:
	_recruit_count = maxi(0, n)


# =============================================================================
# PENDING STORY  (set by main menu, consumed by character_select)
# =============================================================================

func set_pending_story(filename: String) -> void:
	_pending_story = filename

func consume_pending_story() -> String:
	var out := _pending_story
	_pending_story = ""
	return out


# =============================================================================
# SCENE HOOKS  (pre/post battle + turn-triggered scenes)
# =============================================================================

## Filename (with extension) of a SceneData to play just before the battle
## begins (after deployment is confirmed).
var _pre_battle_scene: String  = ""
## Actor-slot overrides for the pre-battle scene (role → "player_N"/"enemy_N").
var _pre_battle_actor_slots: Dictionary = {}
## Filename of a SceneData to play immediately after the battle outcome is set.
var _post_battle_scene: String = ""
## List of {trigger:"turn", turn:int, filename:String} dicts for mid-battle scenes.
var _triggered_scenes: Array   = []

func set_pre_battle_scene(filename: String) -> void:
	_pre_battle_scene = filename

func consume_pre_battle_scene() -> String:
	var out := _pre_battle_scene
	_pre_battle_scene = ""
	return out

func set_pre_battle_actor_slots(slots: Dictionary) -> void:
	_pre_battle_actor_slots = slots.duplicate(true)

func consume_pre_battle_actor_slots() -> Dictionary:
	var out := _pre_battle_actor_slots.duplicate(true)
	_pre_battle_actor_slots.clear()
	return out

func set_post_battle_scene(filename: String) -> void:
	_post_battle_scene = filename

func consume_post_battle_scene() -> String:
	var out := _post_battle_scene
	_post_battle_scene = ""
	return out

func set_triggered_scenes(scenes: Array) -> void:
	_triggered_scenes = scenes.duplicate(true)

func consume_triggered_scenes() -> Array:
	var out := _triggered_scenes.duplicate(true)
	_triggered_scenes.clear()
	return out


# =============================================================================
# SCENE PREVIEW  (launched from Story Planner "▶ Test Scene on Map")
# Carries everything main.gd needs to spawn actors and run the director only,
# then return to the story planner when the playback finishes.
# =============================================================================

var _scene_preview: Dictionary = {}

func set_scene_preview(
	scene_file:    String,
	actor_slots:   Dictionary,
	level_name:    String,
	map_template:  String,
	player_jobs:   Array,
	return_to:     String,
	actor_facings: Dictionary = {}
) -> void:
	_scene_preview = {
		"scene_file":    scene_file,
		"actor_slots":   actor_slots.duplicate(true),
		"level_name":    level_name,
		"map_template":  map_template,
		"player_jobs":   player_jobs.duplicate(),
		"return_to":     return_to,
		"actor_facings": actor_facings.duplicate(true),
	}

func is_scene_preview() -> bool:
	return not _scene_preview.is_empty()

func consume_scene_preview() -> Dictionary:
	var out := _scene_preview.duplicate(true)
	_scene_preview.clear()
	return out
