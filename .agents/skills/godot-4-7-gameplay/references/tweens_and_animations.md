# Tween and AnimationPlayer Lifecycle Safety

## 1. Godot 4.7 Tween Architecture

In Godot 4, `Tween` is an object created via `create_tween()`. It is bound by default to the node that created it, meaning it automatically pauses when the node pauses and is destroyed when the node exits the scene tree.

### The Overlapping Tween Hazard
Starting a new tween on a property while an older tween is actively animating the same property creates conflicting values and jitter.

### Robust Tween Pattern
```gdscript
class_name MoverVisuals extends Node2D

var _active_tween: Tween

func move_to_pos(target_pos: Vector2, duration: float = 0.15) -> void:
    # 1. Kill any prior running tween safely
    if _active_tween and _active_tween.is_valid():
        _active_tween.kill()

    # 2. Instantiate fresh tween bound to this node
    _active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    # 3. Animate property
    _active_tween.tween_property(self, ^"position", target_pos, duration)
```

---

## 2. Safe `await` Patterns

A common source of engine crashes or orphaned code execution is `await`ing a signal on a node that might be freed before the signal fires.

### Guarding Post-Await Execution
```gdscript
func execute_visual_sequence(target_cell: Vector2i) -> void:
    var tw := create_tween()
    tw.tween_property(self, ^"scale", Vector2(1.2, 0.8), 0.08)
    tw.tween_property(self, ^"scale", Vector2.ONE, 0.08)

    # Await tween completion
    await tw.finished

    # CRITICAL: Verify node is still alive and inside the scene tree
    if not is_inside_tree():
        return

    # Continue post-animation logic
    _on_bounce_completed()
```

---

## 3. AnimationPlayer Best Practices

1. **Decouple Animation from Game State:**
   Never wait for an `AnimationPlayer` animation to end before executing the next logical turn. If an animation is playing when a new turn begins, immediately blend into the new animation or snap to the target frame.
2. **Animation Reset on Interruption:**
   When an action is undone or canceled, reset sprite transforms (scale, rotation, modulate) to their default rest state so lingering frames don't distort future animations.
3. **Use StringName for Animation Keys:**
   ```gdscript
   @onready var anim_player: AnimationPlayer = $AnimationPlayer

   func play_walk(direction_name: StringName) -> void:
       var anim_key: StringName = &"walk_" + direction_name
       if anim_player.has_animation(anim_key):
           anim_player.play(anim_key)
   ```
