# ADLegacy - Final Fantasy Tactics Mod Project

A total conversion mod for **Final Fantasy Tactics: The War of the Lions** (PC - "The Ivalice Chronicles") that replaces maps and events while preserving the core job/ability system.

---

## Project Goals

- **Replace:** All maps, story events, and battles with original ADLegacy content
- **Preserve:** Jobs, abilities, items, and core gameplay mechanics
- **Leverage:** Existing ADLegacy game design from Unity/React prototypes

---

## Getting Started with FFT Modding

### Step 1: Obtain the Game

You need a legal copy of one of these versions:
- **FFT: The Ivalice Chronicles** (PC/Steam) - Recommended for this project
- **FFT: War of the Lions** (PSP ISO) - Most mature modding support
- **FFT** (PSX ISO) - Classic version, extensive tool support

### Step 2: Download Essential Tools

All tools available from [FFHacktics Wiki - Tools](https://ffhacktics.com/wiki/Tools)

| Tool | Purpose | Download |
|------|---------|----------|
| **FFTPatcher** | Edit jobs, abilities, items, stats, formations | FFHacktics |
| **GaneshaDx** | 3D Map editor | [GitHub](https://github.com/Garmichael/GaneshaDx) |
| **EVSP (EasyVent Editor)** | Event scripting and cutscenes | FFHacktics |
| **Shishi** | Sprite and portrait editor | FFHacktics |
| **FFTText** | Dialogue and text editing | FFHacktics |
| **FFTorgASM** | Assembly hacks and patches | FFHacktics |
| **cdmage/cdprog** | ISO extraction/rebuilding (PSX/PSP) | Various |

### Step 3: Extract Game Files

**For PC (The Ivalice Chronicles):**
```
1. Locate game installation folder
2. Use appropriate unpacker tool for TIC format
3. Extract to working directory
```

**For PSP (War of the Lions):**
```
1. Obtain your legally owned ISO
2. Use cdmage or similar to extract
3. Work with extracted files, rebuild when testing
```

### Step 4: Backup Everything

```
/backups/
  ├── original_iso_backup.iso
  ├── fftpatcher_original.fftpatch
  └── original_events/
```

**CRITICAL:** Always keep untouched originals. Modding corrupts files regularly.

---

## Tool Deep Dives

### FFTPatcher - The Core Editor

FFTPatcher edits the game's core data tables:

**What You CAN Edit:**
- Job stats, stat growth, innate abilities
- Ability names, descriptions, effects, MP costs
- Item stats, prices, who can equip
- Monster stats and abilities
- Skillsets and which jobs learn what
- Formation data (starting positions)
- Status effects and their properties
- Weapon/armor formulas

**Workflow:**
1. Open your game file/ISO in FFTPatcher
2. Make edits across tabs (Abilities, Jobs, Items, etc.)
3. Export as `.fftpatch` file (save your work!)
4. Apply patch to game files
5. Test in emulator/game

### GaneshaDx - Map Editor

The 3D map editor for creating custom battlefields.

**Capabilities:**
- Edit existing map geometry (terrain, heights)
- Modify textures and UV mapping
- Adjust lighting and palette
- Set tile properties (walkable, water, etc.)
- Export/import map data

**Limitations:**
- Steep learning curve
- No "create from scratch" - must modify existing maps
- Polygon/vertex count limits per map
- Texture memory constraints

### EVSP - Event Editor

Controls cutscenes, dialogue, unit placement, and story flow.

**What Events Control:**
- Pre-battle and post-battle cutscenes
- Character dialogue and positioning
- Camera movements and angles
- Unit spawning and formations
- Battle conditions (win/lose triggers)
- Story branching

**Event Types:**
- **Story Events:** Cutscenes between battles
- **Battle Events:** In-battle triggers and dialogue
- **World Map Events:** Location unlocks, encounters

### Shishi - Sprite Editor

Handles character visuals:
- Unit sprites (battle animations)
- Portraits (dialogue faces)
- Formation sprites
- Effect sprites

---

## Project Folder Structure

```
FFT-Mod/
├── docs/                    # Documentation and design notes
├── tools/                   # Downloaded modding tools
├── assets/
│   ├── maps/               # Custom map files (GaneshaDx exports)
│   ├── sprites/            # Character sprite sheets
│   ├── portraits/          # Character portraits
│   └── effects/            # Spell/ability effects
├── data/
│   ├── jobs/               # Job modification notes
│   ├── abilities/          # Ability balance sheets
│   ├── items/              # Item data
│   └── formations/         # Battle unit placements
├── events/
│   ├── story/              # Story event scripts
│   ├── battles/            # Battle event configs
│   └── cutscenes/          # Cutscene scripts
├── audio/                  # Music and sound replacements
├── patches/                # Exported .fftpatch files
├── reference/              # Original game data for reference
└── exports/                # Built mod packages
```

---

## Modding Scope & Limitations

### What You CAN Do (Realistic Goals)

| Category | Possibility | Difficulty |
|----------|-------------|------------|
| **Replace all story events** | Yes | Medium-High |
| **Replace all dialogue/text** | Yes | Low-Medium |
| **Create new battle maps** | Yes (modify existing) | High |
| **Change map textures** | Yes | Medium |
| **New battle formations** | Yes | Low |
| **Rebalance jobs/abilities** | Yes | Low |
| **Rename everything** | Yes | Low |
| **New character portraits** | Yes | Medium |
| **Custom unit sprites** | Yes | High |
| **New music** | Yes | Medium |
| **World map changes** | Limited | Very High |

### What You CANNOT Do (Engine Limitations)

| Limitation | Reason |
|------------|--------|
| **Add new jobs beyond slots** | Hardcoded job count |
| **Add new abilities beyond slots** | Fixed ability table size |
| **New map from scratch** | Must modify existing map geometry |
| **Change core battle mechanics** | Requires ASM hacking |
| **New animation types** | Animation system is fixed |
| **Expand polygon counts** | Memory/rendering limits |
| **New status effects** | Fixed status effect slots |
| **Change grid size (map)** | Engine limitation |

### Gray Area (Possible with ASM Hacks)

These require assembly-level modifications:
- New formulas for damage/healing
- Additional equipment slots
- Modified stat caps
- Custom AI behaviors
- Expanded text limits

---

## Recommended Workflow for ADLegacy Mod

### Phase 1: Story & Event Planning
1. Map out complete story beats
2. Design all battles (terrain type, enemy composition)
3. Write all dialogue scripts
4. Reference: `reference/` folder with original event dumps

### Phase 2: Event Implementation
1. Use EVSP to create story events
2. Set up battle events with win/lose conditions
3. Test event flow in emulator
4. Store in: `events/story/`, `events/battles/`

### Phase 3: Map Modification
1. Identify base maps closest to your vision
2. Use GaneshaDx to modify geometry
3. Apply new textures
4. Test walkability and pathfinding
5. Store in: `assets/maps/`

### Phase 4: Visual Assets
1. Create character portraits
2. Modify sprites if needed (use existing job sprites where possible)
3. Store in: `assets/sprites/`, `assets/portraits/`

### Phase 5: Data Tuning (Optional)
1. If rebalancing: Use FFTPatcher
2. Rename jobs/abilities to fit theme (if desired)
3. Export patches to: `patches/`

### Phase 6: Integration & Testing
1. Apply all patches to clean game copy
2. Playtest entire mod
3. Build final package to: `exports/`

---

## Resources & Community

### Primary Resources
- [FFHacktics](https://ffhacktics.com/smf/index.php) - Main modding community
- [FFHacktics Wiki](https://ffhacktics.com/wiki/Tools) - Tool documentation
- [GaneshaDx GitHub](https://github.com/Garmichael/GaneshaDx) - Map editor source
- [Romhacking.net FFT](https://www.romhacking.net/games/1707/) - Patches and hacks

### Tutorials
- [FFHacktics Tutorials](https://ffhacktics.com/tutorials.php) - Official tutorial collection
- EVSP event scripting guides on FFHacktics wiki
- GaneshaDx usage guides on GitHub

### Completed Mods (Reference)
- **The Lion War** - Considered definitive FFT mod
- **War of the Lions Tweak** - Quality of life improvements
- Browse [Completed Mods](https://ffhacktics.com/smf/index.php?board=53.0) for inspiration

### PC Version Notes
The PC version (The Ivalice Chronicles) has:
- Growing tool support (less mature than PSP)
- File format differences from PSP/PSX
- Active development on compatibility tools
- Check [Steam Discussions](https://steamcommunity.com/app/1004640/discussions/0/594027788789503504/) for latest

---

## Leveraging Existing ADLegacy Code

Your Unity/React prototypes contain valuable design work:

| Existing Asset | Mod Application |
|----------------|-----------------|
| Job definitions (17+ jobs) | Reference for rebalancing/theming |
| Skill data & formulas | Balance reference |
| Battle system design | Event battle design |
| Terrain types & costs | Map design reference |
| Status effects | Ability effect planning |
| Story/theme concepts | Event script writing |

**Location:** See `../Assets/Scripts/` and `../Documentation/`

---

## Quick Reference Commands

### Testing Workflow
```bash
# 1. Work in tools (FFTPatcher, GaneshaDx, EVSP)
# 2. Export patches
# 3. Apply to clean ISO/game files
# 4. Test in emulator (PPSSPP for PSP) or game
# 5. Iterate
```

### Backup Commands
```bash
# Before major changes
cp game.iso backups/game_$(date +%Y%m%d).iso
```

---

## Project Status

- [ ] Tool setup complete
- [ ] Original game files extracted
- [ ] Story outline finalized
- [ ] Battle list defined
- [ ] Event scripts written
- [ ] Maps modified
- [ ] Portraits created
- [ ] Full playtest complete
- [ ] Release package built

---

*This mod is a fan project. Final Fantasy Tactics is property of Square Enix.*
