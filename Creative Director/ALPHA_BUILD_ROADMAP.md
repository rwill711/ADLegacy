# Adventure Legacy — Alpha Build Roadmap
### Creative Director | RBW Studios
---

## Vision Statement
The Alpha Build is a **functional proof-of-concept** — no art, no polish, just *does the game work and does it feel right?* By the end of Alpha, we should be able to place units on a grid, move them, fight with them, rotate the camera FFTA-style, and see the FOIL system influencing enemy behavior in real time. If a player can make meaningful tactical choices on a bare-bones board and feel the tension of positioning, facing, and turn order — Alpha is a success.

---

## Prerequisites (Complete Before Alpha Work Begins)
- [x] FOIL System — Chunks 1–3 (enums, action record, battle record, profile, tracker)
- [ ] FOIL System — Chunk 4: `foil_analyzer.gd` *(scheduled: tomorrow)*
- [ ] FOIL System — Chunk 5: `foil_loadout_builder.gd` *(scheduled: tomorrow)*
- [ ] FOIL System — Chunk 6: Integration notes & log update *(scheduled: tomorrow)*

> **Once FOIL is wrapped, Alpha begins.**

---

## Alpha Build Pillars

| # | Pillar | What It Proves |
|---|--------|---------------|
| 1 | **Grid & Terrain** | The world exists and has rules |
| 2 | **Units & Jobs** | Characters are distinct and functional |
| 3 | **Turn System & Movement** | Players make meaningful choices |
| 4 | **Battle System** | Combat has depth, actions resolve correctly |
| 5 | **Camera System** | Player can read the battlefield (FFTA-style rotation) |
| 6 | **End Game Conditions** | A battle can be won or lost — there's stakes |
| 7 | **Debug System** | We can see under the hood and iterate fast |

---

## Phase 1 — The Board (Grid & Camera)
*If the stage isn't built, nobody can perform.*

### 1A: Isometric Grid Tile System
- Tile-based grid map — isometric 2.5D presentation
- Tiles should be data-driven: each tile holds properties (type, elevation, walkable, occupant)
- Support for **elevation differences** (even if just 2–3 height levels for Alpha)
- Minimal texture set: flat color-coded tiles (e.g., grey = ground, blue = water/impassable, brown = elevated)
- Tile highlighting for movement range, attack range, and selection
- Grid coordinate system that all other systems reference (movement, targeting, pathfinding)
- **Stretch:** Basic terrain cost differences (normal, rough/slow, impassable)

### 1B: Camera System (FFTA-Style)
- Isometric camera with **4-point rotation** (90° snaps: NE, SE, SW, NW) — exactly like FFTA
- Rotation input: shoulder buttons / Q+E / designated keys
- Camera should re-sort or re-render tile/unit draw order correctly after each rotation
- Zoom in / zoom out (bounded, not infinite)
- Camera tracks the active/selected unit during their turn
- Smooth transition between rotation positions (short tween, not instant snap — keeps the tactical "readability" feel)

---

## Phase 2 — The Pieces (Units & Jobs)
*Three jobs. Three distinct play-feels. That's enough to prove the system.*

### General Unit Framework
- Every unit shares a base: HP, MP, Speed, Move range, Jump tolerance, Attack, Defense, Resistance, facing direction
- Facing direction is **set at end of turn** — player chooses which of 4 cardinal directions to face before confirming end of turn
- Facing matters: attacks from behind deal bonus damage (or have higher hit%), attacks from the side are normal, frontal attacks may have reduced effectiveness
- Units are represented by **placeholder capsules/primitives with a colored arrow or indicator showing facing direction**
- Unit turn order driven by Speed stat (CTR/tick system like FFTA, or simpler initiative queue — **Tech Director to decide on implementation**)

### Alpha Roster: 3 Jobs

#### Rogue
- **Role:** Fast, fragile, positional — rewards flanking and facing exploitation
- **Stats:** High Speed, high Move range, low HP, moderate Attack, low Defense
- **Alpha Abilities:**
  - `Attack` — Basic melee, 1 range
  - `Backstab` — Bonus damage when attacking from behind the target's facing
  - `Steal` — Attempt to take an item/consumable from an enemy (even if inventory is basic for Alpha, prove the mechanic)
- **Move Range:** 5 tiles
- **Jump:** 2 (can handle moderate elevation)

#### Squire
- **Role:** Balanced frontliner, the "tutorial" job — straightforward and reliable
- **Stats:** Balanced across the board, moderate HP/Attack/Defense/Speed
- **Alpha Abilities:**
  - `Attack` — Basic melee, 1 range
  - `First Aid` — Small self-heal (HP recovery)
  - `Stone Throw` — Ranged attack, 3 range, low damage (gives ranged option)
- **Move Range:** 4 tiles
- **Jump:** 3 (solid vertical mobility)

#### White Mage
- **Role:** Backline healer/support — proves magic and targeting allies works
- **Stats:** High MP, high Resistance, low Attack, low Defense, low Speed
- **Alpha Abilities:**
  - `Attack` — Basic melee, 1 range (staff bonk — weak but it exists)
  - `Cure` — Single target heal, 4 range, targets allies
  - `Protect` — Buff that raises target's Defense for X turns, 4 range, targets allies
- **Move Range:** 3 tiles
- **Jump:** 1 (fragile, not mobile — positioning matters)

> **Note to Programming Lead:** Abilities need a shared structure — name, type (damage/heal/buff/debuff/steal), range, area of effect, element (future), MP cost, target type (enemy/ally/self/tile). Build for extensibility even though Alpha only has 3 jobs. Every skill we add later should just be data, not new code.

---

## Phase 3 — The Rules (Turn System, Movement, & Battle)
*This is the heartbeat. If the turn loop doesn't feel right, nothing else matters.*

### 3A: Turn System
- **Turn order** based on Speed stat (CTR countdown or initiative queue)
- Each unit's turn consists of: **Move → Act → Face → End Turn** (in that order, any can be skipped)
  - Move: Select a tile within movement range. Pathfinding respects elevation/jump and terrain.
  - Act: Use an ability (attack, skill, item — item system can be stubbed for Alpha)
  - Face: **Choose which direction to face before ending the turn.** 4 cardinal directions. This is non-negotiable for Alpha — it's core to the tactics feel.
  - End Turn: Confirm. Unit is done. Next unit in turn order activates.
- Player can Act before Move or Move before Act (flexible order, just like FFTA)
- **Wait** option: Skip remaining actions and end turn immediately (still must choose facing)
- Display turn order queue on screen (even just a text list for Alpha — who's next matters to the player)

### 3B: Movement & Pathfinding
- A* pathfinding on the grid, accounting for:
  - Tile walkability
  - Elevation and unit's Jump stat
  - Occupied tiles (can't walk through enemies; allies TBD — **Creative call: for Alpha, units cannot pass through any other unit**)
- Highlight reachable tiles when unit is selected to move
- Movement animates unit across path tile-by-tile (even at placeholder level — don't teleport, it kills readability)

### 3C: Battle / Action Resolution
- Ability use: select ability → show valid targets/range → select target → resolve
- Damage formula (starting point, subject to tuning):
  - `Physical Damage = Attack × Ability Power − Target Defense` (with facing modifier)
  - `Magic Damage = Magic Attack × Ability Power − Target Resistance`
  - Facing modifiers: Rear = 1.5x, Side = 1.0x, Front = 0.75x *(tuning values — not final)*
- Healing formula: `Heal = Magic Attack × Ability Power` (no resistance reduction)
- Hit chance: keep it simple for Alpha — **most things hit at 100%** unless targeting through facing (rear attacks always hit, front attacks could have a miss chance). **Open question — Tech Director weigh in on whether we want hit/miss in Alpha or save it.**
- Display damage numbers on screen (floating text, even basic)
- HP bars visible on units at all times

---

## Phase 4 — End Game Conditions
*A battle without stakes is just moving pieces around a board.*

### Win Conditions (Alpha)
- **Defeat All Enemies** — default. All enemy units HP ≤ 0 → Victory.
- *(Stretch)* **Defeat Target** — one specific enemy is the objective. Others are optional.

### Lose Conditions (Alpha)
- **All Player Units Defeated** — all player units HP ≤ 0 → Defeat.

### On Victory:
- Display "Victory" screen (text is fine)
- *( Stretch)* Show basic battle summary: turns taken, damage dealt, abilities used
- FOIL hook: `FOILTracker.commit_battle()` fires here — this battle's data enters the rolling window

### On Defeat:
- Display "Defeat" screen (text is fine)
- FOIL hook: still commit the battle data — losses inform the profile too

> **Open Question:** Do we want a "Retry" option in Alpha, or is it quit-to-menu? For testing purposes, retry is probably more useful. Flag for Producer.

---

## Phase 5 — Debug System
*We are building a living game. The debugger has to grow with it.*

### Core Philosophy
The debug system must be **modular and extensible**. It's not a one-off — every new system we build should be able to register its own debug panel/output. Build it as a framework, not a fixed tool.

### Alpha Debug Features

#### Debug Overlay (Toggle On/Off — single key, maybe F1 or backtick)
- **Tile Inspector:** Click any tile → shows tile data (coordinates, elevation, terrain type, occupant, walkable)
- **Unit Inspector:** Click any unit → shows full stat block (HP, MP, ATK, DEF, SPD, etc.), current facing, FOIL profile summary, status effects
- **Turn Order Display:** Full queue visible with CTR/initiative values
- **Grid Coordinate Overlay:** Toggle to show coordinates on every tile

#### Debug Console / Command System
- In-game console (toggle with backtick or designated key)
- Command structure that new systems can register commands into. Examples for Alpha:
  - `heal [unit] [amount]` — heal a unit
  - `damage [unit] [amount]` — deal damage to a unit
  - `kill [unit]` — instantly defeat a unit
  - `set_hp [unit] [value]` — set exact HP
  - `spawn [job] [team] [tile_x] [tile_y]` — spawn a unit at location
  - `foil_level [0-4]` — force FOIL level override for next battle
  - `foil_profile` — dump current character's FOIL profile to console
  - `win` — trigger win condition
  - `lose` — trigger lose condition
  - `move [unit] [tile_x] [tile_y]` — teleport unit to tile
  - `next_turn` — skip to next unit's turn

#### Debug Log
- Persistent scrollable log capturing all game events: damage dealt, heals, ability usage, turn changes, FOIL data commits
- Filterable by category (combat, movement, FOIL, system)
- Exportable to text file for review

#### Extensibility Contract
- Any new system (equipment, elements, legacy, AI behavior) should be able to:
  1. Register new debug commands via a simple API
  2. Add a new debug panel/tab to the overlay
  3. Push entries to the debug log with a category tag
- **Note to Programming Lead:** Build a `DebugManager` autoload singleton that other systems register with. Don't hardcode any system-specific logic into the debugger itself.

---

## Phase 6 — FOIL Integration (Post-Foundation)
*FOIL is already built (or will be by tomorrow). This phase wires it into the Alpha systems.*

- Hook `FOILTracker.begin_battle()` into battle start
- Hook `FOILTracker.record_action()` into every player ability use
- Hook `FOILTracker.commit_battle()` into end-game resolution (win or lose)
- Use `FOILAnalyzer.build_profile()` during battle setup to inform enemy loadout
- Use `FOILLoadoutBuilder.build_enemy_team()` to adjust enemy jobs/gear/consumables based on FOIL level
- Debug panel should display FOIL profile, current FOIL level, archetype weights, and trait tags
- For Alpha, FOIL levels 0–2 are the target. Levels 3–4 need AI behavior and equipment systems that are post-Alpha.

---

## Scope & Constraints

| In Scope (Alpha) | Out of Scope (Alpha) |
|---|---|
| 3 jobs (Rogue, Squire, White Mage) | Full job system / job switching |
| Placeholder capsule units with facing indicators | Character art, sprites, animations |
| Color-coded flat tiles with elevation | Detailed terrain art, environment art |
| Basic damage/heal/buff abilities | Element system, status effects, terrain interaction |
| FFTA-style camera rotation | Cinematic camera, cutscenes |
| Win/Lose conditions | Story, quests, narrative, world map |
| FOIL levels 0–2 functional | FOIL levels 3–4 (need AI/equipment systems) |
| Debug overlay + console + log | Save/Load system (beyond FOIL's built-in serialization) |
| Single battle map (flat + a few elevation changes) | Multiple maps, map editor, procedural gen |
| Facing direction at end of turn | Reaction abilities, counter-attacks (future) |
| Basic turn order queue | Complex initiative manipulation abilities |

---

## Suggested Build Order

| Priority | System | Depends On | Owner |
|----------|--------|-----------|-------|
| 🔴 1 | Grid Tile System (data + rendering) | Nothing | Programming Lead |
| 🔴 2 | Camera System (FFTA rotation) | Grid | Programming Lead |
| 🔴 3 | Unit Base Class + 3 Jobs | Grid (for placement) | Programming Lead + Creative Director (stat review) |
| 🔴 4 | Turn System (turn order, move/act/face/end loop) | Grid + Units | Programming Lead |
| 🔴 5 | Movement + Pathfinding | Grid + Turn System | Programming Lead |
| 🔴 6 | Battle / Ability Resolution | Units + Turn System | Programming Lead |
| 🔴 7 | End Game Conditions | Battle System | Programming Lead |
| 🟡 8 | Debug System (overlay, console, log) | All above (to inspect them) | Programming Lead |
| 🟡 9 | FOIL Integration Hooks | FOIL System + Battle System | Programming Lead |
| 🟢 10 | Tuning Pass (damage values, move ranges, speed, facing modifiers) | Everything functional | Creative Director + QA Lead |

> 🔴 = Critical Path | 🟡 = High Priority | 🟢 = Polish / Balance

---

## Open Questions for the Team

1. **Turn order system:** CTR countdown (like FFTA) or simple initiative queue? — *Tech Director call, impacts complexity.*
2. **Hit/Miss in Alpha?** Or do all attacks land and we add accuracy later? — *Creative leans toward all-hit for Alpha to reduce RNG frustration during testing, but open to discussion.*
3. **Unit passthrough:** Can allies walk through each other? — *Creative ruling for Alpha: No. All units block movement. Keeps positioning meaningful.*
4. **Retry on defeat?** — *Useful for testing. Producer to confirm.*
5. **Alpha test map:** How big? — *Suggestion: 12×12 grid with a small hill (3-tile raised area) in the center. Enough to test elevation + positioning without being overwhelming.*
6. **Party size for Alpha battles?** — *Suggestion: 3v3. One of each job on player side. Enemy composition driven by FOIL level.*

---

## Success Criteria
Alpha is **done** when:
- [ ] A player can start a battle on a grid map
- [ ] Camera rotates in 4 directions, FFTA-style
- [ ] 3 units per side, each with distinct jobs (Rogue, Squire, White Mage)
- [ ] Units take turns based on speed
- [ ] Units can move, use an ability, choose facing, and end their turn
- [ ] Damage, healing, and buffs resolve correctly with facing modifiers
- [ ] A battle can be won or lost
- [ ] FOIL system records player actions and influences enemy setup
- [ ] Debug tools allow inspection of all systems
- [ ] A tester can play 3 consecutive battles and see FOIL adaptation shift enemy loadouts

---

*"The Alpha doesn't need to be pretty. It needs to be true. If the tactics feel right on a grey grid with colored capsules — the game works."*

— Creative Director, RBW Studios
