# Deterministic Grid Architecture & State Separation

## 1. The Core Architectural Axiom

> **The logical board state updates instantaneously and deterministically; rendering and animations (tweens, sprites, particles) merely lag behind to visualize the transition.**

```text
[Input Event] ──► [Controller]
                       │
                       ▼
             [Logical Game State] (RefCounted / Pure Data)
             - Checks rules & collisions (Vector2i)
             - Updates state instantly: (S_t, Action) -> S_{t+1}
             - Emits state change signals
                       │
            ┌──────────┴──────────┐
            ▼                     ▼
     [View / Renderer]     [Audio / Effects]
     - Node2D / Sprites    - AudioStreamPlayer
     - Starts Tweens       - Plays SFX
     - Visual interpolation
```

---

## 2. Invariants for Deterministic Logic

1. **Integer Coordinate Authority:**
   All gameplay calculations, collision checks, distance metrics, and entity placements must use integer coordinates (`Vector2i`). Floating-point node positions (`position.x`, `position.y`) are strictly presentation details.
2. **Decoupled from Delta Time:**
   Turn-based state logic must never depend on `_process(delta)` or `_physics_process(delta)`. Float `delta` introduces cumulative rounding errors, frame-rate dependency, and non-deterministic behavior.
3. **No Visual State Polling:**
   Never check `animation_player.is_playing()`, `tween.is_running()`, or `sprite.frame` to decide if a game action is valid or if a turn has completed.

---

## 3. Implementation: Pure State Model

Keep the logical state clean, standalone, and testable without requiring the Godot SceneTree:

```gdscript
class_name GridBoardModel extends RefCounted

signal entity_moved(entity_id: int, from_cell: Vector2i, to_cell: Vector2i)
signal entity_blocked(entity_id: int, target_cell: Vector2i)

var dimensions: Vector2i = Vector2i(10, 10)
var solid_tiles: Dictionary[Vector2i, bool] = {}
var entity_cells: Dictionary[int, Vector2i] = {}
var cell_occupants: Dictionary[Vector2i, int] = {}

func initialize(size: Vector2i, walls: Array[Vector2i]) -> void:
    dimensions = size
    solid_tiles.clear()
    for wall in walls:
        solid_tiles[wall] = true

func register_entity(entity_id: int, start_cell: Vector2i) -> bool:
    if is_cell_obstructed(start_cell):
        return false
    entity_cells[entity_id] = start_cell
    cell_occupants[start_cell] = entity_id
    return true

func is_cell_obstructed(cell: Vector2i) -> bool:
    if cell.x < 0 or cell.y < 0 or cell.x >= dimensions.x or cell.y >= dimensions.y:
        return true # Out of bounds
    if solid_tiles.get(cell, false):
        return true # Solid terrain
    if cell_occupants.has(cell):
        return true # Occupied by another entity
    return false

func try_move_entity(entity_id: int, direction: Vector2i) -> bool:
    if not entity_cells.has(entity_id):
        return false

    var current_cell: Vector2i = entity_cells[entity_id]
    var target_cell: Vector2i = current_cell + direction

    if is_cell_obstructed(target_cell):
        entity_blocked.emit(entity_id, target_cell)
        return false

    # Instantaneous logical update
    cell_occupants.erase(current_cell)
    cell_occupants[target_cell] = entity_id
    entity_cells[entity_id] = target_cell

    entity_moved.emit(entity_id, current_cell, target_cell)
    return true
```

---

## 4. The View Adapter Pattern

The View (a `Node2D` with `Sprite2D`) listens to the Model's signals and animates smoothly without blocking state transitions:

```gdscript
class_name EntityView extends Node2D

@export var tile_size: int = 16
@onready var sprite: Sprite2D = $Sprite2D

var _active_tween: Tween

func bind_to_model(model: GridBoardModel, entity_id: int, initial_cell: Vector2i) -> void:
    position = Vector2(initial_cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)
    model.entity_moved.connect(_on_entity_moved.bind(entity_id))

func _on_entity_moved(from_cell: Vector2i, to_cell: Vector2i, target_id: int) -> void:
    var target_world_pos := Vector2(to_cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)

    if _active_tween and _active_tween.is_valid():
        _active_tween.kill()

    _active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _active_tween.tween_property(self, ^"position", target_world_pos, 0.12)
```
