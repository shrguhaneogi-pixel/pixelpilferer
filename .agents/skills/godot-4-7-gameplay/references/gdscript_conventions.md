# GDScript Typing, Data Structures, and Conventions (Godot 4.7)

## 1. Strict Static Typing Rules

To guarantee runtime safety, compile-time error detection, and optimal execution performance in Godot 4.7, strict static typing is mandatory.

### Type Declarations
```gdscript
# 1. Explicit variable typing
var turn_count: int = 0
var player_name: String = "Pilferer"
var is_active: bool = true

# 2. Inferred typing (only when RHS type is self-evident)
var start_pos := Vector2i(0, 0)
var bounding_box := Rect2i(0, 0, 16, 16)

# 3. Typed Arrays and Dictionaries
var path_history: Array[Vector2i] = []
var tile_occupants: Dictionary[Vector2i, Node2D] = {}

# 4. Strict function signatures
func calculate_next_cell(current: Vector2i, dir: Vector2i) -> Vector2i:
    return current + dir

func can_traverse(target: Vector2i) -> bool:
    return target not in tile_occupants
```

### Prohibited Typing Practices
- **Never leave gameplay variables untyped** (`var x = 5` without `:` or `:=`).
- **Never use `Variant` in hot loops** unless interfacing with generic serialization.
- **Never rely on dynamic method dispatch** (`call("method_name")`); use direct typed method invocations or Callables.

---

## 2. StringName (`&"..."`) Usage

In Godot 4.7, `StringName` is an immutable, globally unique string optimized for fast comparisons and zero-allocation hash lookups.

Always use `StringName` literals for:
1. Input actions: `Input.is_action_just_pressed(&"move_up")`
2. Animation names: `animation_player.play(&"walk_north")`
3. Node names and groups: `is_in_group(&"guards")`
4. Custom metadata or properties: `get_meta(&"tile_cost")`

```gdscript
const ACTION_UP: StringName = &"move_up"
const ACTION_DOWN: StringName = &"move_down"
const GROUP_INTERACTABLE: StringName = &"interactables"
```

---

## 3. Typed Enums and Match Expressions

Use typed enums for state machines, directions, and action types:

```gdscript
enum Direction {
    NORTH,
    SOUTH,
    EAST,
    WEST,
}

const DIRECTION_VECTORS: Dictionary[Direction, Vector2i] = {
    Direction.NORTH: Vector2i(0, -1),
    Direction.SOUTH: Vector2i(0, 1),
    Direction.EAST: Vector2i(1, 0),
    Direction.WEST: Vector2i(-1, 0),
}

func direction_to_vector(dir: Direction) -> Vector2i:
    return DIRECTION_VECTORS.get(dir, Vector2i.ZERO)

func parse_direction(dir: Direction) -> StringName:
    match dir:
        Direction.NORTH:
            return &"north"
        Direction.SOUTH:
            return &"south"
        Direction.EAST:
            return &"east"
        Direction.WEST:
            return &"west"
        _:
            return &"idle"
```

---

## 4. Class Structure and Naming Conventions

Follow official GDScript order within each script:

```gdscript
class_name PlayerMover extends Node2D

## Docstring explaining the purpose of PlayerMover.

# 1. Signals
signal step_completed(cell: Vector2i)

# 2. Enums
enum MoveState { IDLE, MOVING, BLOCKED }

# 3. Constants
const STEP_DURATION: float = 0.15

# 4. @export Variables
@export var grid_board: NodePath
@export var allow_diagonal: bool = false

# 5. Public / Private Variables
var current_cell: Vector2i = Vector2i.ZERO
var _current_state: MoveState = MoveState.IDLE
var _step_tween: Tween

# 6. Built-in Virtual Methods (_init, _enter_tree, _ready, _process, etc.)
func _ready() -> void:
    _setup_initial_cell()

# 7. Public Methods
func request_step(dir: Direction) -> bool:
    if _current_state != MoveState.IDLE:
        return false
    return _execute_step(dir)

# 8. Private / Internal Methods
func _setup_initial_cell() -> void:
    pass

func _execute_step(dir: Direction) -> bool:
    return true
```
