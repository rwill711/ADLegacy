# ADLegacy → FFT Mod: Design Crosswalk

This document maps your existing ADLegacy Unity/React game design to FFT modding equivalents.

---

## Job System Mapping

Your ADLegacy jobs can map directly to FFT's existing jobs:

| ADLegacy Job | FFT Equivalent | Notes |
|--------------|----------------|-------|
| Knight | Knight | Direct match |
| Rogue | Thief | Similar role |
| Archer | Archer | Direct match |
| White Mage | White Mage | Direct match |
| Dark Mage | Black Mage | Offensive magic |
| Paladin | Knight/Monk hybrid | Use Knight with Holy abilities |
| Dark Knight | Dark Knight (WotL) | Available in WotL |
| Warrior | Knight | Heavy damage focus |
| Ranger | Archer | Tweak for agility |
| Ninja | Ninja | Direct match |
| Dragoon | Dragoon | Direct match |

**Approach:** Keep FFT jobs as-is. Your job balance work from Unity can inform any stat tweaks in FFTPatcher.

---

## Terrain Type Mapping

Your GridTile terrain types → FFT map tiles:

| ADLegacy Terrain | FFT Equivalent | Movement Cost |
|------------------|----------------|---------------|
| Grass | Natural Surface | 1 |
| Stone | Wooden Floor/Stone | 1 |
| Forest | Natural Surface (trees) | 1.5 (mod via ENTD) |
| Mountain | Obstructed | 2+ |
| Water | Shallow Water | 2 (or impassable) |
| DeepWater | Deep Water | Impassable |
| Lava | Lava (via effect tiles) | Damage on entry |
| Fire | Effect tile | Damage on entry |
| Void | No tile | Impassable |

**In GaneshaDx:** Set tile types and properties to match your terrain costs.

---

## Combat Formula Comparison

Your ADLegacy formulas are already FFTA-inspired:

**ADLegacy (from SkillData.cs):**
```
Physical: (Attack * PowerMultiplier) - Defense
Magical: (Magic * PowerMultiplier) - Resistance
Hit%: BaseAccuracy + (SpeedDiff/2) - Evasion
```

**FFT Native:**
```
Physical: PA * WP + modifier
Magical: MA * spell power
Evasion: C-Ev + S-Ev + A-Ev + Mantle
```

**Implication:** FFT's formulas are more complex. If keeping vanilla FFT abilities, no changes needed. Your formulas serve as balance reference.

---

## Status Effect Mapping

| ADLegacy Status | FFT Status | Notes |
|-----------------|------------|-------|
| Poison | Poison | Damage over time |
| Burn | - | No direct FFT equivalent |
| Slow | Slow | Speed reduction |
| Haste | Haste | Speed boost |
| Sleep | Sleep | Skip turns |
| Stun | Stop | Skip turns (Stop is stronger) |
| Blind | Blind | Accuracy reduction |
| Protect | Protect | Physical defense up |
| Shell | Shell | Magic defense up |
| Regen | Regen | HP over time |
| Doom | Death Sentence | Countdown to death |

**Approach:** Use FFT's existing status effects. They're more numerous than your list.

---

## Battle Manager → FFT Events

Your BattleManager.cs phases map to FFT event structure:

| ADLegacy Phase | FFT Equivalent |
|----------------|----------------|
| Setup | Pre-battle event + ENTD formation |
| BattleStart | Battle event (initial dialogue) |
| PlayerTurn | Engine-handled |
| EnemyTurn | Engine-handled |
| Victory | Post-battle event (victory) |
| Defeat | Post-battle event (defeat) |

**ENTD (Event-based NPC and Territory Data):** Controls unit placement, jobs, levels, equipment.

---

## Turn System Comparison

| ADLegacy | FFT |
|----------|-----|
| Speed-based ordering | CT (Charge Time) based |
| Team-based option | Not native |
| Extra turns (Haste) | Haste increases CT gain |
| Turn skipping | Stop/Sleep/Stone stops CT |

FFT's CT system is more granular. Units with higher speed act more frequently.

---

## Grid System Comparison

| Feature | ADLegacy | FFT |
|---------|----------|-----|
| Grid size | 12x12 default | Varies by map |
| Height levels | Simplified | 0-255 (detailed) |
| Tile properties | 9 types | Multiple flags |
| Pathfinding | A* | Engine-native |

**GaneshaDx** gives you height control per vertex. FFT maps have more vertical complexity.

---

## Animation Assets → Sprite Usage

Your Skeleton Warrior animation assets:
- **Idle:** 18 frames
- **Jump:** 6 frames
- **Attack:** 12 frames

**FFT Sprite Format:**
- Specific frame layout required
- 256 color palette
- Fixed dimensions per animation type

**Recommendation:** For initial mod, use FFT's existing sprites. Your Skeleton Warrior could potentially be converted, but requires careful reformatting to FFT's sprite sheet format using Shishi.

---

## Reusable Design Documents

| Your Document | Use For |
|---------------|---------|
| `SCRIPTS_README.md` | Balance reference, formula checking |
| `UNITY_SETUP_GUIDE.md` | Camera angle reference for map design |
| Job data in `index.html` | Job stat balance reference |
| Skill data patterns | Ability balance reference |

---

## What Transfers Directly

1. **Story/Theme** - Your narrative vision, character concepts
2. **Battle Designs** - Enemy compositions, terrain ideas
3. **Balance Philosophy** - Job progression, skill utility
4. **UI/UX Lessons** - What worked in your React prototype

## What Requires Translation

1. **Code → Event Scripts** - C# logic → EVSP scripting
2. **Procedural Maps → Handcrafted Maps** - GaneshaDx manual editing
3. **Programmatic AI → FFT AI** - Use FFT's AI system

---

## Quick Reference: Your Code Locations

| ADLegacy Asset | Location |
|----------------|----------|
| Job definitions | `Assets/Scripts/Jobs/JobData.cs` |
| Skill system | `Assets/Scripts/Skills/SkillData.cs` |
| Combat formulas | `Assets/Scripts/Core/BattleManager.cs` |
| Status effects | `Assets/Scripts/Units/Unit.cs` |
| Terrain types | `Assets/Scripts/Grid/GridTile.cs` |
| Web game jobs | `index.html` (17+ job objects) |
