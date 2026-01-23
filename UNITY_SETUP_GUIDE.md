# Unity 2.5D Setup Guide for FFTA-Style Tactical RPG

## Project Overview
This guide will help you set up Unity 6000.1.2f1 for a 2.5D tactical RPG similar to Final Fantasy Tactics Advance, porting your existing web-based game to Unity.

---

## Part 1: Initial Unity Project Setup

### Step 1: Create New Project
1. Open Unity Hub
2. Click "New Project"
3. Select **2D (URP)** template (Universal Render Pipeline)
   - URP is optimized for 2D/2.5D games and offers better performance
   - Provides modern rendering features for effects and lighting
4. Name: `ADLegacy` (or your preferred name)
5. Location: Choose your preferred directory
6. Unity Version: 6000.1.2f1
7. Click "Create Project"

### Step 2: Configure Project Settings

Once Unity opens, configure these critical settings:

#### Graphics Settings
1. **Edit > Project Settings > Graphics**
   - Verify URP is the active pipeline
   - This gives you better sprite sorting and lighting

#### Quality Settings
1. **Edit > Project Settings > Quality**
   - Set default quality level to "Medium" or "High"
   - Anti Aliasing: 2x or 4x Multi Sampling
   - Texture Quality: Full Res

#### Physics Settings
1. **Edit > Project Settings > Physics**
   - Disable Auto Simulation (we'll control physics manually for tactical gameplay)

#### Time Settings
1. **Edit > Project Settings > Time**
   - Keep default (we'll use Time.timeScale for game speed control)

---

## Part 2: Package Installation

### Essential Packages

Open **Window > Package Manager** and install:

1. **2D Sprite** (should be pre-installed)
   - For sprite rendering and management

2. **2D Tilemap Editor** (Install if not present)
   - For building grid-based maps
   - Essential for tactical grid layout

3. **Cinemachine** (Recommended)
   - Advanced camera control
   - Smooth camera transitions
   - Camera shake for combat effects
   - Install from Package Manager

4. **TextMeshPro** (Should auto-import on first text creation)
   - Better text rendering than legacy UI Text
   - Essential for stats, damage numbers, UI

### Optional but Recommended

5. **Universal RP** (should be installed via template)
   - Modern rendering pipeline
   - Better 2D lighting

6. **Input System** (New Input System)
   - More flexible than old input manager
   - Better for complex control schemes
   - Install from Package Manager
   - When prompted, select "Yes" to enable new input system

---

## Part 3: Project Folder Structure

Create this folder structure in your `Assets` folder:

```
Assets/
├── Scenes/
│   ├── MainMenu.unity
│   ├── BattleScene.unity
│   └── TeamSetup.unity
│
├── Scripts/
│   ├── Core/
│   │   ├── GameManager.cs
│   │   ├── BattleManager.cs
│   │   └── TurnManager.cs
│   │
│   ├── Grid/
│   │   ├── GridManager.cs
│   │   ├── GridTile.cs
│   │   └── Pathfinding.cs
│   │
│   ├── Units/
│   │   ├── Unit.cs
│   │   ├── UnitStats.cs
│   │   ├── UnitMovement.cs
│   │   └── UnitAnimator.cs
│   │
│   ├── Jobs/
│   │   ├── JobData.cs (ScriptableObject)
│   │   └── JobManager.cs
│   │
│   ├── Skills/
│   │   ├── SkillData.cs (ScriptableObject)
│   │   └── SkillExecutor.cs
│   │
│   ├── AI/
│   │   ├── EnemyAI.cs
│   │   └── AIBehavior.cs
│   │
│   ├── UI/
│   │   ├── BattleUI.cs
│   │   ├── UnitInfoPanel.cs
│   │   └── SkillMenu.cs
│   │
│   └── Data/
│       ├── SaveData.cs
│       └── GameData.cs
│
├── Prefabs/
│   ├── Units/
│   │   ├── PlayerUnit.prefab
│   │   └── EnemyUnit.prefab
│   │
│   ├── Grid/
│   │   └── GridTile.prefab
│   │
│   ├── UI/
│   │   ├── DamageNumber.prefab
│   │   └── StatusIcon.prefab
│   │
│   └── VFX/
│       ├── HitEffect.prefab
│       └── SkillEffect.prefab
│
├── Sprites/
│   ├── Characters/
│   │   ├── Knight/
│   │   ├── Mage/
│   │   └── Archer/
│   │
│   ├── Tiles/
│   │   ├── Grass.png
│   │   ├── Stone.png
│   │   └── Water.png
│   │
│   ├── UI/
│   │   └── Icons/
│   │
│   └── VFX/
│       └── Effects/
│
├── ScriptableObjects/
│   ├── Jobs/
│   │   ├── Knight.asset
│   │   ├── Mage.asset
│   │   └── ...
│   │
│   └── Skills/
│       ├── Attack.asset
│       ├── Heal.asset
│       └── ...
│
├── Materials/
│   ├── SpriteMaterial.mat
│   └── GridMaterial.mat
│
├── Audio/
│   ├── Music/
│   ├── SFX/
│   │   ├── Combat/
│   │   └── UI/
│   └── Ambience/
│
└── Resources/
    └── (Runtime-loaded assets)
```

---

## Part 4: Camera Setup for 2.5D FFTA Style

### Camera Configuration

1. **Select Main Camera** in Hierarchy
2. **Camera Component Settings:**
   ```
   Projection: Orthographic (NOT Perspective)
   Size: 5-8 (adjust based on grid visibility)
   Position: X=0, Y=8-12, Z=-10
   Rotation: X=30-45, Y=0, Z=0
   ```

3. **Recommended Settings for FFTA-style:**
   - **Rotation: X=35, Y=0, Z=0** (Dimetric/Isometric angle)
   - **Size: 6** (shows ~12x12 tile grid)
   - This creates the classic tactical RPG angled view

### Advanced Camera (with Cinemachine)

If you installed Cinemachine:

1. **GameObject > Cinemachine > Virtual Camera**
2. Name it "BattleCam"
3. Set **Body** to "Framing Transposer"
4. Configure:
   ```
   Lookahead Time: 0.1-0.3
   Damping: 1.0-2.0 (smooth movement)
   Screen X/Y: 0.5 (centered)
   Dead Zone: 0.1
   ```

5. This allows smooth camera following of selected units

---

## Part 5: Grid System Setup

### Option A: Using 3D Grid (Recommended for FFTA style)

**Why 3D Grid?**
- Better height/elevation control
- Easier pathfinding with obstacles
- More flexible for terrain variety
- Sprites render on 3D positions with proper layering

**Setup:**

1. Create empty GameObject: "GridManager"
2. Add component: Grid
3. Grid Settings:
   ```
   Cell Size: X=1, Y=0.5, Z=1 (isometric feel)
   Cell Gap: 0
   Cell Layout: Rectangle
   Cell Swizzle: XYZ
   ```

4. **Create Tile Prefab:**
   - Create empty GameObject: "GridTile"
   - Add SpriteRenderer (for tile visual)
   - Add BoxCollider (for raycasting/selection)
   - Add custom GridTile.cs script (we'll create later)
   - Save as Prefab

### Option B: Using Tilemap (Alternative)

1. **GameObject > 2D Object > Tilemap > Rectangular**
2. This creates:
   - Grid (parent)
   - Tilemap (child)

3. **Window > 2D > Tile Palette**
4. Create tile assets and paint directly

**Note:** Option A gives you more control for tactical grid mechanics

---

## Part 6: Sprite Configuration for 2.5D

### Sprite Import Settings

When importing character/tile sprites:

1. **Select sprite in Project window**
2. **Inspector Settings:**
   ```
   Texture Type: Sprite (2D and UI)
   Sprite Mode: Multiple (if sprite sheet) or Single
   Pixels Per Unit: 32-64 (FFTA uses ~32-48)
   Mesh Type: Tight (for non-rectangular sprites)
   Filter Mode: Point (no filter) for pixel art, or Bilinear for smooth
   Compression: None (for pixel-perfect) or Low Quality Compression
   ```

3. **Click Apply**

### Sprite Renderer Settings (on GameObjects)

For character units:

1. **Add SpriteRenderer component**
2. Configure:
   ```
   Sprite: (your character sprite)
   Color: White
   Flip: As needed
   Sorting Layer: "Units" (create this)
   Order in Layer: Based on Y position (lower Y = higher number)
   ```

3. **Sorting Layers** (Edit > Project Settings > Tags and Layers > Sorting Layers):
   ```
   0: Background
   1: Terrain
   2: Objects
   3: Units
   4: Effects
   5: UI
   ```

---

## Part 7: Render Pipeline Configuration (URP)

### URP Asset Settings

1. **Find URP Asset** in `Assets/Settings/`
2. **Select UniversalRenderPipelineAsset**
3. **Configure for 2D:**
   ```
   Rendering:
   - Renderer: UniversalRenderer
   - Depth Texture: OFF (not needed for 2D)
   - Opaque Texture: OFF

   Quality:
   - HDR: OFF (not needed)
   - Anti Aliasing (MSAA): 4x
   - Render Scale: 1.0

   Lighting:
   - Main Light: ON (optional for effects)
   - Additional Lights: OFF (performance)
   - Cast Shadows: OFF (2D doesn't need)

   Shadows:
   - Disabled (not needed for 2D)

   Post-processing:
   - Enabled (for screen effects)
   ```

4. **Assign to Project:**
   - Edit > Project Settings > Graphics
   - Scriptable Render Pipeline Settings: (your URP asset)

---

## Part 8: Scene Setup

### Create Battle Scene

1. **File > New Scene**
2. Save as `BattleScene.unity`
3. **Scene Hierarchy:**
   ```
   BattleScene
   ├── Main Camera (configured as above)
   ├── GridManager (with Grid component)
   ├── GameManager (empty GameObject with scripts)
   ├── BattleManager (empty GameObject with scripts)
   ├── Canvas (UI - more below)
   └── EventSystem
   ```

### UI Canvas Setup

1. **GameObject > UI > Canvas**
2. **Canvas Settings:**
   ```
   Render Mode: Screen Space - Overlay
   Canvas Scaler:
   - UI Scale Mode: Scale With Screen Size
   - Reference Resolution: 1920x1080
   - Match: 0.5 (balance width/height)
   ```

3. **Add UI Elements:**
   ```
   Canvas
   ├── BattleUI
   │   ├── UnitInfoPanel (top-left)
   │   ├── SkillMenu (bottom-right)
   │   ├── TurnIndicator (top-center)
   │   └── MessageLog (bottom-left)
   │
   └── DamageNumbers (pooled, spawned dynamically)
   ```

---

## Part 9: Input Setup

### Using New Input System (Recommended)

1. **Create Input Actions Asset:**
   - Right-click in Project: Create > Input Actions
   - Name: "GameControls"
   - Double-click to open

2. **Define Action Maps:**

**Action Map: "Battle"**
```
Actions:
- Click (Mouse > Left Button)
- RightClick (Mouse > Right Button)
- MousePosition (Mouse > Position)
- Cancel (Keyboard > Escape)
- Confirm (Keyboard > Enter/Space)
- RotateCamera (Keyboard > Q/E)
```

**Action Map: "UI"**
```
Actions:
- Navigate (Keyboard > WASD/Arrows)
- Submit (Keyboard > Enter)
- Cancel (Keyboard > Escape)
```

3. **Generate C# Class:**
   - Check "Generate C# Class"
   - Click "Apply"
   - This creates `GameControls.cs`

4. **Usage in scripts:**
```csharp
private GameControls controls;

void Awake()
{
    controls = new GameControls();
    controls.Battle.Click.performed += ctx => OnClick();
}

void OnEnable() => controls.Enable();
void OnDisable() => controls.Disable();
```

---

## Part 10: Essential Initial Scripts

I'll create these core scripts for you to get started:

### 1. GridTile.cs
Handles individual tile data and visuals

### 2. GridManager.cs
Manages the entire grid, tile creation, and pathfinding

### 3. Unit.cs
Base unit class with stats and state

### 4. GameManager.cs
Overall game state management

Would you like me to create these initial script templates now?

---

## Part 11: Recommended Workflow

### Development Order:

1. **Phase 1: Grid Foundation**
   - Create grid generation system
   - Implement tile selection/highlighting
   - Basic camera control

2. **Phase 2: Unit Basics**
   - Unit placement on grid
   - Unit selection
   - Basic movement (no pathfinding yet)

3. **Phase 3: Movement System**
   - Implement pathfinding (A* or BFS)
   - Movement range calculation
   - Movement animation

4. **Phase 4: Combat Core**
   - Basic attack system
   - Damage calculation
   - Turn management

5. **Phase 5: Job System**
   - ScriptableObject-based job data
   - Skill system
   - Job switching

6. **Phase 6: Polish**
   - VFX and animations
   - UI refinement
   - Audio integration

---

## Part 12: Art Style Recommendations for FFTA

### Visual Guidelines:

1. **Sprites:**
   - 32x32 or 48x48 pixel character sprites
   - 4-8 directional facing (FFTA uses 4: N, S, E, W)
   - Idle, Walk, Attack, Cast, Hit, Death animations
   - 4-8 frames per animation

2. **Tiles:**
   - 32x32 or 64x64 base size
   - Simple, readable designs
   - Clear differentiation (grass, stone, water, etc.)

3. **Color Palette:**
   - Vibrant, saturated colors (FFTA style)
   - High contrast for readability
   - Pastel backgrounds, punchy character colors

4. **Effects:**
   - Sprite-based VFX (not particle systems initially)
   - Frame-by-frame attack effects
   - Simple hit flashes and screen shake

### Placeholder Art (to start):

- Use Unity's built-in sprites (squares, circles)
- Color-code units by team (blue = player, red = enemy)
- Use colored tiles for terrain types
- Replace with final art incrementally

---

## Part 13: Performance Optimization Tips

1. **Sprite Atlasing:**
   - Group sprites into atlases
   - Reduces draw calls significantly
   - Enable in Sprite Packer (Edit > Project Settings > Editor)

2. **Object Pooling:**
   - Pool damage numbers, VFX, projectiles
   - Reuse GameObjects instead of Instantiate/Destroy

3. **Batching:**
   - Keep sprites on same atlas/material
   - Static batching for grid tiles
   - Dynamic batching for units (automatic in URP)

4. **Culling:**
   - Only render visible tiles/units
   - Disable SpriteRenderers for off-screen objects

---

## Next Steps

After completing this setup:

1. I'll create the core grid system scripts
2. We'll implement unit placement and selection
3. Port your job/skill data to ScriptableObjects
4. Build the combat system with your existing formulas
5. Create the UI system
6. Add animations and polish

**Let me know when you've completed the Unity project creation and I'll start generating the core scripts!**

---

## Quick Reference Checklist

- [ ] Create new 2D (URP) project in Unity
- [ ] Install packages (Cinemachine, TextMeshPro, Input System)
- [ ] Set up folder structure
- [ ] Configure camera (Orthographic, angled view)
- [ ] Create Grid Manager GameObject
- [ ] Set up Sorting Layers
- [ ] Configure URP settings
- [ ] Create Battle Scene
- [ ] Set up Canvas with UI Scale
- [ ] Create Input Actions asset
- [ ] Ready for scripting!

---

**Questions?** Let me know if you need clarification on any step, or if you'd like me to create the initial scripts while you set up Unity!
