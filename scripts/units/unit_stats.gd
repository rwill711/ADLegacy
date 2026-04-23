class_name UnitStats extends Resource
## Runtime stat block for a unit. A fresh copy (via Resource.duplicate()) is
## given to each unit at spawn so damage/healing don't bleed between units
## sharing the same JobData.base_stats template.


## --- Pool stats (have current + max) ----------------------------------------
@export var max_hp: int = 100
@export var max_mp: int = 50

## Current pools. Mutated by the battle system. On spawn, caller should
## reset these to max via reset_to_full().
@export var hp: int = 100
@export var mp: int = 50


## --- Combat stats -----------------------------------------------------------
@export var attack: int = 10     # Physical damage stat
@export var defense: int = 10    # Physical damage resistance
@export var magic: int = 10      # Magical damage stat
@export var resistance: int = 10 # Magical damage resistance
@export var speed: int = 10      # Drives turn order / CTR fill rate


## --- Movement stats ---------------------------------------------------------
@export var move_range: int = 3  # Tiles per turn on flat ground
@export var jump: int = 2        # Max height delta traversable in one step


# =============================================================================
# POOL HELPERS
# =============================================================================

func is_alive() -> bool:
	return hp > 0


func is_full_hp() -> bool:
	return hp >= max_hp


## Apply damage. Returns the actual HP lost (clamped to what was available).
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var lost: int = mini(hp, amount)
	hp -= lost
	return lost


## Restore HP. Returns the actual HP gained (clamped to max).
func heal(amount: int) -> int:
	if amount <= 0 or hp >= max_hp:
		return 0
	var gained: int = mini(max_hp - hp, amount)
	hp += gained
	return gained


## Spend MP for an ability. Returns true if paid in full, false if not
## enough MP (no partial spend).
func spend_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if mp < amount:
		return false
	mp -= amount
	return true


func restore_mp(amount: int) -> int:
	if amount <= 0 or mp >= max_mp:
		return 0
	var gained: int = mini(max_mp - mp, amount)
	mp += gained
	return gained


## Reset current HP/MP to max. Called at unit spawn and after full rest.
func reset_to_full() -> void:
	hp = max_hp
	mp = max_mp


# =============================================================================
# FACTORY
# =============================================================================

static func create(
	p_max_hp: int, p_max_mp: int,
	p_attack: int, p_defense: int,
	p_magic: int, p_resistance: int,
	p_speed: int,
	p_move_range: int, p_jump: int
) -> UnitStats:
	var s := UnitStats.new()
	s.max_hp = p_max_hp
	s.max_mp = p_max_mp
	s.hp = p_max_hp
	s.mp = p_max_mp
	s.attack = p_attack
	s.defense = p_defense
	s.magic = p_magic
	s.resistance = p_resistance
	s.speed = p_speed
	s.move_range = p_move_range
	s.jump = p_jump
	return s
