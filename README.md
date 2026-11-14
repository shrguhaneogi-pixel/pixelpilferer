# Pixel Pilferer

> **Steal the world. Rebuild your escape.**

*Pixel Pilferer* is a 2D top-down pixel-art puzzle adventure built with Godot 4.7 and GDScript. Players embody **Pip**, a diminutive hooded thief equipped with the legendary **Pixel Glove**, infiltrating geometric vaults to siphon blocks from reality itself, convert abysses into bridges, power chromatic sockets, and open the exit portal.

---

## 1. Core Mechanics & Rules

- **Discrete Grid Movement:** Strictly four-directional orthogonal movement (`Vector2i`).
- **Adjacent Interactions:** Pip siphons ("steals") or places blocks exclusively into adjacent orthogonal cells.
- **Carrying Capacity:** Exactly one block at a time.
- **Floor vs Void Duality:**
  - A movable block on ordinary floor functions as an obstacle.
  - A movable block dropped into a void pit creates a traversable bridge.
  - Bridge blocks can be stolen back out of the void, returning the cell to an impassable chasm.
- **Chromatic Sockets:**
  - **Neutral Sockets:** Activated by any block.
  - **Colored Sockets:** Require an exact chromatic match (Cyan, Amber, Magenta, Emerald).
- **Exit Portal:** Unlocked only when every required socket in the chamber is satisfied.
- **Deterministic History:**
  - **Undo:** Rewinds the exact prior state losslessly ($S_t \to S_{t-1}$).
  - **Restart:** Restores the level's exact initial state ($S_0$).

---

## 2. Controls

| Action | Primary Key | Secondary Key | Controller / Handheld |
| :--- | :---: | :---: | :---: |
| **Move Up / Face North** | `W` | `Up Arrow` | D-Pad Up |
| **Move Down / Face South** | `S` | `Down Arrow` | D-Pad Down |
| **Move Left / Face West** | `A` | `Left Arrow` | D-Pad Left |
| **Move Right / Face East** | `D` | `Right Arrow` | D-Pad Right |
| **Steal / Place Block** | `E` | `Space` / `J` | Button A / Trigger |
| **Undo Turn** | `Z` | `U` / `Backspace` | Button B |
| **Restart Level** | `R` | - | Button Y |
| **Hint** | `H` | - | Button X |
| **Menu / Pause** | `Escape` | - | Start |

---

## 3. Campaign Structure (20 Solver-Verified Levels)

The game features four distinct thematic chapters with five handcrafted levels each:

### Chapter 1: The Stolen Street
- `ch1_01`: **First Steps** (Intro to block theft and socket activation)
- `ch1_02`: **Alley Shortcut** (Clearing obstacles and rerouting corridors)
- `ch1_03`: **Void Cross** (Bridging single chasms and retrieving bridge blocks)
- `ch1_04`: **Alleyway Duality** (Dual-block bridge and socket management)
- `ch1_05`: **The Twin Locks** (Multi-socket coordination in narrow streets)

### Chapter 2: The Broken Bridges
- `ch2_01`: **Chasm Hop** (Wide gap navigation)
- `ch2_02`: **The Leapfrog** (Sequential single-block bridging across multiple chasms)
- `ch2_03`: **Double Plank** (Parallel chasm routing)
- `ch2_04`: **Isolated Isle** (Isle socket activation and escape)
- `ch2_05`: **The Great Divide** (Multi-gap bridging cycles)

### Chapter 3: The Forgotten Vault
- `ch3_01`: **Amber Awakening** (Introduction to Amber chromatic blocks & sockets)
- `ch3_02`: **Spectrum Split** (Differentiating Neutral vs Amber sockets)
- `ch3_03`: **Tight Quarter Exchange** (Close-confines block exchange)
- `ch3_04`: **The Vault Siphon** (Temporary bridging for resource extraction)
- `ch3_05`: **The Triad Conduit** (Triple-socket power routing)

### Chapter 4: The Chromatic Core
- `ch4_01`: **Neon Spectrum** (Cyan and Magenta harmony)
- `ch4_02`: **Emerald Gate** (High-frequency Emerald fragment guidance)
- `ch4_03`: **The Rainbow Bridge** (Tri-color chasm crossing)
- `ch4_04`: **Chromatic Labyrinth** (Multi-color non-blocking corridors)
- `ch4_05`: **The Core Chamber** (The Master Heist: 4-color master vault puzzle)

---

## 4. Architecture & Engineering Standards

- **Strict Model-View Separation:** The logical simulation operates completely decoupled from Godot's SceneTree and rendering loop.
- **Godot 4.7 Dedicated `TileMapLayer` Nodes:** Uses dedicated `TileMapLayer` nodes (`VoidLayer`, `FloorLayer`, `SocketLayer`, `WallLayer`) with exact z-indices; zero calls to legacy `TileMap` methods.
- **Pixel-Art Rendering Standards:**
  - Base viewport: `320x180` (16:9 aspect ratio, 16x16 tiles = 20x11.25 tiles).
  - Stretch mode: `canvas_items` with integer scaling (`scale_mode = "integer"`).
  - Texture filter: `Nearest` (Point).
  - Snap 2D transforms and vertices to integer pixels to prevent subpixel jitter.
- **Accessibility:** Built-in **Reduced Motion** mode (snaps entity movements instantly without tweening, eliminates camera shake).
- **Single-Threaded Web Export:** Configured with `threads/thread_model=0` in `export_presets.cfg` for universal compatibility across static hosts and itch.io without requiring `COOP`/`COEP` headers.

---

## 5. Automated Testing & Verification

The repository includes a comprehensive dual-test harness:

### Run Master Test Suite (Instant Local Execution)
```bash
python tests/run_tests.py
```
This runs:
1. **Domain Invariant Suite:** 33 assertions verifying all collision rules, inventory limits, bridge mechanics, and undo integrity.
2. **A* / BFS Solvability Verifier:** Mathematically tests and proves solvability for all 20 levels.

### Run Headless Godot Suite (When Godot 4.7 is installed)
```bash
godot --headless --script res://tests/test_runner.gd
```

---

## 6. Asset & Code Licenses

- **Code:** MIT License.
- **Visual Sprites & Sound Effects:** Original lightweight procedural pixel-art assets and 16-bit retro synthesized audio generated specifically for Pixel Pilferer. Dedicated to the Public Domain (CC0 1.0 Universal).
