# ADR-005: Item & Equipment System — Gear Slots, Consumables, Two-Pass Stat Derivation

## Status: APPROVED

## Context

ADR-004 established the two-layer stat architecture (BaseAttributes → StatFormulas → UnitStats) and explicitly marked equipment modifiers as "future: additive layer applied after base derivation." With the core attribute economy stable and combat math validated, we need to:

1. **Give units gear** that modifies their stats, fulfilling the growth model promised in ADR-004.
2. **Give units consumable items** (potions) usable as battle actions, adding a resource-management dimension to tactical combat.
3. **Wire everything into the spawn flow** so units start with class-appropriate equipment and a small consumable bag.

The system must preserve the standard-array invariant (base attributes always total 30, each 1–10) while allowing equipment to push *effective* attributes beyond that range.

## Decision

### Architecture: Six New Files

```
scripts/items/
  item_enums.gd      — ItemType, EquipSlot, ConsumableEffect, Rarity enums
  item_data.gd       — ItemData resource (identity + modifiers + consumable data)
  equipment.gd       — Equipment container (8-slot loadout, equip/unequip/query)
  inventory.gd       — Inventory container (consumable bag, max 6 items)
  item_library.gd    — Catalog of all Alpha items + starter loadout factory
  item_resolver.gd   — Consumable effect resolution during battle
```

Modified files:
```
scripts/units/unit.gd  — Carries Equipment + Inventory, two-pass stat derivation
```

### Equipment Slot Design (8 Slots)

| Slot    | Count | Alpha Usage                        |
|---------|-------|------------------------------------|
| HELM    | 1     | Stubs only — not equipped by default |
| BODY    | 1     | Starter armor (+1 CON each)        |
| BOOTS   | 1     | Starter boots (+1 CON each)        |
| GLOVES  | 1     | Empty — future                     |
| TRINKET | 1     | Weapons stored here as identity    |
| RING    | 2     | Empty — future                     |
| SHIELD  | 1     | Empty — future                     |

**Why 8 slots?** Standard TRPG convention (FFT has 5–6, Disgaea has 4+). 8 gives enough variety for meaningful build choices post-Alpha without being overwhelming. Ring slots (×2) are the classic "flex accessory" pattern.

### Two-Pass Stat Derivation

The critical design: equipment can modify *attributes* (which cascade through StatFormulas) or *derived stats* (flat bonuses after derivation). This gives designers two tuning levers:

**Pass 1 — Attribute Modifiers** (multiplicative via formulas):
```
temp_attributes = base_attributes.duplicate()
temp_attributes.constitution += sum(all equipment CON bonuses)  # e.g., +2 from body + boots
StatFormulas.derive(temp_attributes, move, jump) → UnitStats
```
A +1 CON bonus yields +5 HP, +1 DEF, and minor RES through the existing formulas. This is the *intended* primary modifier path for Alpha — small attribute bumps create meaningful stat changes.

**Pass 2 — Flat Stat Modifiers** (additive, post-derivation):
```
unit_stats.speed += sum(all equipment speed bonuses)
```
Used for targeted stat boosts that shouldn't ripple through formulas (e.g., +2 speed boots that don't also change HP).

**Invariant preserved:** `unit.base_attributes` is never mutated by equipment. The temp copy is discarded after derivation. Growth systems (leveling, story events) mutate `base_attributes` directly; equipment operates on a separate layer.

### Alpha Starter Loadouts

| Job        | Body         | Boots         | Net Attribute Bonus | Stat Impact              |
|-----------|-------------|---------------|--------------------|--------------------------| 
| Rogue      | Leather Vest | Leather Boots | +2 CON             | +10 HP, +2 DEF, +1 RES  |
| Squire     | Chain Mail   | Iron Boots    | +2 CON             | +10 HP, +2 DEF, +1 RES  |
| White Mage | Cloth Robe   | Sandals       | +2 CON             | +10 HP, +2 DEF, +1 RES  |

All starter gear gives identical stat bonuses (+1 CON per piece). The *names* are class-flavored for immersion but mechanically equivalent. This is intentional for Alpha — differentiated gear comes with the loot/shop system.

**Updated stat table with starter gear:**

| Job        | HP (base→equipped) | DEF (base→equipped) |
|-----------|--------------------|---------------------|
| Rogue      | 30 → 40            | 5 → 7              |
| Squire     | 50 → 60            | 10 → 12            |
| White Mage | 35 → 45            | 5 → 7              |

### Consumable System

Three potions for Alpha:

| Item           | Effect         | Value | Range | Rarity |
|---------------|----------------|-------|-------|--------|
| Health Potion  | Restore HP     | 20    | 1     | Common |
| Mana Potion    | Restore MP     | 15    | 1     | Common |
| Lazarus Potion | Revive (% max) | 50%   | 1     | Rare   |

**Inventory rules:**
- Max 6 consumables per unit
- Duplicates allowed (carry 3 Health Potions)
- Items are consumed on use (removed from inventory)
- Every unit starts with 1 Health Potion + 1 Mana Potion

**ItemResolver** handles usage during battle:
- Validates targeting (alive for potions, dead for revive)
- Applies effects via existing Unit.heal() / UnitStats.restore_mp()
- Returns a result Dictionary matching AbilityResolver's shape for consistent visual/log handling
- Revive resets unit state from DEFEATED → IDLE

### Targeting Rules

| Effect     | Valid Targets                    |
|-----------|----------------------------------|
| Restore HP | Alive allies, not at full HP     |
| Restore MP | Alive allies, not at full MP     |
| Revive     | Defeated allies (HP = 0)         |

All Alpha consumables are ally-targeted. `use_range: 1` means the user must be adjacent to (or be) the target.

### Integration Points

**Unit.initialize():**
1. Creates Equipment + Inventory
2. Equips starter gear via ItemLibrary.get_starter_equipment()
3. Adds starter consumables via ItemLibrary.get_starter_consumables()
4. Calls `_derive_stats_with_equipment()` (replaces old `job.instantiate_stats()`)

**Unit.equip_item() / unequip_item():**
Auto-call `rederive_stats()` so stats are always consistent with current gear.

**Battle flow (future wiring):**
ActionController will offer "Item" as an action type alongside "Move" and "Ability". On selection, the UI shows the unit's inventory; player picks an item, then targets. ActionController calls `ItemResolver.resolve()`.

## Risks

1. **Attribute modifier overflow:** Equipment can push effective attributes above the BaseAttributes cap of 10. The derivation clamps to 1–99 to prevent negatives but doesn't enforce the cap. This is intentional — equipment *should* be able to exceed the natural cap. But it means StatFormulas must be robust across the full 1–99 range. Currently validated for 1–10 only. **Mitigation:** Alpha gear only gives +1 per piece (max effective CON = 9 for Squire). Monitor when stronger gear is added.

2. **Consumable action economy:** Using an item costs your turn but has no MP cost. If potions are too strong, the optimal play becomes "spam potions and stall." **Mitigation:** Limited inventory (6 slots), single-use, range 1 (must be adjacent). Monitor in playtests.

3. **Revive loop:** Lazarus Potion → ally revives → gets killed → another Lazarus Potion. With 6 inventory slots and rare rarity, this is self-limiting. But if future systems add item refills or shops during battle, cap revive frequency. **Mitigation:** Rarity.RARE — starter inventory doesn't include Lazarus Potion. Only available from loot/shops.

4. **FOIL consumable interaction:** UnitSpawner already applies FOIL consumable bonuses as flat stat boosts (Phase 6). This is a *different system* from the inventory consumables. Naming collision risk ("consumable" means two things). **Mitigation:** FOIL bonuses remain in UnitSpawner as `consumable_tag` / `CONSUMABLE_STAT_BONUSES`. Battle consumables live in Inventory/ItemResolver. Document the distinction clearly.

5. **UnitStats.restore_mp() dependency:** ItemResolver calls `target.stats.restore_mp()` directly rather than going through a Unit-level wrapper (unlike `heal()` which has `Unit.heal()`). This means `mp_changed` signal won't fire for MP potions. **Mitigation:** Add `Unit.restore_mp()` wrapper in the next pass, or have ItemResolver call `mp_changed.emit()` explicitly after use.

## Open for Future

- **Weapon slot:** A proper weapon slot (not trinket) that modifies attack power and potentially changes basic attack behavior.
- **Set bonuses:** Equipping matching gear (e.g., full Leather set) for bonus effects.
- **Equipment restrictions:** Job-based equip restrictions (Rogue can't wear Chain Mail).
- **Item shop / loot drops:** Post-battle rewards, pre-battle shop, and Lazarus Potion availability.
- **Battle "Item" command:** Wire ItemResolver into ActionController's action menu alongside Move/Ability/Wait.
- **Enemy item usage:** FOIL-driven enemies using consumables during their AI turn.
- **Equipment UI:** Equip/unequip screen, stat comparison preview.
