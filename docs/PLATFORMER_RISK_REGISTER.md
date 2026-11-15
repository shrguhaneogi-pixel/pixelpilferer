# PIXEL PILFERER — PLATFORMER RISK REGISTER & MITIGATION MATRIX

This document registers critical technical, physics, and gameplay risks associated with transitioning PIXEL PILFERER into a 2D side-scrolling puzzle-platformer, along with verified mitigation strategies.

---

## 1. Risk Register Matrix

| ID | Risk Description | Severity | Probability | Impact Area | Mitigation & Architectural Defense |
| :---: | :--- | :---: | :---: | :---: | :--- |
| **R-01** | **Tile Collision Synchronization Lag:** Godot's `TileMapLayer` flushes collision updates on a deferred basis or at the end of physics ticks, which can cause newly placed blocks to have missing collisions for 1 frame. | **CRITICAL** | HIGH | Dynamic Platforming | **Defense:** Use dedicated `StaticBody2D` instances with `CollisionShape2D` for dynamic movable blocks, managed by `PlatformTileManager`. This guarantees synchronous, immediate physics collision registration on the exact frame of placement. |
| **R-02** | **Self-Collision Trap (Block Spawn Overlap):** Placing a block into a tile cell that overlaps Pip's own collision bounds could trap Pip inside solid geometry. | **CRITICAL** | MEDIUM | Glove Placement | **Defense:** Strict spatial bounds check before executing `place()`. If the proposed 16×16 tile bounding box `Rect2(tile_pos * 16, Vector2(16, 16))` intersects Pip's global collision box, placement is strictly rejected with a buzz sound (`sfx_bump`). |
| **R-03** | **Floor Support Removal Discontinuity:** Pip stands on a movable block and uses the Glove to steal it downward. If not handled cleanly, Pip could glitch through floors or freeze. | **HIGH** | MEDIUM | Physics Fall | **Defense:** When a block beneath Pip is stolen, its collision shape is disabled immediately. On the very next `_physics_process()` tick, `is_on_floor()` naturally evaluates to `false`, and gravity accelerates Pip downward seamlessly. |
| **R-04** | **Subpixel Camera Jitter:** Floating-point camera smoothing at a 640×360 base resolution can cause pixel shimmering, text trembling, and seam artifacts between 16×16 tiles. | **MEDIUM** | HIGH | Visual Quality | **Defense:** Camera smoothing runs in float space, but the camera's final rendered position is rounded to integer pixel coordinates (`camera.position = desired_pos.round()`). Furthermore, `project.godot` enforces `snap_2d_transforms_to_pixel` and `snap_2d_vertices_to_pixel`. |
| **R-05** | **Ledge Snagging / Corner Catching:** Flat rectangular character collision boxes frequently snag on tile corners when jumping up against walls. | **HIGH** | HIGH | Movement Feel | **Defense:** Use a slightly chamfered or rounded collision shape (e.g. `RectangleShape2D` with width 10px, height 14px centered in a 16px tile) with a 2-pixel margin on horizontal sides. Additionally, configure `safe_margin = 0.08` on `CharacterBody2D`. |
| **R-06** | **Ceiling Head Collision Stopping Horizontal Velocity:** In default physics, bonking a ceiling tile abruptly zeroes out all horizontal momentum. | **MEDIUM** | MEDIUM | Jump Traversal | **Defense:** Ensure `move_and_slide()` handles slides along ceiling normals properly without clearing $v_x$. Only zero $v_y$ when `is_on_ceiling()` is true. |
| **R-07** | **Coyote Time / Buffer Exploits:** Rapid button mashing triggering repeated jumps in mid-air. | **HIGH** | MEDIUM | Jump Physics | **Defense:** Coyote time is strictly gated by a one-shot timer (`coyote_timer <= 0.0`), and jumping immediately invalidates both the coyote window and the jump buffer. |
| **R-08** | **Checkpoint State Drift:** Restoring a checkpoint while physics bodies have residual momentum or partially modified block configurations. | **HIGH** | MEDIUM | Level Progression | **Defense:** Checkpoint snapshots capture immutable deep copies of block positions, colors, and socket states. On respawn, player velocity is hard-reset to `Vector2.ZERO`, and all blocks are re-instantiated directly from the checkpoint snapshot. |
| **R-09** | **Physics Discrepancy Across Variable Frame Rates:** Delta fluctuations causing variable jump heights or speeds on 60Hz vs 144Hz monitors. | **CRITICAL** | LOW | Engine Invariant | **Defense:** All character velocity calculations, gravity integration, and `move_and_slide()` calls are strictly isolated to `_physics_process(delta: float)`. Godot's physics tick runs at a constant 60Hz. |
| **R-10** | **Unreachable Level Geometry:** Handcrafted platformer levels having gaps wider than max jump reach or heights exceeding jump peak. | **HIGH** | HIGH | Level Design | **Defense:** Formally bound level design parameters by physics limits ($H_{max} = 40.8\text{ px} \approx 2.5\text{ tiles}$, $R_{max} = 87.1\text{ px} \approx 5.4\text{ tiles}$). Every level is verified by a scripted headless physics traversal test before shipping. |

---

## 2. Dynamic Collision Synchronization Deep Dive

### Problem Statement
In Godot 4.7, mutating `TileMapLayer` via `set_cell()` updates the internal tile visual quadrant, but the PhysicsServer2D quadrant collision maps may undergo deferred quadtree recalculations. If a player places a block directly beneath them or jumps onto it immediately, the collision shape might not exist on the exact sub-tick, resulting in falling through the platform.

### Architectural Solution
For movable fragments that are stolen and placed dynamically during gameplay:
1. We implement `PlatformTileManager` which instantiates lightweight `StaticBody2D` nodes with pre-baked `CollisionShape2D` (16×16 rectangle) and `Sprite2D`.
2. When a fragment is placed, `StaticBody2D.set_collision_layer_value(1, true)` is set immediately, registering directly with `PhysicsServer2D` in the current frame.
3. Static terrain (unbreakable stone walls, ground bedrock) remains on the background `TileMapLayer`, which never mutates during gameplay.

---

## 3. Collision Box Dimension Standards

| Entity | Logical Size | Physics Shape | Dimensions | Collision Layer / Mask |
| :--- | :---: | :---: | :---: | :--- |
| **Pip (Player)** | `16 × 16` px | `RectangleShape2D` | `10 × 14` px | Layer 1 (Player) / Mask 1, 2 |
| **Movable Block** | `16 × 16` px | `RectangleShape2D` | `16 × 16` px | Layer 2 (Terrain/Solid) / Mask 1 |
| **Static Ground** | `16 × 16` px | `TileMapLayer` | `16 × 16` px | Layer 2 (Terrain/Solid) / Mask 1 |
| **Socket** | `16 × 16` px | `Area2D` | `14 × 14` px | Layer 3 (Sockets) / Mask 2 |
| **Exit Portal** | `24 × 32` px | `Area2D` | `16 × 24` px | Layer 4 (Triggers) / Mask 1 |
| **Hazards / Pit** | Variable | `Area2D` | Variable | Layer 5 (Hazards) / Mask 1 |

---

## 4. Verification & Defense Checklist
- [x] Collision safety check implemented in `pixel_glove.gd` before any block placement.
- [x] Synchronous `StaticBody2D` registration verified in Milestone B / C tests.
- [x] Zero-velocity checkpoint respawn confirmed.
- [x] Fixed-step 60Hz physics processing enforced in `player_platformer.gd`.
- [x] Level design bounds ($H \le 2.5$ tiles, $R \le 5.4$ tiles) codified in test suite.
