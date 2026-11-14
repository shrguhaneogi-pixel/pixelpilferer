# Input Handling, Interaction Timing, and Collision Rules

## 1. Input Processing Hierarchy

Godot handles input through an ordered notification chain:

```text
[Input Event]
     │
     ▼
[Control Nodes] ───► _gui_input() (Consumed by UI, HUD, or Dialogs)
     │ (If unhandled)
     ▼
[_unhandled_input()] ──► Gameplay Controllers & Movement
     │ (If unhandled)
     ▼
[_unhandled_key_input()] ──► Shortcut Keys & Dev Consoles
```

### Best Practice
Always handle gameplay controls in `_unhandled_input(event: InputEvent)` so that opening an in-game pause menu or dialogue box automatically intercepts inputs without requiring manual input-disabling flags across all actors.

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"move_up"):
        _handle_input_direction(Vector2i.UP)
    elif event.is_action_pressed(&"move_down"):
        _handle_input_direction(Vector2i.DOWN)
    elif event.is_action_pressed(&"move_left"):
        _handle_input_direction(Vector2i.LEFT)
    elif event.is_action_pressed(&"move_right"):
        _handle_input_direction(Vector2i.RIGHT)
    elif event.is_action_pressed(&"interact"):
        _handle_interact()
    elif event.is_action_pressed(&"undo"):
        _handle_undo()
```

---

## 2. Responsive Input Buffering

Players frequently press movement keys slightly before an ongoing movement tween completes. Dropping these inputs feels unresponsive ("sticky controls"). Instead, buffer the latest input with an expiration timer:

```gdscript
class_name InputBuffer extends RefCounted

var buffered_direction: Vector2i = Vector2i.ZERO
var buffer_time_remaining: float = 0.0
const BUFFER_WINDOW: float = 0.12 # 120ms buffer

func push_input(dir: Vector2i) -> void:
    buffered_direction = dir
    buffer_time_remaining = BUFFER_WINDOW

func update(delta: float) -> void:
    if buffer_time_remaining > 0.0:
        buffer_time_remaining -= delta
        if buffer_time_remaining <= 0.0:
            buffered_direction = Vector2i.ZERO

func consume_input() -> Vector2i:
    if buffer_time_remaining > 0.0:
        var dir := buffered_direction
        buffered_direction = Vector2i.ZERO
        buffer_time_remaining = 0.0
        return dir
    return Vector2i.ZERO
```

---

## 3. Logical Collision Rules

In a grid game, collisions are mathematical queries on the board state, never physics shape queries (`Area2D`, `CollisionShape2D`).

### Static vs Dynamic Collisions
```gdscript
func can_occupy(cell: Vector2i) -> bool:
    # 1. Bounds check
    if not is_inside_grid(cell):
        return false

    # 2. Static terrain / obstacle check
    if is_wall(cell):
        return false

    # 3. Dynamic entity check
    if get_entity_at(cell) != null:
        return false

    return true
```

### Recursive Push Mechanics (e.g. Sokoban / Blocks)
```gdscript
func try_push(actor_cell: Vector2i, dir: Vector2i) -> bool:
    var target_cell := actor_cell + dir
    var block := get_pushable_at(target_cell)

    if block == null:
        return false # No pushable object

    var beyond_cell := target_cell + dir
    if not can_occupy(beyond_cell):
        return false # Blocked behind

    # Move block first, then allow actor to move
    move_entity(block, beyond_cell)
    return true
```

### Facing-Cell Interactions
Interactions target the cell immediately in front of the actor's facing direction:
```gdscript
func interact_facing() -> void:
    var target_cell := current_cell + facing_direction
    var interactable := get_interactable_at(target_cell)
    if interactable != null:
        interactable.trigger_interaction(self)
```
