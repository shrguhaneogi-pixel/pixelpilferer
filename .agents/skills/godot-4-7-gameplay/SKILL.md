---
name: godot-4-7-gameplay
description: >-
  Reliable, version-aware engineering guidance for developing, testing, and exporting
  native 2D grid-based games using Godot 4.7.2 and GDScript. Use when creating or modifying
  scenes, nodes, resources, signals, TileMapLayers, deterministic gameplay state, undo systems,
  pixel-art rendering, tweens, headless tests, or desktop/web export presets in Pixel Pilferer.
---

# Godot 4.7.2 2D Gameplay Engineering Guide

A project-specific engineering skill for building, testing, and exporting deterministic 2D grid-based games in Godot 4.7.2 and GDScript.

---

## 1. Mandatory Safeguards & Invariants

All gameplay implementations in Pixel Pilferer must adhere to these non-negotiable rules:

1. **Verify Unfamiliar APIs:** Never invent nonexistent nodes, properties, methods, or signals. Verify methods against Godot 4.7 documentation or local CLI help.
2. **Avoid Deprecated APIs:** Use `TileMapLayer` nodes instead of legacy monolithic `TileMap`. Use first-class `Callable` signals (`signal.connect(callable)`) instead of string-based connects.
3. **Decouple Logical State from Rendering:** **Logical board state updates instantaneously and deterministically.** Never poll `Sprite2D`, `AnimationPlayer.is_playing()`, `Tween.is_running()`, or physics bodies (`move_and_slide`) to validate game state or turns.
4. **No Third-Party Bloat:** Never introduce third-party libraries or plugins unless strictly necessary and proven. Prioritize native GDScript solutions.
5. **Real Test Verification:** Require real command execution output and exit codes before claiming tests passed. Never claim tests passed from hallucinated results.
6. **Repeatable Regression Tests:** Stateful gameplay mechanics (movement, push, collision, undo, win/loss) must have automated headless test coverage.
7. **KISS Architecture:** Avoid unnecessary architectural layers. Prefer clean composition with `RefCounted` data models and `Node2D` view adapters.
8. **Preserve Repository Integrity:** Commit verified local changes without pushing to remote until approved.

---

## 2. Progressive Disclosure Reference Map

For detailed architectural patterns and code samples, consult the specialized reference guides:

| Domain | Focus | Reference Document |
| :--- | :--- | :--- |
| **Lifecycle & Nodes** | Scene composition, parent/child ready order, signals, custom Resources | [scene_and_lifecycle.md](./references/scene_and_lifecycle.md) |
| **GDScript Standards** | Strict static typing, `StringName`, enums, class structure | [gdscript_conventions.md](./references/gdscript_conventions.md) |
| **TileMapLayer** | Multi-layer setup, cell querying/mutation, TileSet custom data, Y-sort | [tilemaplayer_and_rendering.md](./references/tilemaplayer_and_rendering.md) |
| **Grid Architecture** | Deterministic coordinates (`Vector2i`), state transitions, Model-View decoupling | [grid_architecture_and_state.md](./references/grid_architecture_and_state.md) |
| **Input & Collision** | `_unhandled_input`, input buffering, grid collision queries, push/slide | [input_and_collision.md](./references/input_and_collision.md) |
| **Pixel Art & Scaling** | Viewport resolution, integer scaling, pixel snapping, pixel-perfect camera | [pixel_art_and_scaling.md](./references/pixel_art_and_scaling.md) |
| **Tweens & Anim** | Godot 4 Tween binding, collision-free interruption, safe `await` guards | [tweens_and_animations.md](./references/tweens_and_animations.md) |
| **Undo & Solvers** | Command pattern, state snapshots, view resync, BFS level solvability | [undo_and_puzzle_solvers.md](./references/undo_and_puzzle_solvers.md) |
| **Testing & CI** | Headless CLI test runners (`SceneTree`), assertions, exit codes | [testing_and_headless.md](./references/testing_and_headless.md) |
| **Export Targets** | Windows Desktop & HTML5 Web export, single-thread Web, audio unlock | [export_targets.md](./references/export_targets.md) |
| **Performance & Mem** | `RefCounted` circular leak prevention, `queue_free`, draw calls | [performance_and_memory.md](./references/performance_and_memory.md) |

---

## 3. Core Technical Summary

### A. Scene Composition & Lifecycle
- `_enter_tree()` executes top-down (parent first); `_ready()` executes bottom-up (children first).
- Use **Signals** for upward notifications (`child -> parent`) and **direct method calls** for downward instructions (`parent -> child`).
- Separate data definitions into `Resource` (`RefCounted`) classes with `@export` properties.

### B. GDScript 4.7 Conventions
- Enforce strict typing on all variables and functions (`var step: int = 1`, `func move(target: Vector2i) -> bool:`).
- Use `StringName` (`&"..."`) for action names, animation tags, and node groups to avoid string allocation overhead.
- Use `Vector2i` and `Rect2i` for all logical grid operations.

### C. TileMapLayer (Godot 4.7 Native)
- Monolithic `TileMap` is deprecated. Use individual `TileMapLayer` nodes (e.g. `GroundLayer`, `ObstacleLayer`).
- Query cells directly on the layer: `layer.get_cell_source_id(coords)`, `layer.local_to_map(pos)`.
- Store semantic tile properties (e.g., `walkable: bool`) inside TileSet Custom Data Layers instead of hardcoded coordinates.

### D. Deterministic Turn-Based Grid Architecture
- All gameplay state exists in integer coordinates: `Vector2i(x, y)`.
- Never use float positions or physics collisions for turn-based game logic.
- Model (`RefCounted`) transitions state immediately: $(S_t, \text{Action}) \to S_{t+1}$.
- View (`Node2D`, `Sprite2D`) animates to the new state asynchronously via `Tween`.

### E. Input Handling & Buffering
- Process player actions in `_unhandled_input(event: InputEvent)` to allow UI elements to consume events first.
- Implement an `InputBuffer` (window: ~120ms) so rapid keystrokes during an active movement tween are queued rather than dropped.

### F. Pixel Art & Integer Scaling
- Set `display/window/stretch/mode = "canvas_items"` and `scale_mode = "integer"`.
- Set `rendering/textures/canvas_textures/default_texture_filter = 0` (Nearest).
- Enable `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel` to eliminate subpixel jitter.
- Smooth camera movement must round final coordinates to whole pixels (`global_position = desired.round()`).

### G. Safe Tweens & Interruption
- Always kill an active tween before starting a new one on the same node:
  ```gdscript
  if _tween and _tween.is_valid():
      _tween.kill()
  _tween = create_tween()
  ```
- Guard post-`await` logic: check `if not is_inside_tree(): return`.

### H. Undo Systems & State Restoration
- Record reversible `Command` objects or immutable `BoardSnapshot` instances on an undo stack.
- When an undo is executed, update the model instantly, then notify the view to snap/interpolate to the restored positions.

### I. Headless Testing & Verification
- Execute tests via Godot CLI without GUI:
  ```bash
  godot --headless --script res://tests/test_runner.gd
  ```
- Test runner scripts extend `SceneTree`, execute assertions in `_init()`, and call `quit(0)` on pass or `quit(1)` on fail.

### J. Desktop & HTML5 Export
- Single-threaded Web export (`threads/thread_model=0`) avoids strict `COOP`/`COEP` server header requirements on static hosts.
- Present a user-interaction screen ("Click to Start") to unlock the browser `AudioContext`.

---

## 4. Development & Verification Workflow

```text
[1. Design Model] ────► [2. Unit Test Model] ───► [3. Implement View] ───► [4. End-to-End Test]
Pure RefCounted         Headless CLI test        Node2D / TileMapLayer    Rendered Playtest /
Vector2i logic          (godot --headless)       Tweens & Sprites         Export Validation
```

### Pull Request & Implementation Checklist
- [ ] **Typing:** All new scripts have static typing on every variable, parameter, and return type.
- [ ] **State Decoupling:** No gameplay logic depends on `Tween`, `AnimationPlayer`, or float positions.
- [ ] **TileMapLayer:** Uses dedicated `TileMapLayer` nodes; zero calls to legacy `TileMap` methods.
- [ ] **Pixel Snapping:** Camera and sprite coordinates do not introduce subpixel jitter.
- [ ] **Tween Safety:** All newly created tweens kill existing tweens and verify tree presence post-`await`.
- [ ] **Automated Tests:** Headless test runner executes cleanly with return code 0.
- [ ] **No Dead Code:** Unused signals, dead variables, and legacy debug prints removed.

---

## 5. Helper Utilities

- **Headless Test Template:** [headless_test_template.gd](./scripts/headless_test_template.gd)
- **Environment Audit Script:** [verify_environment.ps1](./scripts/verify_environment.ps1)
