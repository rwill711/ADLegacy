class_name TurnHUD extends CanvasLayer
## HUD overlay: active unit info (top-left), phase indicator (top-center),
## turn order queue (right side). Pure display — subscribes to TurnManager
## signals and re-renders. No input handling here.


## --- Node refs (via unique names in the scene) ------------------------------
@onready var _active_name: Label = %ActiveName
@onready var _active_stats: Label = %ActiveStats
@onready var _phase_label: Label = %PhaseLabel
@onready var _foil_label: Label = %FoilLabel
@onready var _queue_list: VBoxContainer = %QueueList
@onready var _outcome_banner: Label = %OutcomeBanner


## --- State ------------------------------------------------------------------
var _turn_manager: TurnManager = null


# =============================================================================
# WIRING
# =============================================================================

## Attach this HUD to a turn manager. Disconnects from any previous one.
func bind_turn_manager(manager: TurnManager) -> void:
	if _turn_manager == manager:
		return

	if _turn_manager != null:
		_disconnect(_turn_manager.turn_started, _on_turn_started)
		_disconnect(_turn_manager.turn_ended, _on_turn_ended)
		_disconnect(_turn_manager.phase_changed, _on_phase_changed)
		_disconnect(_turn_manager.queue_updated, _on_queue_updated)
		_disconnect(_turn_manager.battle_ended, _on_battle_ended)

	_turn_manager = manager

	if _turn_manager != null:
		_turn_manager.turn_started.connect(_on_turn_started)
		_turn_manager.turn_ended.connect(_on_turn_ended)
		_turn_manager.phase_changed.connect(_on_phase_changed)
		_turn_manager.queue_updated.connect(_on_queue_updated)
		_turn_manager.battle_ended.connect(_on_battle_ended)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_turn_started(unit: Unit) -> void:
	_render_active_unit(unit)


func _on_turn_ended(_unit: Unit) -> void:
	# Leave the panel showing the unit whose turn just ended until the next
	# turn_started fires — prevents a visible flash of empty state.
	pass


## Display the current encounter's FOIL level + who's being countered.
## Called by main.gd once per battle after FOILBattleSetup runs. Blank
## string hides the label (FOIL 0 with no data, or debug disables).
func set_foil_status(level: int, dominant_archetype_name: String) -> void:
	if _foil_label == null:
		return
	if level <= 0:
		_foil_label.text = "FOIL 0 — no adaptation"
	elif dominant_archetype_name.is_empty() or dominant_archetype_name == "HYBRID":
		_foil_label.text = "FOIL %d — countering hybrid" % level
	else:
		_foil_label.text = "FOIL %d — countering %s" % [level, dominant_archetype_name]


func _on_phase_changed(phase: int) -> void:
	_phase_label.text = _label_for_phase(phase)


func _on_queue_updated(predicted_units: Array) -> void:
	_render_queue(predicted_units)


func _on_battle_ended(outcome: int) -> void:
	_outcome_banner.visible = true
	match outcome:
		TurnEnums.BattleOutcome.PLAYER_VICTORY:
			_outcome_banner.text = "VICTORY"
			_outcome_banner.modulate = Color(0.7, 1.0, 0.7)
		TurnEnums.BattleOutcome.PLAYER_DEFEAT:
			_outcome_banner.text = "DEFEAT"
			_outcome_banner.modulate = Color(1.0, 0.6, 0.6)
		TurnEnums.BattleOutcome.DRAW:
			_outcome_banner.text = "DRAW"
			_outcome_banner.modulate = Color(1.0, 1.0, 0.8)
		_:
			_outcome_banner.visible = false


# =============================================================================
# RENDERING
# =============================================================================

func _render_active_unit(unit: Unit) -> void:
	if unit == null:
		_active_name.text = "—"
		_active_stats.text = ""
		return
	_active_name.text = "%s  (%s)" % [unit.display_name, _team_label(unit.team)]
	_active_name.modulate = UnitEnums.team_color(unit.team)
	_active_stats.text = "HP %d/%d   MP %d/%d   SPD %d" % [
		unit.stats.hp, unit.stats.max_hp,
		unit.stats.mp, unit.stats.max_mp,
		unit.stats.speed,
	]


func _render_queue(predicted_units: Array) -> void:
	# Clear old children cheaply. The queue reshuffles every turn end and
	# every move that affects SPD, so rebuilding is simplest for now.
	for child in _queue_list.get_children():
		child.queue_free()

	for i in predicted_units.size():
		var unit: Unit = predicted_units[i]
		var entry := Label.new()
		entry.text = "%d. %s" % [i + 1, unit.display_name]
		entry.modulate = UnitEnums.team_color(unit.team)
		_queue_list.add_child(entry)


# =============================================================================
# HELPERS
# =============================================================================

static func _label_for_phase(phase: int) -> String:
	match phase:
		TurnEnums.TurnPhase.TICKING:         return "Ticking…"
		TurnEnums.TurnPhase.TURN_START:      return "Turn Start"
		TurnEnums.TurnPhase.AWAITING_ACTION: return "Move / Act / Wait"
		TurnEnums.TurnPhase.CHOOSING_FACING: return "Choose Facing"
		TurnEnums.TurnPhase.TURN_ENDING:     return "Ending Turn…"
		TurnEnums.TurnPhase.BATTLE_OVER:     return "Battle Over"
	return "?"


static func _team_label(team: UnitEnums.Team) -> String:
	match team:
		UnitEnums.Team.PLAYER:  return "Player"
		UnitEnums.Team.ENEMY:   return "Enemy"
		UnitEnums.Team.NEUTRAL: return "Neutral"
	return "?"


static func _disconnect(signal_ref: Signal, callable: Callable) -> void:
	if signal_ref.is_connected(callable):
		signal_ref.disconnect(callable)
