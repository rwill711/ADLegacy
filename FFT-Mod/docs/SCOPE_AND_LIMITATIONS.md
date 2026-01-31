# FFT Modding: Scope & Limitations Analysis

This document provides a realistic assessment of what can and cannot be achieved when modding Final Fantasy Tactics for your ADLegacy total conversion.

---

## Your Goals Assessment

| Goal | Feasibility | Notes |
|------|-------------|-------|
| Replace all maps | **Achievable** | Modify existing maps, not create new geometry from scratch |
| Replace all events | **Achievable** | Full control via EVSP |
| Keep all jobs | **Easy** | No changes needed, or rename to fit theme |
| Keep all skills | **Easy** | No changes needed, or rename to fit theme |
| New story | **Achievable** | Event system is flexible |
| New characters | **Achievable** | Portraits + event scripting |

**Verdict:** Your vision is realistic and achievable with the existing toolset.

---

## Detailed Breakdown by System

### 1. MAPS - What You Can Do

**Full Control:**
- Change terrain heights (hills, valleys, cliffs)
- Modify tile textures (grass to stone, etc.)
- Adjust lighting and color palettes
- Change tile properties (walkable, water, lava, etc.)
- Reposition starting locations

**Modifications Required:**
- You must start from an existing map as a base
- Choose maps with similar layout to your vision
- GaneshaDx can reshape geometry significantly

**Practical Approach:**
```
Original Map          →  Your Vision
Mandalia Plains       →  Rolling farmlands
Sweegy Woods          →  Dense forest dungeon
Zirekile Falls        →  Waterfall sanctuary
Golgorand Execution   →  Town square/plaza
Orbonne Monastery     →  Temple interior
Riovanes Castle       →  Fortress/keep
```

**Limits:**
- Total polygon/vertex count per map is capped
- Texture memory is limited (palette swapping helps)
- Map dimensions are fixed by base map
- No vertical map stacking (single-layer maps)

---

### 2. EVENTS - Full Creative Control

**You Control Everything:**
- All dialogue text
- Character positioning on screen
- Camera angles and movements
- When units spawn/despawn
- Facial expressions (portrait changes)
- Battle start/end conditions
- Branching choices (limited)
- World map unlocks

**Event Structure:**
```
Story Event → Pre-Battle Event → BATTLE → Post-Battle Event → Next Story Event
```

**What EVSP Lets You Do:**
- Write custom dialogue for any character
- Create new cutscene choreography
- Set up complex multi-part battles
- Control reinforcement spawns
- Trigger weather/visual effects
- Play music cues

**Example Event Script Concept:**
```
EVENT: Chapter 1 - The Awakening

[Fade in on village map]
[Camera pan across burning buildings]
PROTAGONIST: "No... this can't be happening."
[Enter ALLY from stage right]
ALLY: "We have to move! They're coming!"
[Transition to battle]
```

---

### 3. JOBS & ABILITIES - Keep or Retheme

**Option A: Keep Everything**
- Use FFT's 20+ jobs as-is
- All abilities function identically
- Familiar to FFT players

**Option B: Retheme (Rename Only)**
- Change job names (Squire → Recruit)
- Change ability names (Throw Stone → Hurl Debris)
- Same mechanics, different flavor

**Option C: Rebalance (Careful)**
- Adjust MP costs
- Modify damage formulas
- Change stat growth
- Risk: Breaking game balance

**Fixed Limits:**
- Cannot add new job slots (22 generic + special)
- Cannot add new ability slots (~512 total)
- Cannot create fundamentally new mechanics
- Animation types are fixed

---

### 4. UNITS & CHARACTERS

**Full Control:**
- Character names
- Character portraits (custom art)
- Starting stats and jobs
- Which battles they appear in
- Their dialogue

**Sprite Options:**
- Use existing FFT sprites (easiest)
- Palette swap existing sprites (medium)
- Create custom sprites (hard, time-consuming)

**Special Characters:**
- Can repurpose special character slots
- Ramza → Your protagonist
- Delita → Your rival/ally
- etc.

---

### 5. BATTLES

**Customizable:**
- Which map to use
- Starting positions for all units
- Enemy composition (jobs, levels, equipment)
- Win/lose conditions
- Reinforcement triggers
- Pre/post battle events
- Battle dialogue

**Example Battle Setup:**
```
BATTLE: Forest Ambush
- Map: Sweegy Woods (modified)
- Player Units: 4 slots
- Enemies: 3 Archers (trees), 2 Knights (ground), 1 Black Mage
- Win: Defeat all enemies
- Special: Reinforcements after turn 3
```

---

### 6. WORLD MAP

**Can Modify:**
- Location names
- Which locations unlock when
- Random battle encounters
- Dot positions (limited)

**Cannot Modify Easily:**
- World map image itself (possible but complex)
- Add new location dots beyond existing
- Change traversal mechanics

**Workaround:** The world map is mostly flavor. Focus on battle-to-battle flow rather than overworld exploration.

---

## Technical Constraints Summary

### Hard Engine Limits

| System | Limit |
|--------|-------|
| Generic Jobs | 22 slots |
| Special Jobs | ~20 slots |
| Abilities | ~512 slots |
| Items | ~256 slots |
| Maps | Must modify existing |
| Sprites per unit | Fixed animation frames |
| Text per dialogue box | Character limit per line |
| Status effects | 40 slots (fixed) |
| Battle participants | 16 units max on field |

### Memory Constraints

- Total sprite memory per battle
- Texture memory per map
- Event script size limits
- Audio file sizes

---

## Recommended Scope for ADLegacy

### Realistic First Release

**Include:**
1. Complete new story (10-15 story battles)
2. Modified maps for each battle location
3. Custom character portraits for main cast (5-8 characters)
4. Fully rewritten dialogue
5. Rethemed job names (optional)

**Defer to Later:**
- Custom unit sprites
- Music replacement
- Ability rebalancing
- Extensive side content

### Development Timeline Estimate

| Phase | Content |
|-------|---------|
| **Phase 1** | Story outline + battle list + dialogue drafts |
| **Phase 2** | Learn tools (FFTPatcher, EVSP, GaneshaDx) |
| **Phase 3** | Implement events for Chapter 1 |
| **Phase 4** | Modify maps for Chapter 1 |
| **Phase 5** | Playtest Chapter 1 |
| **Phase 6** | Iterate, then continue to remaining chapters |

---

## Comparison: Mod vs. Original Game Development

| Aspect | FFT Mod | Unity From Scratch |
|--------|---------|-------------------|
| Battle system | Ready (FFT engine) | Must build |
| Job/ability system | Ready (400+ abilities) | Must design |
| AI | Ready (FFT AI) | Must program |
| Pathfinding | Ready | Must implement |
| UI | Ready | Must design |
| Maps | Modify existing | Create any |
| Story | Full control | Full control |
| Flexibility | Constrained by engine | Unlimited |
| Time to playable | Faster | Longer |
| Learning curve | Tool-specific | Programming |

**Verdict for ADLegacy:** Modding FFT gets you to a playable, polished tactical RPG faster, but with engine constraints. Your Unity codebase remains valuable for a future "no limits" version.

---

## Next Steps

1. **Download tools** from FFHacktics
2. **Extract your game files** (PC or PSP version)
3. **Study one completed mod** (like The Lion War) to understand structure
4. **Start with events** - write your story in EVSP
5. **Modify one map** as a proof of concept
6. **Iterate** from there

---

## References

- [FFHacktics Tools Wiki](https://ffhacktics.com/wiki/Tools)
- [GaneshaDx GitHub](https://github.com/Garmichael/GaneshaDx)
- [FFHacktics Tutorials](https://ffhacktics.com/tutorials.php)
- [Completed Mods Gallery](https://ffhacktics.com/smf/index.php?board=53.0)
