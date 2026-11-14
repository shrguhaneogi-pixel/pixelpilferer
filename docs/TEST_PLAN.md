# Pixel Pilferer — Test & Quality Assurance Plan

## 1. Test Strategy & Objectives

The testing suite guarantees that:
1. Every locked game rule is strictly enforced by the state machine.
2. No edge case allows illegal moves, illegal block placements, or carrying multiple blocks.
3. Undo and Restart are 100% loss-free and restore exact historical states.
4. Every single one of the 20 handcrafted levels is mathematically proven solvable via BFS search.
5. All GDScript code adheres to static typing and Godot 4.7 standards.

---

## 2. Test Categories

### A. Movement & Collision Invariants
- `test_player_move_empty_floor`: Moving into an empty floor cell succeeds.
- `test_player_move_blocked_wall`: Moving into an immutable wall fails and position is unchanged.
- `test_player_move_blocked_void`: Moving into unbridged void fails.
- `test_player_move_blocked_block`: Moving into a cell with a movable block on floor fails.
- `test_player_move_bounds`: Moving outside grid boundaries fails.

### B. Block Manipulation Mechanics
- `test_steal_block_adjacent`: Stealing adjacent movable block succeeds, adds block to player's carry slot, removes block from cell.
- `test_steal_block_diagonal_forbidden`: Diagonal steal attempts are rejected.
- `test_steal_block_while_carrying_forbidden`: Stealing when already carrying a block is rejected (capacity = 1).
- `test_steal_immutable_wall_forbidden`: Attempting to steal an immutable wall fails.
- `test_place_block_on_floor`: Placing carried block on empty floor succeeds; cell becomes an obstacle.
- `test_place_block_on_void`: Placing carried block over void succeeds; cell becomes a walkable bridge.
- `test_steal_bridge_from_void`: Stealing a bridge block from a void cell succeeds; cell reverts to impassable void.
- `test_place_block_on_player_cell_forbidden`: Cannot place block on self.
- `test_place_block_on_occupied_cell_forbidden`: Cannot place block on existing block or wall.

### C. Socket & Win Condition Mechanics
- `test_neutral_socket_accepts_any_color`: Neutral socket activates with Neutral, Cyan, Amber, Magenta, or Emerald blocks.
- `test_colored_socket_requires_exact_match`: Cyan socket only activates with Cyan block; Amber with Amber.
- `test_exit_locked_until_all_sockets_satisfied`: Moving to exit before sockets are satisfied does not complete level.
- `test_exit_unlocked_when_all_sockets_satisfied`: Reaching exit after all sockets are active triggers level clear.

### D. Undo & History Integrity
- `test_undo_single_move`: `Move -> Undo` returns exact prior position and turn count.
- `test_undo_steal_and_place`: Steal + Place + 2x Undo restores original block placement and clear carry slot.
- `test_undo_bridge`: Bridging void + walking on bridge + undo restores player and bridge state.
- `test_restart_restores_initial_state`: Multiple actions followed by Restart restores $S_0$.

### E. 20 Handcrafted Levels BFS Solvability
- Every level (1-1 through 4-5) must be solved by `PuzzleSolver.solve(level)`.
- Solution path length must be $\ge$ minimum expected moves (no trivial zero-step bypass).
- Verification records the minimal solution action sequence for hint generation.

---

## 3. Test Runners & Commands

### Headless Godot Suite (When Godot is available)
```bash
godot --headless --script res://tests/test_runner.gd
```

### Reference Dual-Harness Suite (Instant Local Execution)
```bash
python tests/run_tests.py
```
Both test suites evaluate identical state transition rules and level files.
