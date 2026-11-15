# Pixel Pilferer

> **Steal the world. Rebuild your escape.**

*Pixel Pilferer* is a 2D top-down grid-based puzzle adventure built with Godot 4.7.2 stable and GDScript. Players embody **Pip**, a diminutive hooded thief equipped with the legendary **Pixel Glove**, infiltrating geometric vaults to siphon movable blocks from reality itself, convert abysses into bridges, power chromatic sockets, and rebuild an escape portal.

---

## 1. Core Mechanics & Rules

- **Discrete Grid Movement:** Strictly four-directional orthogonal movement (`Vector2i`).
- **Adjacent Interactions:** Pip siphons ("steals") or places blocks into adjacent orthogonal cells.
- **Carrying Capacity:** Exactly one block at a time.
- **Floor vs. Void Duality:**
  - A movable block on ordinary floor functions as an obstacle.
  - Siphoning a block removes it from the board into the glove, clearing the corridor.
  - A carried block dropped into a void pit creates a traversable bridge.
  - Bridge blocks can be stolen back out of the void, returning the cell to an impassable chasm and enabling leapfrogging across deep chasms.
- **Chromatic Sockets & Conduits:**
  - **Neutral Sockets (`✚`):** Activated by any block.
  - **Colored Sockets:** Require an exact chromatic and rune match:
    - Cyan (`◆`)
    - Amber (`▲`)
    - Magenta (`■`)
    - Emerald (`●`)
- **Exit Portal:** Unlocked and energized only when every required socket in the chamber is satisfied.
- **Lossless Deterministic History:**
  - **Undo (`Z`):** Rewinds the exact prior state losslessly ($S_t \to S_{t-1}$).
  - **Restart (`R`):** Restores the level's exact initial state ($S_0$).
  - **Hint (`H`):** Contextual tactical guidance derived from the authoritative BFS solver.

---

## 2. Controls & Input

The game supports seamless hybrid controls across keyboard, mouse, and gamepads:

| Action | Primary Keyboard | Secondary Keyboard | Mouse / Touch | Gamepad / Handheld |
| :--- | :---: | :---: | :---: | :---: |
| **Move Up / Face North** | `W` | `Up Arrow` | - | D-Pad Up / Left Stick |
| **Move Down / Face South** | `S` | `Down Arrow` | - | D-Pad Down / Left Stick |
| **Move Left / Face West** | `A` | `Left Arrow` | - | D-Pad Left / Left Stick |
| **Move Right / Face East** | `D` | `Right Arrow` | - | D-Pad Right / Left Stick |
| **Directional Steal / Place** | `Shift + Direction` | - | Click adjacent block to Steal; Click floor to Place | Trigger / Shoulder + D-Pad |
| **Facing Steal / Place** | `E` | `Space` / `J` | - | Button A |
| **Direct Tile Interaction** | - | - | Click adjacent empty floor/exit to Walk; Click block to Steal | - |
| **Undo Turn** | `Z` | `U` / `Backspace` | In-Game HUD Button | Button B |
| **Restart Level** | `R` | - | In-Game HUD Button | Button Y |
| **Tactical Hint** | `H` | - | In-Game HUD Button | Button X |
| **Pause / Menu** | `Escape` | - | In-Game HUD Button | Start |

---

## 3. Campaign Structure (23 Solved & Verified Levels)

The campaign features 23 handcrafted, mathematically proven levels:

### Chapter 0: Tutorial & Demo
- `demo_01`: **The Obstructed Path** (Basic movement and obstacle clearing)
- `demo_02`: **Chasm Bridge** (Creating void bridges)
- `demo_03`: **Chromatic Socket** (Activating sockets to energize the exit)

### Chapter 1: The Stolen Street (Neon Twilight)
- `ch1_01`: **The Blocked Alley** (Single block siphon)
- `ch1_02`: **The Side Pocket** (Side alcove relocation)
- `ch1_03`: **Turnabout** (Placement choices and loopbacks)
- `ch1_04`: **Squeeze Point** (Tight corridor maneuvering)
- `ch1_05`: **The Double Gate** (Dual obstacle coordination)

### Chapter 2: The Broken Bridges (Skyway Oceanic)
- `ch2_01`: **First Gap** (1-tile void chasm bridge)
- `ch2_02`: **Obstacle to Bridge** (Obstacle siphoning into bridge)
- `ch2_03`: **Island Hop** (Stepping onto isolated pillar)
- `ch2_04`: **The Leapfrog** (Bridge siphon-back from behind)
- `ch2_05`: **The Grand Divide** (Multi-gap leapfrog coordination)

### Chapter 3: The Forgotten Vault (Obsidian Violet)
- `ch3_01`: **Conduit Awakening** (Single neutral socket)
- `ch3_02`: **The Vault Niche** (Side niche socket navigation)
- `ch3_03`: **Conduit and Chasm** (Bridge and socket duality)
- `ch3_04`: **Dual Conduits** (Dual neutral sockets)
- `ch3_05`: **Vault Masterwork** (Multi-corridor socket planning)

### Chapter 4: The Chromatic Core (Prismatic Full Spectrum)
- `ch4_01`: **Prismatic Intro** (Cyan socket matching)
- `ch4_02`: **Duo Resonators** (Cyan and Amber matching)
- `ch4_03`: **Chromatic Bridge** (Neutral bridge + Magenta socket)
- `ch4_04`: **Triad Conduits** (Cyan, Amber, Magenta conduits)
- `ch4_05`: **The Grand Core** (4-Color masterwork climax)

---

## 4. Architecture & Engineering Standards

- **Strict Model-View Decoupling:** Pure GDScript deterministic domain model (`res://scripts/core/`) runs independently of Godot's SceneTree and floating-point frame delta.
- **Godot 4.7 Dedicated `TileMapLayer` Nodes:** Uses individual `TileMapLayer` nodes (`VoidLayer`, `FloorLayer`, `SocketLayer`, `WallLayer`) with exact z-indices; zero calls to legacy monolithic `TileMap` methods.
- **Pixel-Art Standards:**
  - Viewport: `640x360` (16:9 aspect ratio, 16x16 tiles).
  - Stretch mode: `viewport` with integer scaling (`scale_mode = "integer"`).
  - Texture filter: `Nearest` (Point sampling, `default_texture_filter=0`).
  - Snap 2D transforms and vertices to integer pixels to prevent subpixel jitter.
- **Colorblind Accessibility:** Every chromatic block and socket features a distinct geometric rune (`◆`, `▲`, `■`, `●`, `✚`) so puzzle logic never depends solely on color perception.
- **Accessibility & Preferences:** Built-in settings for **Reduced Motion** (snaps entity movements instantly, disables screen shake), independent SFX and Music volume sliders, and Corrupted Save Auto-Recovery.

---

## 5. Automated Testing & Verification

The project includes an exhaustive automated verification suite:

### 1. Master Python Test Runner (Instant Local Execution)
```bash
python tests/run_tests.py
```
Executes:
1. **Domain Invariant Suite:** 79 tests verifying collision, rules, and bridge mechanics.
2. **Vertical Slice Demo Suite:** Verifies demo level solutions and schema.
3. **Solver & Validator Suite:** 54 tests covering BFS/A* and schema validation.
4. **Campaign Solvability Audit:** Solves all 23 levels with 100% determinism.
5. **Adversarial QA Suite:** 270 tests including 10,000-step randomized fuzzing.
6. **Final Release Verification:** 361 assertions covering the complete shipping lifecycle.

### 2. Godot Headless Test Runner
```bash
godot --headless --script res://tests/test_runner.gd
```
Executes 435 in-engine assertions verifying resource loading, SceneTree nodes, camera tracking, particle systems, input buffering, modal layering, and save file I/O.

---

## 6. How to Build & Export

### Windows Desktop Package
```bash
# Export the game data pack
godot --headless --export-pack "Windows Desktop" build/desktop/PixelPilferer.pck

# Copy the standalone Godot binary alongside the PCK:
cp Godot_v4.7.2-stable_win64.exe build/desktop/PixelPilferer.exe
```
When launched, `PixelPilferer.exe` automatically binds and executes `PixelPilferer.pck`.

### Web / HTML5 Export
Configured in `export_presets.cfg` (`preset.1`) with single-threaded WebAssembly (`threads/thread_model=0`) for universal hosting without requiring special `COOP`/`COEP` server headers. Requires Godot Web export templates.

---

## 7. Save File Locations

- **Windows Desktop:** `%APPDATA%\Godot\app_userdata\Pixel Pilferer\pixel_save.json`
- **Backup File:** `%APPDATA%\Godot\app_userdata\Pixel Pilferer\pixel_save.bak`
- **Fallback Cache (Headless/Sandboxed Environments):** `res://.save_cache.json`

---

## 8. Known Limitations

1. **Web Export Templates in Current Host Environment:** The active offline environment does not include pre-installed Godot Web export templates (`web_nothreads_release.zip`), so Web export is documented as template-limited in this build.
2. **Diagonal Interactions:** Diagonal movement and interactions are intentionally rejected by design to maintain discrete orthogonal puzzle integrity.

---

## 9. Asset & Code Licenses

- **Code:** MIT License.
- **Original Sprites & Procedural Audio:** All sprites (`pip.png`, `blocks.png`, `tileset.png`, `exit_portal.png`, `icon.png`) and synthesized 16-bit retro audio tracks are original assets created specifically for Pixel Pilferer. Dedicated to the Public Domain (CC0 1.0 Universal).
