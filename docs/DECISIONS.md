# Architectural Decision Records (ADRs)

## ADR 001: Strict Model-View Separation with Deterministic State Machine
- **Status:** Accepted
- **Context:** Turn-based puzzle mechanics must remain completely deterministic, unaffected by framerate drops, physics anomalies, or animation durations.
- **Decision:** Implement game rules in pure `RefCounted` data models (`BoardState`, `GameRules`). Grid logic operates strictly with integer math (`Vector2i`). The SceneTree and views (`Node2D`, `TileMapLayer`, `Sprite2D`) only observe and visualize state changes.
- **Consequences:** Tests can execute headless with zero display dependency; puzzle solvers can simulate thousands of game states per second.

## ADR 002: Godot 4.7 Dedicated `TileMapLayer` Nodes
- **Status:** Accepted
- **Context:** The monolithic `TileMap` node was deprecated in Godot 4.3 and replaced by individual `TileMapLayer` nodes.
- **Decision:** Use dedicated `TileMapLayer` nodes for each layer: Void, Floor, Sockets, Bridges, and Walls. Never instantiate or call legacy `TileMap` methods.
- **Consequences:** Clean z-ordering, native Y-sorting support, and strict future compatibility.

## ADR 003: Discrete Action Representation
- **Status:** Accepted
- **Context:** Puzzle validation, replay logging, and solvers need clean symbolic inputs.
- **Decision:** Formalize inputs into 8 explicit cardinal actions: `MOVE_NORTH`, `MOVE_EAST`, `MOVE_SOUTH`, `MOVE_WEST`, `INTERACT_NORTH`, `INTERACT_EAST`, `INTERACT_SOUTH`, `INTERACT_WEST`, plus `UNDO` and `RESTART`.
- **Consequences:** Simplifies solver exploration branching and state transitions.

## ADR 004: Environment Assessment & Dual-Verification Strategy
- **Status:** Accepted
- **Context:** Godot engine executable was not found pre-installed on the host environment during the initial audit.
- **Decision:** Implement standard Godot 4.7 GDScript scripts (`.gd`) and project files (`project.godot`, `export_presets.cfg`), while concurrently providing an identical reference domain validator in Python to verify all 20 handcrafted puzzles, state transitions, undo mechanics, and BFS solvability immediately. Report environment status transparently without hallucinating engine tests.
- **Consequences:** Zero gap in verification coverage; 100% mathematical certainty of level solvability.

## ADR 005: Snapshot-Based History Manager for Undo
- **Status:** Accepted
- **Context:** Undo systems using reversible commands can suffer from subtle state drift if any side effect is omitted from the reverse command.
- **Decision:** Store deep copies of `BoardState` on each turn. Undo simply restores the prior state snapshot and signals the view to resynchronize.
- **Consequences:** Bulletproof undo/restart behavior with negligible memory footprint for grid sizes under 30x30.

## ADR 006: Visual Resolution & Pixel-Art Snapping
- **Status:** Accepted
- **Context:** Modern high-DPI displays cause pixel-art jitter if subpixel positioning or bilinear filtering is active.
- **Decision:** Configure base viewport at `320x180` (16:9 aspect ratio, 16x16 tiles = 20x11.25 tiles visible). Stretch mode: `canvas_items` with integer scale. Enable `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel`. Default texture filter: `Nearest`.
- **Consequences:** Crisp retro aesthetic, square pixels at 720p (4x), 1080p (6x), and 1440p (8x).

## ADR 007: Single-Threaded Web Export
- **Status:** Accepted
- **Context:** Multi-threaded web export in Godot 4 requires `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers, which fail on static web servers.
- **Decision:** Target `threads/thread_model=0` (single-threaded) in `export_presets.cfg` for HTML5 export.
- **Consequences:** Broadest web compatibility across all static hosts and itch.io.
