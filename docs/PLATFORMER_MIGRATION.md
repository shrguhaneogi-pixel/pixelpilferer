# PIXEL PILFERER — PLATFORMER MIGRATION SPECIFICATION

This document details the system-by-system migration strategy from the top-down turn-based puzzle game (v1.0.0) to the 2D side-scrolling puzzle-platformer.

---

## 1. System Classification Matrix

| Subsystem | Existing File(s) | Classification | Technical Rationale & Migration Strategy |
| :--- | :--- | :--- | :--- |
| **Progress & Save** | `scripts/services/progress_service.gd`, `scripts/ui/save_manager.gd` | **Preserve Unchanged** | Dual-tier save/load, timestamp resolution, corrupt backup recovery, volume settings, and level completion tracking work flawlessly and are completely decoupled from movement mechanics. |
| **Audio Subsystem** | `scripts/services/audio_service.gd`, `assets/audio/*.wav` | **Preserve Unchanged** | Centralized bus audio, master/BGM/SFX volume controls, and 11 procedural sound effects (`sfx_steal`, `sfx_place`, `sfx_socket`, `sfx_bump`, `sfx_win`, etc.) directly map to platformer interactions. |
| **Core Constants** | `scripts/core/constants.gd` | **Refactor & Reuse** | Retain `BlockColor` enum, hex definitions, and dual-channel accessibility runes (`◆`, `▲`, `■`, `●`, `✚`). Extend with platformer action keys and collision layer bitmasks. |
| **Level Data Schema** | `scripts/core/level_data.gd`, `data/levels/*.json` | **Refactor & Reuse** | Level metadata schema (id, name, width, height, par moves/time, sockets, fragments) is adapted to 2D side-scrolling room dimensions. Top-down layouts will be replaced by handcrafted platformer levels. |
| **UI Modals & Screens** | `scripts/ui/settings_menu.gd`, `confirm_modal.gd`, `credits_modal.gd`, `title_screen.gd`, `pause_menu.gd` | **Refactor & Reuse** | Settings, confirmation modals, pause menu, and title screen remain functional. Minor adjustments for platformer control bindings (A/D/Space instead of Arrow-only). |
| **HUD & Feedback** | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | **Refactor & Reuse** | Carried block indicator, socket status, level title, and restart prompts remain. Step counter adapts to stopwatch/timer or platformer move counter. |
| **Camera System** | `scripts/view/pixel_camera.gd` | **Refactor & Reuse** | Upgrade from static grid framing to dynamic `Camera2D` with horizontal lookahead, vertical deadzone, and integer pixel snapping. |
| **Player Controller** | `scripts/view/player_view.gd`, `scripts/game/game_controller.gd` | **Replace** | Top-down turn-based step/tween controller cannot model continuous horizontal velocity, variable jumping, gravity, coyote time, or platform landing. Replaced by `CharacterBody2D` with `move_and_slide()`. |
| **Grid State / Rules** | `scripts/core/board_model.gd`, `board_state.gd`, `game_rules.gd` | **Replace** | 4-directional discrete transition $(S_t, \text{Action}) \to S_{t+1}$ replaced by hybrid platformer architecture: `PlayerPlatformer` handles physics; `PlatformTileManager` handles dynamic 16×16 tile-aligned block stealing and placement. |
| **Undo Subsystem** | `scripts/core/history_manager.gd` | **Replace** | Reversible discrete turn commands cannot roll back continuous real-time physics bodies. Replaced with safe **Checkpoint Snapshot Restoration** and instantaneous full-level restart. |
| **BFS Solver** | `scripts/core/puzzle_solver.gd`, `level_validator.gd` | **Deprecate & Replace** | Discrete grid pathfinding cannot prove jump reachability, airborne arcs, or platform timing. Replaced by **3-Tier Reachability Testing**: static data validation, discrete block manipulation tests, and scripted physics traversal tests. |
| **Top-Down Renderer** | `scripts/game/board_renderer.gd`, `level_view.gd`, `block_view.gd` | **Replace** | Top-down floor/wall rendering replaced by side-scrolling `TileMapLayer` and animated `StaticBody2D` dynamic platform instances. |

---

## 2. In-Depth Replacement Rationale & Dependencies

### 2.1 Replacement of `BoardModel` and `GameRules`
- **Technical Incompatibility:** `GameRules` operates on `Vector2i` player coordinates and instantaneous cell-to-cell transitions. In a platformer, horizontal movement is continuous float velocity governed by acceleration and friction; vertical movement is a parabolic curve governed by gravity ($v_y = v_0 + gt$).
- **The Hybrid Solution:**
  - Create `scripts/platformer/player_platformer.gd` (`CharacterBody2D`).
  - Create `scripts/platformer/platform_tile_manager.gd` (`Node2D`).
  - The player moves freely in continuous space. When the player presses `interact`, the `PixelGlove` raycasts/probes the discrete 16×16 tile grid within interaction range ($28\text{ px}$).
  - Stealing removes the block from the physics world; placing creates a solid floating platform with synchronized collision.

### 2.2 Replacement of Discrete `HistoryManager` (Undo)
- **Technical Incompatibility:** In discrete grid puzzles, undo simply pops $S_{t-1}$ from a stack and tweens the player to `(x, y)`. In a continuous physics platformer, arbitrary real-time undo can cause the player to spawn inside falling trajectories, mid-air hazards, or newly modified geometry.
- **The Checkpoint Architecture:**
  - Each level features start points and designated checkpoints.
  - Touching a checkpoint stores a clean snapshot of:
    1. Player coordinates.
    2. Dynamic block positions and held fragment.
    3. Socket states.
  - On hazard contact or pressing restart, the game snaps cleanly to the checkpoint state.

### 2.3 Replacement of BFS `PuzzleSolver`
- **Technical Incompatibility:** Godot's discrete BFS solver assumed that if `pos + Vector2i(1, 0)` is floor, it is reachable. In a platformer, reaching a platform requires evaluating jump clearance ($H \le 40.8\text{ px}$), horizontal jump distance ($R \le 87.1\text{ px}$), ceiling headroom ($32\text{ px}$), and timing.
- **The 3-Tier Testing Architecture:**
  - **Level 1 (Static):** Validates level boundaries, presence of spawn, reachable exit, valid fragment counts.
  - **Level 2 (Discrete Manipulation):** Tests that block stealing, carrying, placing, capacity limits, and collision updates obey deterministic rules.
  - **Level 3 (Physics Traversal):** Uses recorded input vectors and headless simulation scripts to prove that a human player can navigate the level, steal the necessary blocks, place the required bridges, and reach the exit.

---

## 3. Directory & File Migration Plan

### New Platformer Scripts & Scenes
```
scripts/platformer/
├── player_platformer.gd      # CharacterBody2D controller with movement, jumping, coyote, buffer
├── pixel_glove.gd            # Aiming raycast, steal, carry indicator, place logic
├── platform_tile_manager.gd  # Dynamic tile collision, floating platform generation
└── platformer_camera.gd      # Smooth Camera2D with lookahead and pixel snapping

scenes/test/
├── platformer_prototype.tscn # Milestone B: Isolated movement and physics test
└── broken_crossing.tscn      # Milestone C: "The Broken Crossing" vertical slice

scripts/test/
├── test_platformer_movement.gd # Milestone B automated headless verification
└── test_broken_crossing.gd     # Milestone C 9-step acceptance test runner
```

### Preserved Subsystems (Zero Breaking Changes)
- `scripts/services/progress_service.gd`
- `scripts/services/audio_service.gd`
- `scripts/core/constants.gd` (extended)
- `scenes/ui/settings_menu.tscn`
- `scenes/ui/confirm_modal.tscn`
- `scenes/ui/credits_modal.tscn`

---

## 4. Phased Milestone Execution Sequence

```
[Phase Zero: Audit & Specs] ──► [Milestone B: Movement Prototype] ──► [Milestone C: Vertical Slice]
         │                                       │                                   │
         ▼                                       ▼                                   ▼
  4 Design Docs in docs/             platformer_prototype.tscn              broken_crossing.tscn
  Local Git Commit                   Headless Physics Tests Pass            9/9 Acceptance Pass
```
