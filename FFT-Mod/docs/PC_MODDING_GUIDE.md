# FFT: The Ivalice Chronicles (PC/Steam 2025) - Modding Setup Guide

Step-by-step instructions for extracting and modding the PC version.

---

## Prerequisites

Before starting, you need:

1. **FFT: The Ivalice Chronicles** installed via Steam
2. **.NET 8.0 Runtime** - [Download from Microsoft](https://dotnet.microsoft.com/download/dotnet/8.0)
3. **Windows 10/11** with DirectStorage support

---

## Step 1: Locate Your Game Files

Your game is installed at:
```
C:\Program Files (x86)\Steam\steamapps\common\FINAL FANTASY TACTICS - The Ivalice Chronicles\
```

Inside, you'll find:
```
FINAL FANTASY TACTICS - The Ivalice Chronicles/
├── FFTTIC.exe              # Main executable
├── data/
│   ├── enhanced/           # HD remaster assets (what you want)
│   │   ├── 0000.pac        # Packed game files
│   │   ├── 0001.pac
│   │   ├── 0002.pac
│   │   ├── ...
│   │   ├── 0007.en.pac     # English locale pack
│   │   └── ...
│   └── classic/            # Original PSP-style assets
└── ...
```

**The `.pac` files contain all game assets** - maps, sprites, events, data tables, etc.

---

## Step 2: Download FF16Tools

This is the extraction/packing tool for TIC.

1. Go to: https://github.com/Nenkai/FF16Tools/releases
2. Download the latest `FF16Tools.CLI-win-x64.zip`
3. Extract to a convenient location, e.g., `C:\Tools\FF16Tools\`

You should have:
```
C:\Tools\FF16Tools\
├── FF16Tools.CLI.exe
└── (other DLLs)
```

---

## Step 3: Extract Game Files

Open **Command Prompt** or **PowerShell** and run:

```cmd
cd C:\Tools\FF16Tools

FF16Tools.CLI unpack-all-packs -i "C:\Program Files (x86)\Steam\steamapps\common\FINAL FANTASY TACTICS - The Ivalice Chronicles\data\enhanced" -o "C:\FFT_Modding\extracted" -g fft
```

**Breaking down the command:**
- `unpack-all-packs` - Extract all .pac files
- `-i` - Input folder (your game's data/enhanced folder)
- `-o` - Output folder (where extracted files go)
- `-g fft` - **CRITICAL:** Tells the tool this is FFT, not FF16

**This will take a few minutes.** When done, you'll have:

```
C:\FFT_Modding\extracted\
├── fftpack/                # Main game data
│   ├── battle/             # Battle maps and data
│   ├── effect/             # Visual effects
│   ├── event/              # Event scripts!
│   ├── map/                # Map geometry
│   ├── sound/              # Audio
│   └── ...
├── nxd/                    # Database tables
│   ├── ability.nxd         # Ability definitions
│   ├── item.nxd            # Item definitions
│   ├── job.nxd             # Job definitions
│   └── ...
├── system/
│   └── ffto/g2d/           # Textures
└── ui/                     # UI assets
```

---

## Step 4: Examine Key Files

Now you can explore what's inside:

### List contents of a specific pack:
```cmd
FF16Tools.CLI list-files -i "C:\Program Files (x86)\Steam\steamapps\common\FINAL FANTASY TACTICS - The Ivalice Chronicles\data\enhanced\0001.pac" -g fft
```

### Key folders to explore:

| Folder | Contains |
|--------|----------|
| `fftpack/event/` | Event scripts (story, battles) |
| `fftpack/map/` | Map data |
| `fftpack/battle/` | Battle configurations |
| `nxd/` | Data tables (jobs, abilities, items) |
| `system/ffto/g2d/` | Textures |

---

## Step 5: Set Up Mod Loader (For Testing Mods)

To actually load mods into the game:

### 5a. Install Reloaded-II

1. Download from: https://github.com/Reloaded-Project/Reloaded-II/releases
2. Install and run Reloaded-II
3. Click "+" to add a game
4. Browse to `FFTTIC.exe` in your game folder
5. Register the game

### 5b. Install FFTIVC Mod Loader

1. Go to: https://github.com/Nenkai/fftivc.utility.modloader/releases
2. Download the latest `.7z` file
3. Drag and drop the `.7z` directly onto Reloaded-II's left panel
4. It will auto-install

### 5c. Enable the Mod Loader

1. In Reloaded-II, select FFT: TIC
2. Check the box next to "FFTIVC Mod Loader"
3. Launch game through Reloaded-II to test mods

---

## Step 6: Create Your First Mod

### Mod Folder Structure

Create this folder structure:
```
C:\FFT_Modding\mymods\fftivc.story.adlegacy\
└── FFTIVC\
    └── data\
        └── enhanced\
            ├── fftpack\
            │   └── event\        # Your modified events
            ├── nxd\              # Your modified data tables
            └── system\
                └── ffto\g2d\     # Your modified textures
```

### Installing Your Mod

1. In Reloaded-II, go to "Mods" folder
2. Copy your `fftivc.story.adlegacy` folder there
3. Enable it in Reloaded-II
4. Launch game

---

## Step 7: Repack Modified Files (Alternative Method)

If not using the mod loader, you can repack files:

```cmd
FF16Tools.CLI pack -i "C:\FFT_Modding\extracted\fftpack" -o "C:\FFT_Modding\repacked" -g fft
```

Then replace the original .pac files (BACKUP FIRST!).

---

## What You Can Modify

Based on the extracted structure:

| File Type | Tool/Method | Difficulty |
|-----------|-------------|------------|
| **Event scripts** | Hex editor / EVSP (if compatible) | Medium |
| **Data tables (.nxd)** | XML export via FF16Tools | Low |
| **Textures (.tex)** | FF16Tools tex-conv → edit → reconvert | Medium |
| **Maps** | GaneshaDx (PSP format, may need conversion) | High |
| **Audio** | Standard audio tools | Medium |

### Hardcoded Tables (Editable via XML)

The mod loader supports direct XML edits for:
- `AbilityData.xml` - Ability stats and effects
- `ItemData.xml` - Item properties
- `JobCommandData.xml` - Job ability assignments

Place in: `FFTIVC/tables/` folder in your mod.

---

## Current Tool Status (2025)

| Tool | PC/TIC Support |
|------|----------------|
| **FF16Tools** | Full extraction/repacking |
| **FFTIVC Mod Loader** | Full mod loading |
| **FFTPatcher** | PSP/PSX only (not directly compatible) |
| **GaneshaDx** | PSP format (may need conversion) |
| **EVSP** | PSP format (research needed) |

**Note:** The PC version uses different file formats than PSP. Some classic tools work on extracted files, others need adaptation.

---

## Backup Strategy

**ALWAYS backup before modding:**

```cmd
mkdir C:\FFT_Modding\backups
xcopy "C:\Program Files (x86)\Steam\steamapps\common\FINAL FANTASY TACTICS - The Ivalice Chronicles\data\enhanced" "C:\FFT_Modding\backups\enhanced_original" /E /I
```

Or use Steam's "Verify Integrity" to restore originals.

---

## Next Steps

1. Extract your game files (Step 3)
2. Explore the folder structure
3. Set up Reloaded-II + Mod Loader
4. Start with small edits (text/data tables)
5. Work up to events and maps

---

## Resources

- [FF16Tools GitHub](https://github.com/Nenkai/FF16Tools)
- [FFTIVC Mod Loader](https://github.com/Nenkai/fftivc.utility.modloader)
- [FFT Modding Docs](https://nenkai.github.io/ffxvi-modding/modding/creating_mods_fft/)
- [FFHacktics Community](https://ffhacktics.com/smf/index.php)
- [Reloaded-II](https://github.com/Reloaded-Project/Reloaded-II)

---

## Troubleshooting

**"unpack failed" errors:**
- Make sure you included `-g fft` flag
- Check .NET 8.0 is installed
- Run as Administrator if permission issues

**Game won't start with mods:**
- Launch through Reloaded-II, not Steam directly
- Check mod folder structure matches exactly

**Mod not loading:**
- Verify FFTIVC Mod Loader is checked in Reloaded-II
- Check file paths match game's internal structure
