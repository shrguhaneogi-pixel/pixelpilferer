# Pixel Pilferer — Test & Quality Assurance Plan

## 1. Test Strategy & Objectives

The testing suite guarantees that:
1. Every locked game rule is strictly enforced by the authoritative state machine (`GameRules`).
2. No edge case allows illegal moves, illegal block placements, diagonal interactions, or carrying multiple blocks.
3. Undo and Restart are 100% loss-free and restore exact historical states.
4. States produce deterministic canonical hash keys for caching and solver state tracking regardless of internal block insertion order.
5. Every single one of the 23 levels (20 campaign + 3 tutorial demo puzzles) is mathematically proven solvable via an admissible A* search heuristic.
6. The presentation layer (`BoardRenderer`, `PlayerView`, `BlockView`, `HUD`) correctly visualizes model state without mutating domain logic.
7. All GDScript code adheres to static typing and Godot 4.7.2 standards.

---

## 2. Test Categories & 28 Mandatory Deterministic Cases

### Category A: Movement & Terrain Boundaries
- **Test 1 — Movement on ordinary floor:** Step north/east/south/west onto empty floor; position and turn count update; succeeds.
- **Test 2 — Rejection at fixed walls:** Step towards immutable wall; move rejected with reason `blocked_wall`; position and state unchanged.
- **Test 3 — Rejection at board boundaries:** Attempting to step off the grid rejected with `blocked_bounds`.
- **Test 4 — Rejection when entering empty void:** Step into unbridged void rejected with `blocked_void`.
- **Test 5 — Rejection when entering a floor block:** Movable block resting on ordinary floor acts as a solid obstacle; rejected with `blocked_block`.

### Category B: Block Manipulation & Void Bridging
- **Test 6 — Successful pickup of adjacent block:** Interaction towards adjacent block removes block from grid and places it into `carried_block` with color preserved.
- **Test 7 — Pickup rejection when already carrying:** Player carrying a block attempting to pick up another block is rejected with `cannot_place_on_block` (strict capacity = 1).
- **Test 8 — Successful placement onto floor:** Carried block placed on empty floor; cell becomes an obstacle; hand clears.
- **Test 9 — Successful placement onto void:** Carried block placed onto void cell transforms into a walkable bridge (`is_bridge == true`, event `bridge_created`).
- **Test 10 — Movement across a bridged void:** Player steps onto void cell with `is_bridge == true`; succeeds.
- **Test 11 — Rejection when placing on an occupied cell:** Attempting to place carried block onto an existing block rejected with `cannot_place_on_block`.
- **Test 12 — Rejection when placing on player cell:** Cannot place block on player's current coordinate (`cannot_place_on_player`).
- **Test 13 — Rejection when placing on exit portal:** Exit portal cannot be obstructed by placing a block (`cannot_place_on_exit`).
- **Test 14 — Color preservation across steal/place cycles:** Stolen block of specific color (e.g. Emerald) preserves color when placed elsewhere.

### Category C: Sockets & Win Conditions
- **Test 15 — Neutral socket activation:** Neutral socket accepts any block color; sets `is_socket_satisfied == true` with event `socket_activated`.
- **Test 16 — Colored socket activation:** Colored socket (e.g. Cyan) activates when matching block color placed on it.
- **Test 17 — Colored socket mismatch:** Placing non-matching color on colored socket succeeds but does not activate socket (`socket_mismatch`).
- **Test 18 — Exit reached with unsatisfied sockets:** Reaching exit when required sockets remain unsatisfied does not complete level (`is_completed == false`).
- **Test 19 — Exit reached with satisfied sockets:** Reaching exit when all required sockets are active (or in levels with 0 sockets) triggers `is_completed == true`.

### Category D: Undo & History Integrity
- **Test 20 — Undo after moving:** Undoing a move restores exact prior coordinate and decrements history.
- **Test 21 — Undo after pickup:** Undoing a pickup clears carried block from glove and restores block to board.
- **Test 22 — Undo after placement:** Undoing a placement removes placed block from board and restores it into player's hand.
- **Test 23 — Undo after completion:** Undoing win condition clears `is_completed` flag and restores previous position.
- **Test 24 — Restart after arbitrary action sequences:** Calling `restart()` resets board to $S_0$ and clears undo stack.

### Category E: Canonical State Identity & Invariants
- **Test 25 — Canonical state identity:** Two boards with identical block positions/colors inserted in different order produce identical `get_canonical_key()`.
- **Test 26 — Invalid action invariant:** Any rejected action leaves logical state 100% unchanged (`next_state == state`).
- **Test 27 — Placement followed by recovery:** Placing block on floor and immediately stealing it back returns player to original carried state.
- **Test 28 — Repeated undo/restart cycles:** Alternating moves and undos preserves $S_0$ state without drift or memory leaks.

---

## 3. Integrated Demonstration Scenario

A 7x3 corridor scenario verifying full core gameplay loop:
- Corridor: `(1,1)` Start -> `(2,1)` Block Obstacle -> `(3,1)` Floor -> `(4,1)` Void Pit -> `(5,1)` Exit Portal.
- Step A: Walking into `(2,1)` blocked by floor block.
- Step B: Steal block from `(2,1)` into Pixel Glove.
- Step C: Step into cleared floor at `(2,1)`.
- Step D: Advance to `(3,1)` facing void pit.
- Step E: Stepping directly into void `(4,1)` blocked.
- Step F: Place carried block into void `(4,1)` creating bridge.
- Step G: Traverse across bridged void onto `(4,1)`.
- Step H: Step onto Exit Portal at `(5,1)` completing level.

---

## 4. Property-Based Randomized Fuzzing

A 500-step random walk test with 10% undo probability asserting 5 physical invariants after every action:
1. **Invariant 1 — Bounds:** Player coordinate always remains within grid bounds.
2. **Invariant 2 — Uniqueness:** No two blocks share the same grid coordinate.
3. **Invariant 3 — Separation:** Player never overlaps a non-bridge movable block.
4. **Invariant 4 — Single Instance:** A carried block never simultaneously exists on the board.
5. **Invariant 5 — Terrain Immutability:** Base terrain tiles (Floor, Void, Wall) never mutate during gameplay actions.

---

## 5. Phase 3 Playable Vertical Slice Verification

### A. Rendering Pipeline & View State
- **Terrain Tile Mapping:** Verified `TileMapLayer` sets Tile 0 (Floor), Tile 1 (Wall), Tile 2 (Void), and Tile 3 (Bridge over void).
- **Socket Visual States:** Verified Frame 2 (Cyan Inactive) transitions to Frame 3 (Cyan Active) when matching block placed.
- **Exit Portal States:** Verified Frame 0 (Locked arch) transitions to Frame 1 (Open radiant vortex) when win condition satisfied.
- **Block Views:** Verified obstacle block (`z_index = 2`, `scale = (1, 1)`) vs bridge block (`z_index = 0`, `scale = (0.9, 0.9)`, tinted modulate).
- **Player View:** Verified 4-way facing frames (South=0, East=1, North=2, West=3), carried sprite visibility/color, and invalid move bump feedback.

### B. Input Handling & Buffering
- **WASD & Shift + Direction:** Verified directional movement and adjacent interactions.
- **Contextual Interact (E / Space):** Verified interaction in last faced direction.
- **Mouse Cell Interaction:** Verified Manhattan distance translation for adjacent clicks.
- **Input Buffering:** Verified 120ms buffer queues next action during active animation and auto-executes upon move completion.
- **Undo / Restart Interruption:** Verified active tweens are immediately killed and view snaps to restored state.

### C. HUD & Interface
- **Carried-Fragment Indicator:** Displays "Glove: Empty" when empty and "Glove: [Color] Fragment" with color badge when holding a block.
- **Socket Counter:** Formats as "No Sockets", "Sockets: X/Y", or "Sockets: Y/Y (Active)".
- **Exit Status:** Formats as "Exit: LOCKED" vs "Exit: OPEN".
- **Focus Safety:** All HUD buttons set to `focus_mode = FOCUS_NONE`.

### D. Authored Demo Puzzles (100% Solvable)
- **Demo A (`demo_01`):** "The Obstructed Path" — Solved in optimal 5 steps.
- **Demo B (`demo_02`):** "Chasm Bridge" — Solved in optimal 6 steps.
- **Demo C (`demo_03`):** "Chromatic Socket" — Solved in optimal 6 steps.

---

## 6. Phase 4 Puzzle Solver & Level Validation Verification

14 comprehensive test cases verifying solver optimality, formal schema validation, solution replay, and intelligent hint generation:
1. **Simple Route:** 2-step straight path with no movable blocks solved and verified.
2. **Pickup Obstacle:** Requires siphoning blocking block eastward to reach exit portal.
3. **Bridge Placement:** Requires placing carried block into void to bridge chasm and cross.
4. **Neutral Socket:** Placement of block onto neutral socket unlocks exit portal.
5. **Colored Socket:** Specific placement of Cyan block onto Cyan socket (and Amber onto Amber) satisfies win condition.
6. **Indistinguishable Fragments:** Swapped block IDs of identical color and carried fragments produce identical canonical keys.
7. **Impossible Level:** Enclosed room with no solution correctly returns `SolverStatus.UNSOLVABLE` (`solved == false`, `steps == -1`).
8. **Level Validator Rejections:** Catches blocks on immutable walls (with cell coordinate), ragged layouts, and overlapping blocks.
9. **Multi-Step Puzzle:** Multi-action steal-bridge-cross sequences verified solvable in minimal step count.
10. **Fragment Reordering:** Different block insertion orders produce 100% identical canonical keys and state hashes.
11. **Contextual Hint System:** Hint queries from mid-level states provide valid next-action guidance; unwinnable states advise Undo or Restart.
12. **Search Limit Enforcement:** Limiting search budget (e.g. `max_visited = 5`) safely returns `SolverStatus.LIMIT_REACHED` without falsely claiming unsolvable.
13. **Solution Replay Verification:** Verifies all steps execute cleanly to completion, and detects tampered illegal actions with exact step index and rejection reason.
14. **Live Model Execution:** Actions returned by solver executed sequentially through `BoardModel`, firing signals and completing level.

---

## 7. Phase 5 Complete Campaign & Progression Verification

Comprehensive test cases verifying the full 20-level campaign curriculum, progression persistence, and restoration victory flow:
1. **Chapter Level Count:** Verifies Chapters 1 through 4 each contain exactly 5 levels (20 total campaign levels).
2. **Level Schema Validation:** Validates every level through `LevelValidator` (unique IDs, dimensions, player start, exit, non-overlapping blocks).
3. **Chapter 1 Invariants:** Asserts Chapter 1 levels (`ch1_01` to `ch1_05`) contain strictly NO VOID and NO SOCKETS before their introduction.
4. **Chapter 2 Invariants:** Asserts Chapter 2 levels (`ch2_01` to `ch2_05`) contain strictly NO SOCKETS before Chapter 3.
5. **Chapter 3 Invariants:** Asserts Chapter 3 levels (`ch3_01` to `ch3_05`) contain strictly NO COLORED SOCKETS before Chapter 4.
6. **Tutorial / Demo Integrity:** Asserts Chapter 0 contains 3 verified tutorial levels.
7. **Progression Locking & Unlocking:** Asserts `ch1_01` unlocked by default, completing `ch1_01` unlocks `ch1_02`, and completing all 5 levels unlocks Chapter 2.
8. **Restoration Storytelling:** Asserts chapter completion awards world restoration text ("The Neon Grid Hums to Life", etc.).
9. **Campaign Completion & Grand Victory:** Asserts campaign completion triggers only after `ch4_05` is finished, bringing up the grand victory modal with total move summary.

---

## 8. Phase 6 Art Direction, Animation, Audio & Settings Verification

Comprehensive test cases verifying the presentation layer, asset dimensions, procedural sound palette, and accessibility controls:
1. **Sprite Dimensions & Frames:** Verifies `pip.png` (64x16, 4 frames), `blocks.png` (80x16, 5 frames), `tileset.png` (64x16, 4 tiles), `sockets.png` (160x16, 10 frames), `exit_portal.png` (32x16, 2 frames), and `icon.png` (64x64).
2. **AudioService Sound Palette:** Verifies all 10 sound effect players (`steal`, `place`, `socket`, `step`, `undo`, `win`, `bump`, `exit_open`, `ui_click`, `chapter_restored`) and the ambient music player are initialized.
3. **Decibel & Volume Invariants:** Asserts `volume_db` properly converts from linear scalar product (`linear_to_db(vol * master)`) and that disabling music attenuates to -80.0 dB.
4. **PlayerView Animations & Idle State:** Verifies idle breathing state is activated when `reduced_motion = false`, deactivates on `reduced_motion = true`, and snaps cleanly with zero lingering offsets.
5. **BoardRenderer Theming & Shake:** Asserts chapter themes 1 to 4 adjust color modulation cleanly, portal unlock emits `portal_unlocked` signal, and camera screen shake respects `reduced_motion` and `screen_shake_enabled`.
6. **Settings Persistence:** Verifies `SettingsMenu` sliders and checkboxes are properly wired to `ProgressService` and persist `master_volume`, `sfx_volume`, `music_volume`, `reduced_motion`, and `screen_shake`.

---

## 9. Test Runners & Commands

### Headless Godot 4.7.2 Suite
```powershell
& "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://tests/test_runner.gd
```
- Runs **361 assertions** covering resource loading, data structures, invariants, all 28 deterministic tests, demo corridor scenario, 500-step fuzzing, board rendering, player animation & particles, block views, input handling & buffering, HUD upgrades, sequential demo progression, Phase 4 solver & validation tests, Phase 5 campaign & progression tests, and Phase 6 art, animation, audio, and accessibility tests.

### Master Headless Runner (Python dual-harness)
```powershell
python tests/run_tests.py
```
- Runs 79 domain assertions, vertical slice demo verification, 54 Phase 4 solver/validator assertions, and all 23 levels verified solvable with BFS/A* search heuristic.

### Formal Campaign Audit
```powershell
python tests/test_campaign_audit.py
```
- Audits all 20 campaign levels against curriculum invariants, bounds, optimal steps, and solution replay verification. Outputs report to `docs/CAMPAIGN_VALIDATION.md`.
