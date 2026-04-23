class_name TurnEnums
## Shared constants and enums for the turn system.
## Kept isolated so tuning CT thresholds / costs doesn't require editing
## the manager, UI, or AI in lockstep.


## --- Turn phase state machine -----------------------------------------------
## Fires on every transition via TurnManager.phase_changed(phase).
##
## Flow:
##   TICKING         → the CT counter is filling; no one has the turn yet.
##   TURN_START      → one-shot "a unit just got the turn" beat. UI reads this
##                      to focus the camera, play a sting, etc. Usually we fall
##                      straight through to AWAITING_ACTION in the same tick.
##   AWAITING_ACTION → the active unit has MOVE and/or ACT available. Player
##                      (or AI) picks an option. Entered multiple times within
##                      one turn as the unit consumes actions.
##   CHOOSING_FACING → MOVE and ACT are spent (or the unit Waited). Must pick
##                      a cardinal facing before the turn closes. Non-skippable
##                      per Creative's ruling — facing is core tactics feel.
##   TURN_ENDING     → facing chosen, CT deducted, damage-over-turn applied.
##                      Usually a single-frame transient state.
##   BATTLE_OVER     → a win/lose condition fired. TurnManager stops ticking.
enum TurnPhase {
	TICKING,
	TURN_START,
	AWAITING_ACTION,
	CHOOSING_FACING,
	TURN_ENDING,
	BATTLE_OVER,
}


## --- CT counter constants ---------------------------------------------------
## Classic FFTA-style: every tick, each unit's CT += its SPEED stat. First unit
## to cross the threshold acts. What the unit did on their turn drives how
## deeply the counter is drained — Waiting drops less than a full Move+Act.

## Acting requires this much CT.
const CT_ACTION_THRESHOLD: int = 100

## CT reset after the turn, depending on what the unit chose.
## Tunable numbers — Phase 10 balance pass will revisit.
const CT_COST_WAIT: int = 60           # Ended immediately without move or act
const CT_COST_MOVED_ONLY: int = 80     # Moved but didn't act
const CT_COST_ACTED_ONLY: int = 80     # Acted but didn't move
const CT_COST_FULL_TURN: int = 100     # Did both move AND act

## Max CT units can hold. Prevents runaway numbers in case of very fast units
## and very long battles.
const CT_MAX: int = 999


## --- Battle outcome ---------------------------------------------------------
enum BattleOutcome {
	ONGOING,
	PLAYER_VICTORY,
	PLAYER_DEFEAT,
	DRAW,           # Possible if a party KOs everyone simultaneously (AOE trade).
}
