# Pixel Pilferer — Test & Quality Assurance Plan

## 1. Test Strategy & Objectives

The testing suite guarantees that:
1. Every locked game rule is strictly enforced by the authoritative state machine (`GameRules`).
2. No edge case allows illegal moves, illegal block placements, diagonal interactions, or carrying multiple blocks.
3. Undo and Restart are 100% loss-free and restore exact historical states.
4. States produce deterministic canonical hash keys for caching and solver state tracking regardless of internal block insertion order.
5. Every single one of the 20 handcrafted levels is mathematically proven solvable via an admissible A* search heuristic.
6. All GDScript code adheres to static typing and Godot 4.7.2 standards.

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

## 5. Test Runners & Commands

### Headless Godot 4.7.2 Suite
```powershell
& "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://tests/test_runner.gd
```
- Runs 113 assertions covering scene loading, data structures, invariants, all 28 deterministic tests, demo scenario, 500-step fuzzing, invalid data error handling, and solver integration.

### Master Headless Runner (Python dual-harness)
```powershell
python tests/run_tests.py
```
- Runs 79 domain assertions + all 20 handcrafted levels verified solvable with A* search heuristic.
