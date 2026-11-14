# Performance, Memory, and Resource Management

## 1. Preventing Memory Leaks in `RefCounted`

`RefCounted` objects automatically free themselves when no variables hold references to them. However, **circular references** prevent reference counts from ever reaching zero.

### Circular Reference Pitfall
```gdscript
# Leaky Pattern:
class NodeA extends RefCounted:
    var neighbor: NodeB

class NodeB extends RefCounted:
    var neighbor: NodeA
# If NodeA and NodeB point to each other, neither will ever be freed!
```

### Solution: Use `weakref()` or Explicit Teardown
```gdscript
class NodeB extends RefCounted:
    var _neighbor_weak: WeakRef

    func set_neighbor(target: RefCounted) -> void:
        _neighbor_weak = weakref(target)

    func get_neighbor() -> RefCounted:
        if _neighbor_weak != null:
            return _neighbor_weak.get_ref()
        return null
```

---

## 2. Node Lifecycle & Disposal (`queue_free`)

- Never call `free()` directly on a node while the scene tree is executing. Always use `queue_free()`.
- `queue_free()` schedules node deletion for the end of the current frame.
- Any references to the node in external arrays or dictionaries must be erased:

```gdscript
func remove_actor(actor: Node2D) -> void:
    var cell: Vector2i = actor.grid_cell
    if active_actors.has(cell):
        active_actors.erase(cell)
    actor.queue_free()
```

---

## 3. Resource Management (`preload` vs `load` vs `duplicate`)

| Method | Behavior | Usage |
| :--- | :--- | :--- |
| `preload("res://...")` | Loaded at script compile time. Zero runtime disk hit. | Const assets, base scenes, core resources. |
| `load("res://...")` | Loaded on demand at runtime. | Dynamic level data, optional DLC/assets. |
| `resource.duplicate()` | Creates an independent unique deep copy. | Mutable per-instance stats or runtime level states. |

---

## 4. Draw Call Minimization & 2D Performance

For high-performance 2D rendering:
1. **Texture Atlases:** Combine character and terrain sprites into shared sprite sheets. Every texture switch forces a new draw call.
2. **TileMapLayer Batching:** `TileMapLayer` automatically batches tiles that share the same texture into a single draw call per quadrant.
3. **Avoid Unnecessary Transparency:** Avoid large full-screen overlapping transparent sprites that increase fill rate overhead.

### Monitoring Performance Metrics
Inspect runtime performance in debug builds:
```gdscript
func log_performance_stats() -> void:
    var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    var mem_static := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024 * 1024) # MB
    var fps := Performance.get_monitor(Performance.TIME_FPS)
    print("FPS: %d | Draw Calls: %d | Static Mem: %d MB" % [fps, draw_calls, mem_static])
```
