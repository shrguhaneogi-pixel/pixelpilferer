# State Transitions, Undo Systems, and Puzzle Solvers

## 1. Pure State Transitions

A turn-based puzzle game is mathematically modeled as a deterministic state machine:
$$\text{State}_{t+1} = f(\text{State}_t, \text{Action})$$

Because $f$ is deterministic, any state can be recorded, rewound, or simulated ahead of time without side effects.

---

## 2. Undo Architecture: Command vs Snapshot

### Pattern A: Reversible Command Pattern (Lightweight)
Store discrete atomic actions on an undo stack. Best for fast operations with minimal memory.

```gdscript
class_name MoveCommand extends RefCounted

var entity_id: int
var from_cell: Vector2i
var to_cell: Vector2i

func _init(id: int, from_pos: Vector2i, to_pos: Vector2i) -> void:
    entity_id = id
    from_cell = from_pos
    to_cell = to_pos

func undo(board: GridBoardModel) -> void:
    board.teleport_entity(entity_id, from_cell)
```

### Pattern B: Immutable State Snapshot (Bulletproof)
Store a complete serialized copy of the board state per turn. Immune to missed undo reversions.

```gdscript
class_name BoardSnapshot extends RefCounted

var turn: int
var entity_positions: Dictionary[int, Vector2i]
var collected_items: Array[int]
var switch_states: Dictionary[Vector2i, bool]

func duplicate_snapshot() -> BoardSnapshot:
    var copy := BoardSnapshot.new()
    copy.turn = turn
    copy.entity_positions = entity_positions.duplicate()
    copy.collected_items = collected_items.duplicate()
    copy.switch_states = switch_states.duplicate()
    return copy
```

### Managing the Undo Stack
```gdscript
class_name HistoryManager extends RefCounted

var _undo_stack: Array[BoardSnapshot] = []
var _redo_stack: Array[BoardSnapshot] = []

func record_state(snapshot: BoardSnapshot) -> void:
    _undo_stack.append(snapshot.duplicate_snapshot())
    _redo_stack.clear()

func can_undo() -> bool:
    return _undo_stack.size() > 1 # Keep at least initial state

func pop_undo() -> BoardSnapshot:
    if not can_undo():
        return null
    var current := _undo_stack.pop_back()
    _redo_stack.append(current)
    return _undo_stack.back() # Return previous state
```

---

## 3. Resynchronizing Views After Undo

When an undo occurs:
1. Restore the model's logical state immediately.
2. Signal the view layer that state has rewound (`state_restored.emit()`).
3. The view layer snaps or quickly tweens entities to their restored positions:

```gdscript
func _on_state_restored(entity_positions: Dictionary[int, Vector2i]) -> void:
    for entity_id in entity_positions:
        var target_cell: Vector2i = entity_positions[entity_id]
        var view: EntityView = get_entity_view(entity_id)
        if view:
            view.snap_to_cell(target_cell) # Snap instantly to avoid animation race conditions
```

---

## 4. Headless Puzzle Solver (BFS Pathfinding & Solvability)

Because the model has zero SceneTree dependencies, search algorithms can verify level solvability at compile/test time:

```gdscript
class_name GridSolver extends RefCounted

static func find_shortest_path(model: GridBoardModel, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
    var queue: Array[Vector2i] = [start]
    var visited: Dictionary[Vector2i, bool] = {start: true}
    var parent_map: Dictionary[Vector2i, Vector2i] = {}

    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

    while not queue.is_empty():
        var current: Vector2i = queue.pop_front()
        if current == goal:
            return _reconstruct_path(parent_map, start, goal)

        for d in dirs:
            var neighbor := current + d
            if not visited.get(neighbor, false) and not model.is_cell_obstructed(neighbor):
                visited[neighbor] = true
                parent_map[neighbor] = current
                queue.append(neighbor)

    return [] # Unsolvable / unreachable

static func _reconstruct_path(parents: Dictionary[Vector2i, Vector2i], start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
    var path: Array[Vector2i] = []
    var cur := goal
    while cur != start:
        path.append(cur)
        cur = parents[cur]
    path.reverse()
    return path
```
