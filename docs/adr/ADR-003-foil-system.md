# ADR-003: FOIL System — Adaptive CPU Opponent Intelligence

## Status: APPROVED

## Context
ADLegacy needs a CPU adaptation system that makes enemies progressively counter the player's habits. Called "FOIL" — the CPU becomes the foil to your playstyle. This is the game's core balancing mechanic.

## Decision

### FOIL Levels (0–4)
| Level | Label | CPU Behavior |
|---|---|---|
| 0 | Oblivious | Random/default loadouts, no adaptation |
| 1 | Aware | CPU uses consumables to mitigate player's dominant approach |
| 2 | Prepared | CPU selects jobs/skills that counter player patterns |
| 3 | Strategic | CPU adjusts AI behavior (targeting, positioning, formation) |
| 4 | Mastery | Hard-counter gear, optimized compositions, exploits weaknesses |

### FOIL Level Drivers
- **Free/endless battles**: FOIL level scales with accumulated renown
- **Story battles**: Mission data specifies FOIL level directly (override)
- Story overrides can go higher OR lower than renown would suggest

### Tracking Model
- **Per-character primary**: Each player character builds their own FOIL profile based on actions taken
- **Party archetype secondary**: At higher renown, the party composition itself gets an archetype label that influences CPU team-building
- **Rolling window**: Last 10–12 battles are actively weighted. Older data is dropped from the window but permanent trait tags persist (see below)

### Trait Tags
- Characters accumulate permanent trait tags through gameplay (e.g., "Master Swordsman", "Pyromancer")
- Trait tags contribute archetype signals to FOIL even outside the rolling window (e.g., "Master Swordsman" → always flags "melee_range_fighter")
- Tags come from: titles earned, job mastery, skill usage milestones, story choices
- Tags persist on the character. On death, tags are lost unless inherited via legacy

### Legacy & Death
- Character death resets renown (partially — legacy characters may inherit bonus renown)
- The rolling window resets with the character (new character, fresh battle history)
- Trait tags are lost unless passed through legacy inheritance
- Player-level patterns are NOT tracked — each character earns their own FOIL profile

### Element/Terrain Interaction
- NOT in scope for FOIL v1. Element system and terrain interactions will be built separately
- Future FOIL levels (v2+) may incorporate terrain-awareness (e.g., avoid water vs lightning user)

## Architecture

### Subsystems
1. **FOILTracker** (Autoload) — Records every player action per battle, manages rolling window
2. **FOILAnalyzer** (Static/utility) — Reads tracker data + trait tags → produces FOILProfile
3. **FOILLoadoutBuilder** (Battle setup) — Consumes FOILProfile + FOIL level → builds enemy team

### Data Flow
```
Player takes action → FOILTracker.record_action()
                          ↓
Battle ends → FOILTracker.commit_battle() → pushes to rolling window, trims to 10-12
                          ↓
Next battle setup → FOILAnalyzer.build_profile(tracker_data, trait_tags) → FOILProfile
                          ↓
FOILLoadoutBuilder.build_enemy_team(profile, foil_level, enemy_pool) → configured enemies
```

### File Structure
```
scripts/foil/foil_enums.gd            [implemented]
scripts/foil/foil_action_record.gd    [implemented]
scripts/foil/foil_battle_record.gd    [implemented]
scripts/foil/foil_profile.gd          [implemented]
scripts/foil/foil_tracker.gd          [implemented]
scripts/foil/foil_analyzer.gd         [implemented]
scripts/foil/foil_loadout_builder.gd  [implemented]
```

FOIL v1 is code-complete. Consumer integration (BattleManager hooks, EnemySpawner
translation of symbolic hints → JobData/ItemData) is pending those systems being
ported to GDScript. See `Technical Director/Technical Log.txt` Session 3 entry
for the full pipeline, the EnemySpawner contract, and tuning-knob locations.

## Risks
- Overtightening: If FOIL counters too aggressively, player feels punished for having a build. Tuning knobs needed per level.
- Data sparsity: Early battles have few records. Analyzer must handle thin data gracefully (default to level 0 behavior).
- Trait tag inflation: Need clear criteria for tag assignment or everything becomes tagged.

## Open for Future
- Terrain-aware FOIL (v2)
- CPU legacy characters that inherit FOIL data from defeated player characters
- Vendetta system (Creative Log mentions NPCs with grudges — FOIL level boost on those encounters)
