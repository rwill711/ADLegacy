# ADR-004: Base Attribute System — Standard Array & Derived Stats

## Status: APPROVED

## Context

Pre-alpha testing revealed two problems:
1. **Combat was too drawn out.** The Squire's 110 HP pool combined with the flat ATK-minus-DEF damage formula meant flank attacks dealt 3 damage per hit — requiring 37 hits to down a single unit. Encounters dragged past 30+ rounds.
2. **No growth path.** Stats were flat numbers hardcoded per job with no underlying attribute layer. There was nothing to level up, nothing for equipment to modify, and no mechanical basis for character differentiation within the same job.

The Creative Director requested a D&D-style "standard array" of foundational attributes that all characters share, with a fixed budget to maintain balance and a per-stat cap to leave room for growth.

## Decision

### Two-Layer Stat Architecture

**Layer 1 — Base Attributes** (new `BaseAttributes` resource):
Six attributes, each constrained to 1–10, totaling exactly 30 points:

| Attribute    | Abbr | Primary Influence                              |
|-------------|------|------------------------------------------------|
| Strength     | STR  | Physical attack, minor HP/DEF contribution     |
| Dexterity    | DEX  | Speed/turn order, physical attack secondary     |
| Constitution | CON  | Max HP (primary), physical defense (primary)    |
| Charisma     | CHA  | Buff/debuff potency, magic secondary            |
| Luck         | LCK  | Speed secondary, crit/dodge (future)            |
| Wisdom       | WIS  | Max MP, magic attack, magic resistance          |

**Layer 2 — Derived Stats** (existing `UnitStats`, now calculated):
All combat stats are outputs of formulas in `StatFormulas`:

| Derived Stat | Formula                          | Example Range (1–10 attrs) |
|-------------|----------------------------------|----------------------------|
| max_hp       | 15 + (CON × 5)                  | 20 – 65                    |
| max_mp       | 5 + (WIS × 5)                   | 10 – 55                    |
| attack       | (STR × 2) + DEX                 | 3 – 30                     |
| defense      | CON + (STR / 2)                  | 1 – 15                     |
| magic        | (WIS × 2) + CHA                 | 3 – 30                     |
| resistance   | WIS + (CON / 2)                  | 1 – 15                     |
| speed        | (DEX × 2) + LCK                 | 3 – 30                     |

Movement stats (`move_range`, `jump`) remain job-level identity stats — not attribute-derived.

### Standard Array Constraints
- **Budget:** 30 total points across 6 attributes
- **Cap:** No single attribute above 10
- **Floor:** No single attribute below 1
- Validated at creation time; invalid allocations fall back to all-5s with an error

### Alpha Job Allocations

| Job        | STR | DEX | CON | CHA | LCK | WIS | HP | MP | ATK | DEF | MAG | RES | SPD |
|-----------|-----|-----|-----|-----|-----|-----|----|----|-----|-----|-----|-----|-----|
| Rogue      | 4   | 8   | 3   | 4   | 7   | 4   | 30 | 25 | 16  | 5   | 12  | 5   | 23  |
| Squire     | 6   | 5   | 7   | 4   | 4   | 4   | 50 | 25 | 17  | 10  | 12  | 7   | 14  |
| White Mage | 2   | 4   | 4   | 5   | 4   | 9   | 35 | 50 | 8   | 5   | 23  | 11  | 12  |

### Combat Math Validation (basic_attack, power 1.0, flank)

Old system: `Rogue (ATK 14) → Squire (DEF 11, 110 HP)` = **3 dmg/hit, 37 hits to kill**

New system: `Rogue (ATK 16) → Squire (DEF 10, 50 HP)` = **6 dmg/hit, ~8 hits to kill**

Facing multipliers stack well:
- Front (0.75×): `max(1, 16×0.75 - 10)` = 2 dmg → frontal assault punished ✓
- Flank (1.0×):  `max(1, 16×1.0 - 10)` = 6 dmg → standard engagement ✓
- Rear (1.5×):   `max(1, 16×1.5 - 10)` = 14 dmg → positioning rewarded ✓
- Backstab rear: `max(1, 16×1.2×2.0×1.5 - 10)` = 48 dmg → near one-shot, high risk/reward ✓

Target encounter length: **4–8 rounds per unit.**

### Growth Model (Stubbed)

Attributes grow via:
- **Per-level allocation** (primary growth path)
- **Equipment bonuses** (modifier layer, not base mutation)
- **Story events / milestones** (permanent base increases)

The `Unit.rederive_stats()` method recalculates derived stats from current attributes, preserving HP/MP ratios. Equipment/buff modifiers will be a separate additive layer applied after base derivation (not yet implemented).

The end-game cap for individual attributes is TBD but the system supports raising `ATTRIBUTE_CAP` or adding a separate `effective_cap` that includes equipment. The base standard array invariant (total = 30) is preserved — growth adds on top.

## Architecture

### File Structure
```
scripts/core/base_attributes.gd    — BaseAttributes resource (6 stats, validation)
scripts/core/stat_formulas.gd      — StatFormulas (all derivation formulas + coefficients)
scripts/jobs/job_data.gd           — Updated: now holds BaseAttributes + movement stats
scripts/jobs/job_library.gd        — Updated: Alpha jobs use standard arrays
scripts/units/unit.gd              — Updated: carries base_attributes, has rederive_stats()
scripts/units/unit_stats.gd        — Unchanged (still the runtime stat block)
scripts/units/unit_spawner.gd      — Updated: consumable bonuses rescaled
```

### Data Flow
```
JobData.base_attributes (standard array)
         ↓
Unit.initialize() → duplicates attributes onto unit instance
         ↓
StatFormulas.derive(attributes, move_range, jump) → UnitStats
         ↓
AbilityResolver reads stats.attack, stats.defense etc. (unchanged)
         ↓
[Future] Equipment/buff modifiers applied as additive layer
         ↓
[Future] Level-up → mutate unit.base_attributes → unit.rederive_stats()
```

### Backward Compatibility
- `UnitStats` is unchanged — all existing code that reads `stats.attack`, `stats.defense`, etc. works without modification
- `AbilityResolver` is unchanged — damage formulas read the same fields
- `UnitSpawner` consumable bonuses rescaled to new ranges
- The old `UnitStats.create()` factory still works for any edge cases but is no longer the primary creation path

## Risks

1. **Formula sensitivity:** Small coefficient changes ripple through the entire combat economy. All tuning knobs are centralized in `StatFormulas` constants to make this manageable.
2. **Healing may be too strong:** White Mage Cure heals 46 HP (magic 23 × power 2.0) against a 50 HP Squire — nearly full heal. May need to reduce Cure's power multiplier or add diminishing returns. Flag for Design Lead.
3. **Rogue fragility:** 30 HP with 5 DEF means a Squire basic attack from flank deals 7 damage — Rogue dies in ~4 hits. Intentional (glass cannon) but may feel punishing. Monitor in playtests.
4. **Consumable scaling:** FOIL level 4 elite consumables now give +4 to a stat. In a system where DEF ranges 5–10, that's significant. May need per-stat caps on consumable bonuses.

## Open for Future

- Leveling system: how many attribute points per level, which attributes can grow
- Equipment modifier layer: additive bonuses that don't mutate the base array
- Luck/Charisma mechanical hooks: crit chance, dodge, steal success, FOIL interaction
- Per-character attribute customization vs pure job-based allocation
- Endgame attribute cap (total and per-stat)
