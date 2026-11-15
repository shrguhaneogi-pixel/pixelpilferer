# PIXEL PILFERER — PLATFORMER TEST PLAN & VERIFICATION GATES

This test plan defines the formal validation strategy for the 2D side-scrolling puzzle-platformer transformation. It replaces top-down discrete grid pathfinding with a rigorous **3-Tier Reachability and Physics Testing Framework**.

---

## 1. The 3-Tier Testing Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    3-TIER VERIFICATION SYSTEM                   │
├─────────────────────────────────────────────────────────────────┤
│ LEVEL 3: PHYSICS-BASED TRAVERSAL                                │
│ • Scripted physics simulation and traversal replay              │
│ • Jump clearance, air velocity, landing on placed platforms    │
│ • Hazard collision, death, checkpoint respawn, exit trigger    │
├─────────────────────────────────────────────────────────────────┤
│ LEVEL 2: DISCRETE BLOCK MANIPULATION                            │
│ • Stealing preconditions: range, capacity limit (1), valid type │
│ • Placing preconditions: empty air, no player overlap, reach    │
│ • Dynamic collision synchronization, floating platform anchor   │
│ • Socket activation, color and rune matching                   │
├─────────────────────────────────────────────────────────────────┤
│ LEVEL 1: STATIC LEVEL DATA                                      │
│ • Bounds validation, tile references, spawn coordinate validity │
│ • Exit portal existence, socket-to-block balance                │
│ • Checkpoint distribution, gap dimension feasibility            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Level 1: Static Level Data Validation

Level 1 tests analyze raw level data (JSON or scene definitions) before instantiating physics bodies:

1. **Geometry & Bounds:**
   - Level width $\ge 20$ tiles, height $\ge 12$ tiles.
   - All tile coordinates lie within `[0, width - 1]` and `[0, height - 1]`.
2. **Spawn & Exit Invariants:**
   - Exactly one valid player spawn point positioned above solid terrain.
   - Exactly one level exit portal.
3. **Movable Fragment Budget:**
   - Total movable fragments $\ge$ required socket activations.
   - Every required socket color has at least one corresponding fragment in the level.
4. **Platform Reachability Bounds:**
   - No vertical jump ledge exceeds $2.5\text{ tiles}$ ($40\text{ px}$) without intermediate step or movable block.
   - No horizontal gap exceeds $5.4\text{ tiles}$ ($87\text{ px}$) without a bridgeable position.

---

## 3. Level 2: Discrete Block Manipulation Tests

Level 2 tests run headless in Godot to verify `PixelGlove` and `PlatformTileManager` contracts:

| Test Case | Scenario / Condition | Expected Outcome |
| :--- | :--- | :--- |
| **L2-01** | Steal valid block within $28\text{ px}$ with empty hand. | Block removed from world, collision disabled, Pip carries block. |
| **L2-02** | Attempt steal with hand already full (capacity = 1). | Rejection; world unchanged; `sfx_bump` triggered. |
| **L2-03** | Attempt steal beyond $28\text{ px}$ range. | Rejection; block remains in world. |
| **L2-04** | Attempt steal on immutable stone/bedrock. | Rejection; terrain untouched. |
| **L2-05** | Place held block into empty air within $28\text{ px}$. | Block created; solid collision activated; hand emptied; floating platform created. |
| **L2-06** | Place held block overlapping Pip's collision shape. | Rejection; no block created; Pip not trapped in collision. |
| **L2-07** | Place held block into existing solid terrain/block. | Rejection; cannot overwrite occupied cell. |
| **L2-08** | Steal block from under Pip's feet while standing. | Block removed; support eliminated; Pip begins falling on next physics tick. |
| **L2-09** | Insert matching Cyan block into Cyan socket. | Socket activates; rune glowing; trigger emitted. |
| **L2-10** | Insert mismatched block into socket. | Block rests in socket; socket does not trigger activation. |

---

## 4. Level 3: Physics-Based Traversal Simulation

Level 3 tests simulate actual player inputs across fixed physics frames (`_physics_process`) to guarantee traversal feasibility:

| Test Case | Physics Action Sequence | Verification Criteria |
| :--- | :--- | :--- |
| **L3-01** | Accelerate right for $0.5\text{s}$, release. | Horizontal velocity reaches `RUN_SPEED` ($120\text{ px/s}$), then decelerates to $0.0\text{ px/s}$ via friction. |
| **L3-02** | Full jump from flat ground. | Peak displacement $y \approx -40.8\text{ px}$; Pip lands safely back on floor. |
| **L3-03** | Short-hop jump (release jump key after 3 frames). | Peak displacement $y \approx -18\text{ px}$; satisfies variable jump height. |
| **L3-04** | Walk off a ledge and press jump $50\text{ms}$ later. | Coyote time activates; jump executes successfully despite leaving ground. |
| **L3-05** | Press jump $60\text{ms}$ before landing on ground. | Jump buffer activates; Pip jumps on the exact landing frame. |
| **L3-06** | Walk into vertical wall. | Pip stopped by wall collision; horizontal velocity zeroed against wall normal; no wall penetration. |
| **L3-07** | Jump toward 3-tile wall (impossible), place block at height 1, jump onto placed block, then jump over wall. | Pip successfully scales obstacle using placed platform. |
| **L3-08** | Walk into hazard pit. | Health zeroed; death trigger fired; respawn at checkpoint with velocity reset. |

---

## 5. Milestone B Verification Gate: Movement Prototype

**Scene:** `res://scenes/test/platformer_prototype.tscn`  
**Test Runner:** `res://scripts/test/test_platformer_movement.gd`  
**Automated Assertion List:**
1. Horizontal running acceleration and friction deceleration verified.
2. Max run speed clamped at $120\text{ px/s}$.
3. Standard jump achieves height between $39\text{ px}$ and $42\text{ px}$.
4. Variable jump cutoff limits short jump height to $\le 25\text{ px}$.
5. Coyote time honors jump at $t = +0.06\text{s}$ off ledge.
6. Jump buffer honors jump pressed $t = -0.06\text{s}$ before touchdown.
7. Wall collision stops horizontal penetration.
8. Terminal velocity clamped at $340\text{ px/s}$.

---

## 6. Milestone C Verification Gate: The Broken Crossing (9-Step Acceptance Scenario)

**Scene:** `res://scenes/test/broken_crossing.tscn`  
**Test Runner:** `res://scripts/test/test_broken_crossing.gd`

```
  [Elevated Ledge]               [Floating Bridge]              [Exit Portal]
       ┌───┐                          ┌───┐                          ┌──────┐
       │   │                          │ █ │                          │ EXIT │
       │   │                          └───┘                          └──────┘
       └───┘  <── Steal Block ──>                <── Cross Gap ──>
═══════════════                           ════════════════════════════════════
  Start Zone                                Crevasse / Pit
```

### The 9 Strict Acceptance Steps:
1. **Step 1:** Pip begins on safe starting platform and can run left and right.
2. **Step 2:** Pip jumps onto an elevated 2-tile ledge with responsive controls.
3. **Step 3:** Pip steals a marked movable block from a nearby wall.
4. **Step 4:** The removed block creates a real opening without corrupting collisions.
5. **Step 5:** Pip carries the block to the broken crossing (a 4-tile crevasse).
6. **Step 6:** Pip places the block into an empty air cell, creating a solid floating platform.
7. **Step 7:** Pip jumps onto the new platform and safely crosses the crevasse.
8. **Step 8:** Pip reaches the exit portal, triggering a correct level-completion state.
9. **Step 9:** After restarting (R key), the original wall and gap return exactly as designed.

---

## 7. Headless Execution Command

All tests are executed via Godot 4.7.2 CLI:

```powershell
& 'C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe' --headless --script res://scripts/test/test_platformer_movement.gd
```
Exit code `0` and `[ALL TESTS PASSED]` output required for gate passage.
