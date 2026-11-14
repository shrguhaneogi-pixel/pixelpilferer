# Godot 4.7 Scene Composition, Resources, Signals, and Node Lifecycle

## 1. Node Lifecycle Order

In Godot 4.7, node execution follows a strict deterministic lifecycle:

```text
[Instantiation]
  └── _init()                  # Object memory allocated; no tree access yet
[Scene Tree Insertion]
  ├── _enter_tree()            # Parent enters before children (top-down)
  └── _ready()                 # Children ready before parents (bottom-up)
[Active Frame Loop]
  ├── _physics_process(delta)  # Fixed tick rate (default: 60Hz), deterministic gameplay physics
  ├── _process(delta)          # Variable frame rate, visual updates / interpolations
  └── _unhandled_input(event)  # Input event dispatching (post-GUI)
[Scene Tree Exit]
  ├── _exit_tree()             # Cleanup before node departure (bottom-up)
  └── [Object Free]            # queue_free() clears memory at end of frame
```

### Critical Rules
- **Parent vs Child Ready Order:** A node cannot access its parent's initialized state during `_ready()` because child `_ready()` runs **before** parent `_ready()`.
- **Top-Down Downward Access, Bottom-Up Signal Emission:**
  - Nodes may call methods on their immediate direct children (`$ChildNode.method()`).
  - Nodes **must never** reach upward directly (`get_parent().get_parent().do_something()`). Upward communication must strictly use **Signals**.

---

## 2. Signals & Callables (Godot 4.x Standard)

In Godot 4.7, signals are first-class language objects. Never use Godot 3 string-based signal APIs.

### Signal Definition & Emission
```gdscript
class_name GridEntity extends Node2D

# Explicitly type signal parameters
signal moved(from_cell: Vector2i, to_cell: Vector2i)
signal defeated(entity: GridEntity)

func execute_step(target: Vector2i) -> void:
    var prev: Vector2i = grid_position
    grid_position = target
    moved.emit(prev, target)
```

### Signal Connection Patterns
```gdscript
func _ready() -> void:
    # 1. Direct Callable connection (compile-time checked)
    moved.connect(_on_moved)

    # 2. One-shot connection (auto-disconnects after first emission)
    defeated.connect(_on_defeated, CONNECT_ONE_SHOT)

    # 3. Deferred connection (queued to end of frame)
    moved.connect(_on_moved_deferred, CONNECT_DEFERRED)

    # 4. Safe disconnection check
    if not moved.is_connected(_on_moved):
        moved.connect(_on_moved)

func _on_moved(from_cell: Vector2i, to_cell: Vector2i) -> void:
    # Handle response
    pass
```

---

## 3. Custom Resources vs Nodes

| Characteristic | `Resource` (`RefCounted`) | `Node` / `Node2D` |
| :--- | :--- | :--- |
| **Primary Role** | Data schema, stat definitions, pure game state | Scene tree representation, rendering, transforms |
| **Lifecycle** | Reference-counted; freed when references drop to 0 | Tree-managed; explicitly freed via `queue_free()` |
| **Sharing** | Shared across instances by default | Always unique instances |
| **Scene Tree** | Does not exist in the scene tree | Attached to SceneTree |

### Defining a Custom Resource
```gdscript
class_name LevelData extends Resource

@export var level_id: String = ""
@export var level_name: String = "Untitled"
@export var grid_size: Vector2i = Vector2i(16, 16)
@export var par_turns: int = 20
@export var initial_tiles: Array[Vector2i] = []

# When mutable per-instance state is needed:
# Use Resource.duplicate() or enable resource_local_to_scene in inspector
```

### Injecting Resources into Components
```gdscript
class_name GuardController extends Node2D

@export var patrol_route: LevelData
@export var move_speed: float = 4.0
```

---

## 4. Composition Over Inheritance

Avoid deep node inheritance trees (e.g., `Node2D -> Entity -> Actor -> Enemy -> Guard -> PatrolGuard`). Instead, use decoupled component nodes or RefCounted controllers:

```text
Guard (CharacterBody2D / Node2D)
├── Visuals (Sprite2D + AnimationPlayer)
├── GridMover (Component Node / Script)
├── VisionCone (Component Node / Area2D or Raycasts)
└── HealthComponent (Resource or Child Node)
```

### Component Communication Pattern
1. The parent orchestrator holds references to its components.
2. Components emit signals when their internal state changes.
3. The parent or controller mediates cross-component effects.
