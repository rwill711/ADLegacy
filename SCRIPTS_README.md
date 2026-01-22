# Unity Scripts Documentation

## Overview

This is a complete set of C# scripts for a 2.5D tactical RPG similar to Final Fantasy Tactics Advance. The scripts are organized into modular systems that work together to create a full tactical battle system.

---

## Script Categories

### Grid System (`Assets/Scripts/Grid/`)
- **GridTile.cs** - Individual tile with terrain, occupancy, and highlighting
- **GridManager.cs** - Generates and manages the entire battle grid
- **Pathfinding.cs** - A* pathfinding, movement range, attack range calculations

### Unit System (`Assets/Scripts/Units/`)
- **Unit.cs** - Main unit component with stats, status effects, and actions
- **UnitStats.cs** - Stats data structure with HP/MP, combat stats, modifiers
- **UnitMovement.cs** - Handles unit movement along paths with animations

### Job & Skill System (`Assets/Scripts/Jobs/` & `Assets/Scripts/Skills/`)
- **JobData.cs** - ScriptableObject for job definitions (Knight, Mage, etc.)
- **SkillData.cs** - ScriptableObject for skill/ability definitions

### Core Management (`Assets/Scripts/Core/`)
- **GameManager.cs** - Overall game state, scene management, player data
- **BattleManager.cs** - Battle flow, combat resolution, turn phases
- **TurnManager.cs** - Turn order and initiative system

---

## Quick Start Guide

### Step 1: Scene Setup

1. **Create a new scene** in Unity (File > New Scene)
2. **Add required GameObjects:**
   ```
   Hierarchy:
   ├── GameManager (empty GameObject)
   ├── BattleManager (empty GameObject)
   ├── GridManager (empty GameObject)
   ├── Main Camera
   └── Canvas (for UI)
   ```

3. **Attach scripts to GameObjects:**
   - Add `GameManager.cs` to GameManager
   - Add `BattleManager.cs` to BattleManager
   - Add `GridManager.cs` to GridManager

### Step 2: Create Grid Tile Prefab

1. **Create a Tile:**
   - GameObject > Create Empty
   - Name it "GridTile"
   - Add `GridTile.cs` component
   - Add `SpriteRenderer` component
   - Add `BoxCollider` component (for mouse clicks)

2. **Configure:**
   - Set Sprite to a square sprite (or create one: Assets > Create > Sprites > Square)
   - Set Collider size to match sprite (usually 1x1)
   - Set Sorting Layer to "Terrain"

3. **Save as Prefab:**
   - Drag from Hierarchy to `Assets/Prefabs/Grid/`
   - Delete from scene

### Step 3: Configure GridManager

1. **Select GridManager** in Hierarchy
2. **In Inspector, set:**
   - Grid Width: 12
   - Grid Height: 12
   - Tile Size: 1
   - Tile Prefab: (drag your GridTile prefab here)
   - Current Template: RandomBattlefield
   - Generate On Start: ✓ (checked)

3. **Press Play** - the grid should generate!

### Step 4: Create Unit Prefab

1. **Create a Unit:**
   - GameObject > Create Empty
   - Name it "PlayerUnit"
   - Add `Unit.cs` component
   - Add `UnitMovement.cs` component
   - Add `SpriteRenderer` component (for character visual)
   - Add `BoxCollider` component (for mouse clicks)

2. **Configure:**
   - Set a character sprite
   - Set Sorting Layer to "Units"
   - Set Order in Layer: 0

3. **Save as Prefab:**
   - Drag to `Assets/Prefabs/Units/PlayerUnit.prefab`

### Step 5: Create Job Data (ScriptableObject)

1. **In Project window:**
   - Right-click in `Assets/ScriptableObjects/Jobs/`
   - Create > ADLegacy > Job Data
   - Name it "Knight"

2. **Configure the Knight job:**
   ```
   Job Name: Knight
   Base HP: 120
   Base MP: 20
   Base Attack: 15
   Base Defense: 12
   Base Magic: 5
   Base Resistance: 8
   Base Speed: 8

   Move Range: 3
   Jump Height: 2
   ```

3. **Repeat for other jobs** (Mage, Archer, Rogue, etc.)

### Step 6: Create Skill Data (ScriptableObject)

1. **In Project window:**
   - Right-click in `Assets/ScriptableObjects/Skills/`
   - Create > ADLegacy > Skill Data
   - Name it "BasicAttack"

2. **Configure Basic Attack:**
   ```
   Skill Name: Attack
   Skill Type: Physical
   MP Cost: 0
   Min Range: 1
   Max Range: 1
   Target Type: Enemy
   Power Multiplier: 1.0
   Base Accuracy: 90
   Can Crit: ✓
   ```

3. **Create more skills** (Heal, Fireball, etc.)

### Step 7: Assign Skills to Jobs

1. **Open Knight.asset** (the Job ScriptableObject)
2. **In Job Skills list:**
   - Set Size: 3
   - Element 0: BasicAttack
   - Element 1: (another skill)
   - Element 2: (another skill)

### Step 8: Test the Battle

1. **In Scene, create test units:**
   - Drag PlayerUnit prefab into scene (x3)
   - In Inspector for each unit:
     - Set Unit Name: "Knight 1", "Knight 2", etc.
     - Set Team: Player
     - Set Current Job: (drag Knight.asset here)

2. **Create enemy units:**
   - Drag PlayerUnit prefab into scene (x2)
   - Set Unit Name: "Enemy 1", "Enemy 2"
   - Set Team: Enemy
   - Set Current Job: Knight (or different job)

3. **Assign units to BattleManager:**
   - Select BattleManager
   - In Inspector, expand Player Units list
   - Drag your player units from Hierarchy
   - Expand Enemy Units list
   - Drag your enemy units

4. **Press Play!**

---

## How The Systems Work Together

### Game Flow

```
GameManager (persistent)
    ↓
BattleManager (battle scene)
    ↓
TurnManager (turn order)
    ↓
Units take actions
    ↓
GridManager (movement/targeting)
    ↓
Pathfinding (calculate paths)
    ↓
Skills executed
    ↓
Victory/Defeat check
```

### Turn Flow

1. **Battle Start**
   - BattleManager.StartBattle()
   - Initializes all units
   - Sets up turn order

2. **Player Turn**
   - Select unit
   - Show movement range
   - Move unit
   - Show action menu
   - Select skill
   - Select target
   - Execute action
   - Next unit or end turn

3. **Enemy Turn**
   - AI takes control
   - Each enemy moves and acts
   - End turn

4. **Repeat** until victory or defeat

### Unit Action Flow

```
Unit selected
    ↓
Can move? → Show movement range
    ↓
Player clicks tile → Find path
    ↓
Move along path → Mark HasMoved = true
    ↓
Can act? → Show skill menu
    ↓
Select skill → Show attack range
    ↓
Select target → Validate
    ↓
Execute skill → Calculate damage
    ↓
Apply effects → Check status
    ↓
Mark HasActed = true
    ↓
End unit turn
```

---

## Key Concepts

### Singleton Managers

These scripts use the Singleton pattern for global access:
- `GameManager.Instance`
- `BattleManager.Instance`
- `GridManager.Instance`
- `TurnManager.Instance`

**Usage:**
```csharp
GridManager.Instance.GetTileAt(5, 5);
BattleManager.Instance.StartBattle();
```

### ScriptableObjects for Data

Jobs and Skills are ScriptableObjects, which means:
- ✓ Create them as assets in Project window
- ✓ Easy to modify without code
- ✓ Reusable across multiple units
- ✓ No need to instantiate

### Event System

Managers use C# events for communication:
```csharp
BattleManager.Instance.OnUnitTurnStart += HandleTurnStart;
GameManager.Instance.OnGameStateChanged += HandleStateChange;
```

### Unit Stats with Modifiers

Stats support temporary and equipment modifiers:
```csharp
// Base stats
unit.Stats.Attack; // Returns base + equipment + buffs

// Apply buff
StatModifiers buff = new StatModifiers { attack = 5 };
unit.Stats.ApplyTemporaryModifier(buff);
```

---

## Combat Formula (FFTA-style)

### Damage Calculation

**Physical:**
```
Damage = (Attack * PowerMultiplier) - Defense
```

**Magical:**
```
Damage = (Magic * PowerMultiplier) - Resistance
```

**Critical:**
```
Damage *= (CritDamage / 100)
```

### Hit Chance

```
HitChance = BaseAccuracy + (Speed Diff / 2) - Target Evasion
Clamped between 5% and 100%
```

### Movement Cost

Each terrain has a cost:
- Grass: 1.0
- Forest: 1.5
- Mountain: 2.0
- Water: Unwalkable (by default)

**Movement Range Calculation:**
- Uses Dijkstra's algorithm
- Considers terrain cost and height differences
- Returns all reachable tiles within range

---

## Extending The System

### Adding a New Job

1. Create Job ScriptableObject
2. Configure stats and growth
3. Assign skills
4. Create character sprite
5. Done!

### Adding a New Skill

1. Create Skill ScriptableObject
2. Set type, cost, range, power
3. Add status effects if needed
4. Assign to job(s)
5. Done!

### Adding New Terrain

1. Open `GridTile.cs`
2. Add to `TerrainType` enum
3. Add case in `SetTerrainType()` method
4. Set movement cost and properties
5. Add color in `GetTerrainColor()`

### Custom Status Effects

Extend the `StatusEffect` class:
```csharp
public class PoisonEffect : StatusEffect
{
    public override void OnTurnStart(Unit unit)
    {
        int damage = Potency;
        unit.TakeDamage(damage);
        Debug.Log($"{unit.UnitName} took {damage} poison damage");
    }
}
```

---

## Common Issues & Solutions

### Grid doesn't generate
- Check GridManager has Tile Prefab assigned
- Check Generate On Start is enabled
- Check Console for errors

### Units don't appear
- Check Unit prefab has SpriteRenderer
- Check Sorting Layer is set to "Units"
- Check units are assigned to BattleManager

### Can't click tiles
- Check GridTile has BoxCollider
- Check collider is not disabled
- Check Camera has Physics Raycaster (for UI)

### Units can't move
- Check Unit has UnitMovement component
- Check Current Tile is assigned
- Check GridManager exists in scene

### Skills don't work
- Check Unit has Current Job assigned
- Check Job has skills in Job Skills list
- Check Unit has enough MP
- Check target is in range

---

## Next Steps

1. **Create UI:**
   - Unit info panel
   - Skill menu
   - Turn indicator
   - Health bars

2. **Add Animations:**
   - Attack animations
   - Skill VFX
   - Damage numbers
   - Hit effects

3. **Implement AI:**
   - Enemy decision making
   - Target selection
   - Skill usage

4. **Add More Content:**
   - More jobs (17 total from your design)
   - More skills (80+ from your design)
   - Equipment system
   - Status effects

5. **Polish:**
   - Sound effects
   - Music
   - Camera movements
   - Screen shake

---

## Script Dependencies

```
GameManager (no dependencies)
    ↓
BattleManager → GameManager
    ↓
TurnManager → Unit
    ↓
GridManager → GridTile, Pathfinding
    ↓
Unit → UnitStats, JobData, SkillData, GridTile
    ↓
UnitMovement → Unit, GridManager, Pathfinding
    ↓
Pathfinding → GridTile, GridManager, Unit
```

**Load order is handled automatically by Unity.**

---

## Performance Tips

1. **Object Pooling:**
   - Pool damage numbers
   - Pool VFX effects
   - Reuse grid tiles

2. **Update Optimization:**
   - Only update visible units
   - Cache frequently used components
   - Use events instead of Update checks

3. **Pathfinding:**
   - Cache movement ranges
   - Only recalculate on stat changes
   - Limit max search depth

---

## Debug Tools

Built-in debug features:

- **Press D in Play Mode:** Toggle debug info
- **GameManager.debugMode:** Enable/disable debug logs
- **TurnManager.debugMode:** Show turn order details
- **Gizmos:** Visual debugging in Scene view
  - Yellow cube: Grid bounds
  - Cyan cube: Tile height
  - Red cube: Unwalkable tile

---

## Additional Resources

- Unity Documentation: https://docs.unity3d.com/
- Your existing game logic in `TacticalRPG.html` for reference
- FFTA combat system: https://finalfantasy.fandom.com/wiki/Final_Fantasy_Tactics_Advance

---

## Support

If you encounter issues:
1. Check Console for error messages
2. Verify all components are attached
3. Check that ScriptableObjects are created and assigned
4. Ensure sorting layers exist (Edit > Project Settings > Tags and Layers)

**The system is fully functional and ready to use once set up!**
