class_name BaseAttributes extends Resource
## The six foundational character attributes that drive all derived combat
## stats. Every unit — player or enemy — starts with a standard-array
## allocation of these. Growth (leveling, equipment, events) modifies this
## layer; derived stats (HP, ATK, DEF, etc.) are recalculated from it.
##
## Design constraints (ADR-004):
##   • Total attribute points must equal ATTRIBUTE_BUDGET (default 30)
##   • No single attribute may exceed ATTRIBUTE_CAP (default 10)
##   • No single attribute may fall below ATTRIBUTE_FLOOR (default 1)
##
## These constraints are validated at creation time and can be re-checked
## at any point via is_valid(). Equipment and event bonuses are applied as
## a separate modifier layer — they do NOT mutate these base values, so
## the standard-array invariant is always preserved on the base.


# =============================================================================
# BUDGET CONSTANTS — tune these to reshape the entire stat economy
# =============================================================================

## Total attribute points each character gets at creation.
const ATTRIBUTE_BUDGET: int = 30

## Hard ceiling per individual attribute.
const ATTRIBUTE_CAP: int = 10

## Hard floor per individual attribute.
const ATTRIBUTE_FLOOR: int = 1

## Number of attributes (used for validation math).
const ATTRIBUTE_COUNT: int = 6


# =============================================================================
# THE SIX ATTRIBUTES
# =============================================================================

## Physical power. Drives attack damage and minor HP contribution.
@export_range(1, 10) var strength: int = 5

## Agility and reflexes. Drives speed/turn order and physical accuracy.
@export_range(1, 10) var dexterity: int = 5

## Toughness and endurance. Primary driver of max HP and physical defense.
@export_range(1, 10) var constitution: int = 5

## Force of personality. Drives buff/debuff potency and steal/persuade chance.
@export_range(1, 10) var charisma: int = 5

## Fortune and instinct. Drives crit chance, dodge, loot quality.
@export_range(1, 10) var luck: int = 5

## Mental acuity and magical aptitude. Drives max MP, magic attack, and
## magic resistance.
@export_range(1, 10) var wisdom: int = 5


# =============================================================================
# VALIDATION
# =============================================================================

## Check that this attribute block satisfies all design constraints.
## Returns an empty string on success, or a human-readable error message.
func validate() -> String:
	var total: int = get_total()

	if total != ATTRIBUTE_BUDGET:
		return "Attribute total is %d, expected %d" % [total, ATTRIBUTE_BUDGET]

	var attrs: Dictionary = get_as_dict()
	for attr_name in attrs:
		var val: int = attrs[attr_name]
		if val < ATTRIBUTE_FLOOR:
			return "%s is %d, below floor of %d" % [attr_name, val, ATTRIBUTE_FLOOR]
		if val > ATTRIBUTE_CAP:
			return "%s is %d, above cap of %d" % [attr_name, val, ATTRIBUTE_CAP]

	return ""


## Shorthand — returns true only if validate() passes.
func is_valid() -> bool:
	return validate() == ""


## Sum of all six attributes.
func get_total() -> int:
	return strength + dexterity + constitution + charisma + luck + wisdom


# =============================================================================
# ACCESSORS
# =============================================================================

## Return all attributes as a flat dictionary. Useful for iteration,
## serialization, and debug display.
func get_as_dict() -> Dictionary:
	return {
		"strength": strength,
		"dexterity": dexterity,
		"constitution": constitution,
		"charisma": charisma,
		"luck": luck,
		"wisdom": wisdom,
	}


## Set attributes from a dictionary. Keys must match the property names.
## Silently ignores unknown keys. Does NOT validate — call validate() after.
func set_from_dict(data: Dictionary) -> void:
	if data.has("strength"):    strength = int(data["strength"])
	if data.has("dexterity"):   dexterity = int(data["dexterity"])
	if data.has("constitution"):constitution = int(data["constitution"])
	if data.has("charisma"):    charisma = int(data["charisma"])
	if data.has("luck"):        luck = int(data["luck"])
	if data.has("wisdom"):      wisdom = int(data["wisdom"])


# =============================================================================
# FACTORY
# =============================================================================

## Create a validated BaseAttributes instance. Pushes an error and returns
## a default (all 5s) block if the supplied values violate constraints.
static func create(
	p_str: int, p_dex: int, p_con: int,
	p_cha: int, p_lck: int, p_wis: int
) -> BaseAttributes:
	var a := BaseAttributes.new()
	a.strength = p_str
	a.dexterity = p_dex
	a.constitution = p_con
	a.charisma = p_cha
	a.luck = p_lck
	a.wisdom = p_wis

	var err: String = a.validate()
	if err != "":
		push_error("BaseAttributes.create: invalid allocation — %s. Falling back to default (all 5s)." % err)
		return BaseAttributes.new()  # default all-5s

	return a
