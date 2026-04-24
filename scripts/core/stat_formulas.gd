class_name StatFormulas
## Centralized derived-stat formulas. Converts a BaseAttributes block into
## the concrete combat stats that UnitStats, AbilityResolver, and the turn
## system consume.
##
## WHY A SEPARATE CLASS: Design Lead and Creative Director need one place to
## tune the entire stat economy without touching unit, job, or battle code.
## Every formula is a static function with clearly labeled coefficients.
##
## MODIFIER LAYER: Equipment, buffs, and event bonuses are applied AFTER
## base derivation. The flow is:
##   BaseAttributes → StatFormulas.derive() → UnitStats (base)
##   then: equipment/buff modifiers are added on top (future system)
##
## All formulas use integer math (truncating) to keep damage predictable.
## Floating-point intermediate values are floored via int() before output.
##
## See ADR-004 for design rationale and combat math validation.


# =============================================================================
# DERIVED STAT COEFFICIENTS — the tuning knobs
# =============================================================================
# Grouped by derived stat. Naming: <DERIVED>_<SOURCE>_COEFF.
# Example: HP_CON_COEFF means "how much Constitution contributes to Max HP."

# --- Max HP ---
const HP_BASE: int = 15            ## Flat HP every unit gets
const HP_CON_COEFF: int = 5        ## Per point of CON

# --- Max MP ---
const MP_BASE: int = 5             ## Flat MP every unit gets
const MP_WIS_COEFF: int = 5        ## Per point of WIS

# --- Physical Attack ---
const ATK_STR_COEFF: int = 2       ## Per point of STR
const ATK_DEX_COEFF: int = 1       ## Per point of DEX

# --- Physical Defense ---
const DEF_CON_COEFF: int = 1       ## Per point of CON
const DEF_STR_COEFF_NUM: int = 1   ## STR contribution numerator
const DEF_STR_COEFF_DEN: int = 2   ## STR contribution denominator (avoids float)

# --- Magic Attack ---
const MAG_WIS_COEFF: int = 2       ## Per point of WIS
const MAG_CHA_COEFF: int = 1       ## Per point of CHA

# --- Magic Resistance ---
const RES_WIS_COEFF: int = 1       ## Per point of WIS
const RES_CON_COEFF_NUM: int = 1   ## CON contribution numerator
const RES_CON_COEFF_DEN: int = 2   ## CON contribution denominator

# --- Speed (turn order / CTR fill) ---
const SPD_DEX_COEFF: int = 2       ## Per point of DEX
const SPD_LCK_COEFF: int = 1       ## Per point of LCK


# =============================================================================
# DERIVATION — from BaseAttributes to UnitStats
# =============================================================================

## Produce a fully populated UnitStats from base attributes + job movement.
## move_range and jump are job-level identity stats, not attribute-derived,
## so they're passed in directly.
static func derive(attrs: BaseAttributes, move_range: int, jump: int) -> UnitStats:
	if attrs == null:
		push_error("StatFormulas.derive: null BaseAttributes")
		return UnitStats.new()

	var s := UnitStats.new()

	s.max_hp     = calc_max_hp(attrs.constitution)
	s.max_mp     = calc_max_mp(attrs.wisdom)
	s.attack     = calc_attack(attrs.strength, attrs.dexterity)
	s.defense    = calc_defense(attrs.constitution, attrs.strength)
	s.magic      = calc_magic(attrs.wisdom, attrs.charisma)
	s.resistance = calc_resistance(attrs.wisdom, attrs.constitution)
	s.speed      = calc_speed(attrs.dexterity, attrs.luck)

	s.move_range = move_range
	s.jump       = jump

	s.reset_to_full()
	return s


# =============================================================================
# INDIVIDUAL STAT FORMULAS — public so tests and UI tooltips can call them
# =============================================================================

## Max HP: flat base + CON scaling.
## CON 1 → 20 HP, CON 5 → 40 HP, CON 7 → 50 HP, CON 10 → 65 HP
static func calc_max_hp(con: int) -> int:
	return HP_BASE + (con * HP_CON_COEFF)


## Max MP: flat base + WIS scaling.
## WIS 1 → 10 MP, WIS 5 → 30 MP, WIS 9 → 50 MP, WIS 10 → 55 MP
static func calc_max_mp(wis: int) -> int:
	return MP_BASE + (wis * MP_WIS_COEFF)


## Physical attack power.
## STR 4 DEX 8 → 16, STR 6 DEX 5 → 17, STR 2 DEX 4 → 8
static func calc_attack(str_val: int, dex: int) -> int:
	return (str_val * ATK_STR_COEFF) + (dex * ATK_DEX_COEFF)


## Physical defense. Integer division truncates (intended — keeps values tight).
## CON 7 STR 6 → 10, CON 3 STR 4 → 5, CON 4 STR 2 → 5
static func calc_defense(con: int, str_val: int) -> int:
	return (con * DEF_CON_COEFF) + ((str_val * DEF_STR_COEFF_NUM) / DEF_STR_COEFF_DEN)


## Magic attack power.
## WIS 9 CHA 5 → 23, WIS 4 CHA 4 → 12, WIS 4 CHA 4 → 12
static func calc_magic(wis: int, cha: int) -> int:
	return (wis * MAG_WIS_COEFF) + (cha * MAG_CHA_COEFF)


## Magic resistance. Integer division truncates.
## WIS 9 CON 4 → 11, WIS 4 CON 7 → 7, WIS 4 CON 3 → 5
static func calc_resistance(wis: int, con: int) -> int:
	return (wis * RES_WIS_COEFF) + ((con * RES_CON_COEFF_NUM) / RES_CON_COEFF_DEN)


## Speed / turn-order stat.
## DEX 8 LCK 7 → 23, DEX 5 LCK 4 → 14, DEX 4 LCK 4 → 12
static func calc_speed(dex: int, lck: int) -> int:
	return (dex * SPD_DEX_COEFF) + (lck * SPD_LCK_COEFF)


# =============================================================================
# DEBUG / UI HELPERS
# =============================================================================

## Return a Dictionary showing every derived stat and its value for a given
## attribute block. Handy for debug overlay, character creation preview, and
## unit tooltips.
static func preview(attrs: BaseAttributes, move_range: int = 3, jump: int = 2) -> Dictionary:
	if attrs == null:
		return {}
	return {
		"max_hp":     calc_max_hp(attrs.constitution),
		"max_mp":     calc_max_mp(attrs.wisdom),
		"attack":     calc_attack(attrs.strength, attrs.dexterity),
		"defense":    calc_defense(attrs.constitution, attrs.strength),
		"magic":      calc_magic(attrs.wisdom, attrs.charisma),
		"resistance": calc_resistance(attrs.wisdom, attrs.constitution),
		"speed":      calc_speed(attrs.dexterity, attrs.luck),
		"move_range": move_range,
		"jump":       jump,
	}
