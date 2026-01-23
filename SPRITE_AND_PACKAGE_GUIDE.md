# Sprite and Unity Package Guide

## Overview

You've added **Skeleton Warrior** sprites and a Unity package! This guide will walk you through importing and using these assets in your tactical RPG.

**What You Have:**
- `Skeleton_Warrior.unitypackage` - Pre-configured Unity asset package
- **Idle/** folder - 18 animation frames for idle animation
- **Jump Loop/** folder - 6 animation frames for jumping
- **Slashing in The Air/** folder - 12 animation frames for attack animation

---

## Option 1: Import the Unity Package (Easiest)

The `.unitypackage` file has everything pre-configured. This is the fastest way!

### Step 1: Import the Package

1. **In Unity**, go to **Assets > Import Package > Custom Package...**
2. **Navigate to** where you saved `Skeleton_Warrior.unitypackage`
3. **Select it** and click **Open**
4. **A window appears** showing all the package contents
5. **Click "Import"** (bottom right) to import everything

### Step 2: Find the Imported Assets

After importing, look in your **Project window**:
- The assets will be in a new folder (likely `Assets/SkeletonWarrior/` or similar)
- You should see:
  - Sprites folder
  - Animations folder
  - Prefab (possibly)
  - Animator Controller (possibly)

### Step 3: Use the Prefab

If there's a prefab included:
1. **Find the Skeleton Warrior prefab** in the imported folder
2. **Drag it into your scene** to test it
3. **Press Play** to see if animations work automatically
4. **If animations work**, you can use this as a template for your units!

---

## Option 2: Manually Import Sprites (More Control)

If you want to set everything up yourself or the package doesn't work, follow this method.

### Step 1: Copy Sprite Files to Unity

1. **In Windows Explorer**, navigate to where you saved the sprite folders:
   - `Idle/`
   - `Jump Loop/`
   - `Slashing in The Air/`

2. **In Unity Project window**, navigate to:
   - `Assets/Sprites/Characters/SkeletonWarrior/`
   - *(Create this folder structure if it doesn't exist)*

3. **Drag all three folders** from Windows Explorer into Unity's `SkeletonWarrior/` folder
   - Unity will import them automatically

### Step 2: Configure Sprite Import Settings

For each sprite folder:

1. **Select ALL sprites** in the Idle folder (click first, shift+click last)
2. **In Inspector**, configure:
   ```
   Texture Type: Sprite (2D and UI)
   Sprite Mode: Single
   Pixels Per Unit: 32-64 (match your game's scale)
   Filter Mode: Point (no filter) - for pixel art
                OR Bilinear - for smooth sprites
   Compression: None (best quality)
   Max Size: 2048 (or higher if needed)
   ```
3. **Click Apply** at the bottom of Inspector
4. **Repeat for Jump Loop and Slashing folders**

### Step 3: Create Animation Clips

Now let's turn these sprite sequences into animations!

#### Create Idle Animation:

1. **Window > Animation > Animation** (opens Animation window)
2. **In Hierarchy**, select your **PlayerUnit** prefab (or create a test GameObject)
3. **In Animation window**, click **Create**
4. **Save as**: `Assets/Animations/SkeletonWarrior/Idle.anim`
5. **In Animation window**:
   - You should see a timeline
   - Click **Add Property > Sprite Renderer > Sprite**
6. **Select all Idle sprite frames** in Project window
7. **Drag them into the Animation timeline** (they'll auto-space)
8. **Set Sample Rate**: 12 (12 frames per second, adjustable)
9. **Click the loop toggle** (circular arrow) to make it loop

#### Create Jump Animation:

1. **In Animation window**, click the **animation dropdown** (top left, says "Idle")
2. **Click "Create New Clip"**
3. **Save as**: `Assets/Animations/SkeletonWarrior/Jump.anim`
4. **Drag all Jump Loop sprites** into timeline
5. **Set to loop**

#### Create Attack Animation:

1. **Create New Clip** again
2. **Save as**: `Assets/Animations/SkeletonWarrior/Attack.anim`
3. **Drag all Slashing sprites** into timeline
4. **DO NOT loop** (attacks play once)

### Step 4: Set Up Animator Controller

Unity should have created an Animator Controller automatically. If not:

1. **Right-click** in Project: **Create > Animator Controller**
2. **Name it**: `SkeletonWarriorAnimator`
3. **Double-click** to open Animator window
4. **Drag your animation clips** (Idle, Jump, Attack) into the Animator window
5. **Right-click Idle** > **Set as Layer Default State** (orange)
6. **Create transitions:**
   - Right-click **Idle** > **Make Transition** > Click **Attack**
   - Right-click **Attack** > **Make Transition** > Click **Idle**
   - Right-click **Idle** > **Make Transition** > Click **Jump**
   - Right-click **Jump** > **Make Transition** > Click **Idle**

### Step 5: Add Parameters for Transitions

1. **In Animator window**, find **Parameters** tab (left side)
2. **Click the + button** > **Trigger**
3. **Name it**: `Attack`
4. **Add another Trigger**: `Jump`
5. **Add a Bool**: `IsMoving`

### Step 6: Configure Transitions

For each transition:

1. **Click the transition arrow** between states
2. **In Inspector**, under **Conditions**:
   - Idle → Attack: Add condition `Attack` (trigger)
   - Attack → Idle: No condition needed (set "Has Exit Time" to checked)
   - Idle → Jump: Add condition `Jump` (trigger)
   - Jump → Idle: No condition (set "Has Exit Time")

3. **Set Transition Duration**: 0 (instant transitions for snappy gameplay)

### Step 7: Apply to Your Unit Prefab

1. **Select your PlayerUnit prefab**
2. **Add Component** > **Animator** (if not already there)
3. **In Animator component**:
   - Set **Controller** to `SkeletonWarriorAnimator`
4. **Press Play** - Idle animation should play automatically!

---

## Option 3: Using Sprites with Your Tactical RPG Scripts

Now let's integrate these with your Unit scripts!

### Method 1: Apply to Existing Unit Prefab

1. **Open your PlayerUnit prefab** (from earlier setup)
2. **Find the SpriteRenderer component**
3. **Set Sprite** to the first Idle frame: `0_Skeleton_Warrior_Idle_000`
4. **Add Animator component** (if not added)
5. **Assign Animator Controller**: `SkeletonWarriorAnimator`
6. **Your unit now has animations!**

### Method 2: Create Unit from Scratch with Sprites

1. **GameObject > Create Empty**
2. **Name it**: `SkeletonWarrior`
3. **Add these components:**
   - `Unit.cs`
   - `UnitMovement.cs`
   - `SpriteRenderer`
   - `Animator`
   - `BoxCollider` (for clicking)

4. **Configure SpriteRenderer:**
   - Sprite: First idle frame
   - Sorting Layer: Units
   - Order in Layer: 0

5. **Configure Animator:**
   - Controller: SkeletonWarriorAnimator

6. **Configure BoxCollider:**
   - Size: Adjust to match sprite (maybe 0.8 x 1.2)

7. **Save as Prefab**: Drag to `Assets/Prefabs/Units/SkeletonWarrior.prefab`

---

## Triggering Animations from Scripts

### In UnitMovement.cs

You can trigger animations when the unit moves:

**Add to your UnitMovement script:**

```csharp
private Animator animator;

private void Awake()
{
    animator = GetComponent<Animator>();
}

// In your movement coroutine:
if (animator != null)
{
    animator.SetBool("IsMoving", true);
}

// When movement ends:
if (animator != null)
{
    animator.SetBool("IsMoving", false);
}
```

### For Attack Animation

**In BattleManager when executing a skill:**

```csharp
// Before dealing damage:
Animator casterAnimator = caster.GetComponent<Animator>();
if (casterAnimator != null)
{
    casterAnimator.SetTrigger("Attack");
    yield return new WaitForSeconds(0.5f); // Wait for animation
}

// Then deal damage...
```

---

## Quick Reference: Animation States

**What you should have:**

| Animation | When to Play | Loop? | Trigger |
|-----------|-------------|-------|---------|
| Idle | Default state, not moving | Yes | Automatic |
| Jump | Moving between tiles | Yes | `IsMoving = true` |
| Attack | Using a skill | No | `Attack` trigger |

---

## Advanced: Sprite Flipping for Direction

To flip the sprite when facing left:

**In Unit.cs or UnitMovement.cs:**

```csharp
public void FaceDirection(Vector3 direction)
{
    if (spriteRenderer == null) return;

    if (direction.x < 0)
        spriteRenderer.flipX = true;  // Face left
    else if (direction.x > 0)
        spriteRenderer.flipX = false; // Face right
}
```

---

## Troubleshooting

### Sprites look blurry
- Set **Filter Mode** to **Point (no filter)** in import settings

### Animation plays too fast/slow
- Adjust **Sample Rate** in Animation window (12-24 is typical)

### Animation doesn't loop
- In Animation window, click the **loop toggle** (circular arrows icon)

### Sprite is too big/small
- Adjust **Pixels Per Unit** in import settings
  - Higher number = smaller sprite (64 = half size of 32)
  - Lower number = bigger sprite

### Can't see sprite in scene
- Check **Sorting Layer** is set to "Units" (not Default)
- Check sprite is at correct Y position (above grid)
- Check **Order in Layer** is higher than terrain

### Animations don't trigger
- Check Animator has **Controller** assigned
- Check **Parameters** exist in Animator
- Check script is calling `SetTrigger()` or `SetBool()`

---

## Next Steps

1. **Import the package** or sprites
2. **Test animations** with a test GameObject
3. **Apply to your Unit prefab**
4. **Create different units** by swapping sprite sets
5. **Add more animations** (hit reaction, death, victory, etc.)

You can find more free sprites on:
- **itch.io** (search "pixel art character sprites")
- **OpenGameArt.org**
- **Kenney.nl**

Look for sprite sheets with these animations for tactical RPGs:
- Idle
- Walk/Run
- Attack
- Cast (for magic)
- Hit/Hurt
- Death
- Victory

---

## Tips for FFTA Style

For Final Fantasy Tactics Advance visual style:

1. **Sprite Size**: 32x32 or 48x48 pixels per unit
2. **Color Palette**: Vibrant, saturated colors
3. **Animation Speed**: 8-12 FPS (slower = more retro)
4. **Use Outlines**: Black outlines around sprites for clarity
5. **Height Indicator**: Shadow sprite under character
6. **Team Colors**: Tint sprites slightly (blue for player, red for enemy)

Enjoy your animated tactical RPG! 🎮⚔️
