# Headless Testing, Failure Detection, and Regression Checks

## 1. Headless CLI Execution

Godot 4.7 provides native headless execution without requiring an X11/Wayland display server or GPU window context.

### Execution Command
```bash
godot --headless --script res://tests/test_runner.gd
```

### Exit Codes
- `0`: All tests passed.
- `1`: One or more tests failed or script threw an error.

> [!IMPORTANT]
> **Mandatory Safeguard:** Never claim tests passed without executing the command in the shell and inspecting the real output and exit code.

---

## 2. Zero-Dependency Native Test Runner

You do not need heavy third-party testing plugins for deterministic gameplay verification. Implement a lightweight `SceneTree` runner:

```gdscript
# res://tests/test_runner.gd
extends SceneTree

var _total_tests: int = 0
var _failed_tests: int = 0

func _init() -> void:
    print("=== Running Pixel Pilferer Headless Tests ===")
    
    _test_grid_initialization()
    _test_movement_and_collision()
    _test_undo_stack()
    _test_solver_reachability()
    
    print("\n-------------------------------------------")
    print("Tests executed: %d | Failed: %d" % [_total_tests, _failed_tests])
    
    if _failed_tests > 0:
        print("FAILED: Suite exited with errors.")
        quit(1)
    else:
        print("SUCCESS: All tests passed.")
        quit(0)

func _assert_true(condition: bool, test_name: String) -> void:
    _total_tests += 1
    if not condition:
        _failed_tests += 1
        printerr("  [FAIL] %s" % test_name)
    else:
        print("  [PASS] %s" % test_name)

func _assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
    _total_tests += 1
    if actual != expected:
        _failed_tests += 1
        printerr("  [FAIL] %s (Expected: %s, Got: %s)" % [test_name, str(expected), str(actual)])
    else:
        print("  [PASS] %s" % test_name)

func _test_grid_initialization() -> void:
    var model := GridBoardModel.new()
    model.initialize(Vector2i(5, 5), [Vector2i(1, 1)])
    _assert_true(model.is_cell_obstructed(Vector2i(1, 1)), "Wall at (1,1) is obstructed")
    _assert_true(not model.is_cell_obstructed(Vector2i(0, 0)), "Cell (0,0) is walkable")
    _assert_true(model.is_cell_obstructed(Vector2i(-1, 0)), "Negative coordinate is out of bounds")

func _test_movement_and_collision() -> void:
    var model := GridBoardModel.new()
    model.initialize(Vector2i(5, 5), [Vector2i(2, 0)])
    model.register_entity(1, Vector2i(1, 0))
    
    # Attempt moving into wall
    var moved_into_wall := model.try_move_entity(1, Vector2i.RIGHT)
    _assert_true(not moved_into_wall, "Cannot move into solid wall")
    _assert_eq(model.entity_cells[1], Vector2i(1, 0), "Entity stays at (1,0)")

    # Move into empty space
    var moved_down := model.try_move_entity(1, Vector2i.DOWN)
    _assert_true(moved_down, "Successfully moves into empty cell")
    _assert_eq(model.entity_cells[1], Vector2i(1, 1), "Entity reaches (1,1)")

func _test_undo_stack() -> void:
    var history := HistoryManager.new()
    var snap1 := BoardSnapshot.new()
    snap1.turn = 1
    snap1.entity_positions = {1: Vector2i(0, 0)}
    history.record_state(snap1)

    var snap2 := BoardSnapshot.new()
    snap2.turn = 2
    snap2.entity_positions = {1: Vector2i(1, 0)}
    history.record_state(snap2)

    var restored := history.pop_undo()
    _assert_eq(restored.turn, 1, "Undo restores turn 1")
    _assert_eq(restored.entity_positions[1], Vector2i(0, 0), "Undo restores position (0,0)")

func _test_solver_reachability() -> void:
    var model := GridBoardModel.new()
    model.initialize(Vector2i(3, 3), [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)])
    var path := GridSolver.find_shortest_path(model, Vector2i(0, 0), Vector2i(2, 0))
    _assert_true(path.is_empty(), "Wall completely blocks path to goal")
```

---

## 3. Regression Testing Guidelines

Maintain a test script covering:
1. **Movement Invariants:** Entity cannot move outside board bounds or into solid walls.
2. **Occupancy Exclusivity:** Two entities cannot occupy the same cell.
3. **Turn Consistency:** One player step advances turn counter by exactly 1.
4. **Push / Slide Chains:** Boxes stop when colliding with walls; chains abort if end is blocked.
5. **Undo Integrity:** `state -> action -> undo` results in identical state hash or properties.
