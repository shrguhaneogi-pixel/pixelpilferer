# Pixel Pilferer — System Architecture

## 1. Architectural Overview

Pixel Pilferer uses a **Strict Model-View Separation** architecture. The logical simulation operates independently of rendering, framerate, and SceneTree nodes.

```text
       ┌────────────────────────┐
       │   User / Input Event   │
       └───────────┬────────────┘
                   │  _unhandled_input()
                   ▼
       ┌────────────────────────┐
       │     GameController     │
       └───────────┬────────────┘
                   │  Action (MOVE_*, INTERACT_*)
                   ▼
┌──────────────────────────────────────────────┐
│           Pure Domain Model (Model)          │
│ - BoardModel: Authoritative state & actions  │
│ - BoardState: Immutable cell grid snapshot   │
│ - GameRules: State transition function       │
│ - HistoryManager: Snapshot-based Undo / Redo │
│ - PuzzleSolver: A* & BFS Solvability Engine  │
└──────────────┬───────────────────────────────┘
               │  Signals / State Events
               ▼
┌──────────────────────────────────────────────┐
│             View Layer (View/Godot)          │
│ - BoardRenderer (TileMapLayers & Entities)   │
│ - TileMapLayers: Void, Floor, Sockets, Walls │
│ - PlayerView (Sprite2D + Tween)              │
│ - BlockView (Sprite2D + Tween)               │
│ - AudioService (Procedural SFX & Volume)     │
│ - PixelCamera (Integer-rounded 2D Camera)    │
└──────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│                Services Layer                │
│ - LevelRepository: Level JSON Loading/Schema │
│ - ProgressService: Save data, high scores    │
└──────────────────────────────────────────────┘
```

---

## 2. Domain Model Specifications

### Coordinates & Directions
- All spatial coordinates are `Vector2i`.
- Four canonical cardinal directions:
  - `NORTH = Vector2i(0, -1)`
  - `EAST  = Vector2i(1, 0)`
  - `SOUTH = Vector2i(0, 1)`
  - `WEST  = Vector2i(-1, 0)`

### Enumerations & Types
```gdscript
enum ActionType {
    MOVE_NORTH,
    MOVE_EAST,
    MOVE_SOUTH,
    MOVE_WEST,
    INTERACT_NORTH,
    INTERACT_EAST,
    INTERACT_SOUTH,
    INTERACT_WEST,
    UNDO,
    RESTART
}

enum TileType {
    EMPTY,       # Boundary / unmapped
    FLOOR,       # Standard walkable surface
    VOID,        # Impassable pit until bridged
    WALL         # Permanent immutable barrier
}

enum BlockColor {
    NEUTRAL,
    CYAN,
    AMBER,
    MAGENTA,
    EMERALD
}
```

### Deterministic State Snapshot (`BoardState`)
Every turn creates an immutable snapshot of:
- `turn: int`
- `player_cell: Vector2i`
- `player_facing: Vector2i`
- `carried_block: Dictionary` (or empty if not carrying)
- `blocks: Dictionary[Vector2i, Dictionary]` (maps grid cell to block data: `id`, `color`, `is_bridge`)
- `sockets: Dictionary[Vector2i, int]` (maps grid cell to required `BlockColor`)
- `exit_cell: Vector2i`
- `is_completed: bool`

### Single Authoritative Transition Function (`GameRules`)
Given $(S_t, Action)$, returns:
- `success: bool`
- `next_state: BoardState`
- `event: StringName` (`&"player_moved"`, `&"block_stolen"`, `&"block_placed"`, `&"bridge_created"`, `&"socket_activated"`, `&"level_cleared"`, `&"blocked"`)

### Reversibility (`HistoryManager`)
- Stores an undo stack of `BoardState` instances.
- Pushing a new state clears the redo stack.
- Undoing returns the immediate previous state $S_{t-1}$.
- Restart clears the stack back to $S_0$.

---

## 3. View & Scene Architecture

### Scene Node Hierarchy
```text
LevelScene (Node2D)
├── Camera2D (PixelPerfectCamera)
├── TileMapLayer_Void (TileMapLayer, z_index: -2)
├── TileMapLayer_Floor (TileMapLayer, z_index: -1)
├── TileMapLayer_Sockets (TileMapLayer, z_index: 0)
├── TileMapLayer_Bridges (TileMapLayer, z_index: 1)
├── TileMapLayer_Walls (TileMapLayer, z_index: 2)
├── EntityContainer (Node2D, y_sort_enabled: true, z_index: 3)
│   ├── ExitPortalView (Node2D)
│   ├── BlockContainer (Node2D)
│   └── PlayerView (Node2D)
├── HUD (CanvasLayer)
│   ├── MoveCounter (Label)
│   ├── CarriedSlot (TextureRect)
│   └── PromptControls (HBoxContainer)
└── AudioManager (Node)
```

### TileMapLayer Standard
In adherence with Godot 4.7 standards:
- Monolithic `TileMap` is prohibited.
- Five dedicated `TileMapLayer` nodes are used with exact z-indices.
- Cells are indexed by integer grid positions `(x, y)`.

### View Interpolation & Visual Lag
- Logical state updates in 0 ms.
- Entity views tween from previous world coordinates to new world coordinates over `0.10s` (TRANS_QUAD, EASE_OUT).
- If input arrives before tween completes, the tween is immediately completed/killed to ensure responsive frame-independent input handling.
- When an Undo occurs, entity views snap immediately to the restored position.

---

## 4. Testing & Verification Architecture

1. **Headless Godot Test Runner:**
   - Script: `res://tests/test_runner.gd`
   - Executes domain tests, rule tests, invariant tests, and solvability checks.
   - Exits with `quit(0)` on pass, `quit(1)` on error.
2. **Dual-Harness Architecture:**
   - Pure GDScript implementation in `scripts/core/`.
   - Dual-verification script executable by Python or CLI to verify all 20 puzzle levels immediately regardless of host runtime status.
3. **BFS Puzzle Solvability Engine (`PuzzleSolver`):**
   - Breadth-first search exploring the state space of each level.
   - Computes shortest solution path, verifies minimum turns, and ensures no level is unsolvable or trivial.
