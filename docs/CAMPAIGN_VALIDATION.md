# Pixel Pilferer — Campaign Solvability & Balance Audit Report

**Generated:** 2026-11-15 08:05:19
**Solvability Engine:** Deterministic Breadth-First Search (BFS) with Authoritative `GameRules`
**Validation Status:** 20 / 20 Levels Verified (100% Solvable & Replay Verified)

---

## 1. Executive Summary

The Pixel Pilferer 20-level campaign across 4 distinct chapters has been formally validated.
Every puzzle adheres to the non-negotiable game rules, enforces strict single-block carrying capacity, guarantees minimal-step solutions, and maintains pedagogical separation of core mechanics.

| Chapter | Theme | Introduced Mechanics | Level Range | Solvability |
| :---: | :--- | :--- | :---: | :---: |
| **Chapter 1** | The Stolen Street | Movement, Floor Obstacles, Theft, Placement, Undo | 1-1 to 1-5 | **100% (5/5)** |
| **Chapter 2** | The Broken Bridges | Void, Bridging, Bridge Retrieval, Siphon-Back | 2-1 to 2-5 | **100% (5/5)** |
| **Chapter 3** | The Forgotten Vault | Neutral Sockets, Route Constraints, Multi-Block | 3-1 to 3-5 | **100% (5/5)** |
| **Chapter 4** | The Chromatic Core | Colored Fragments (C/A/M/E), Chromatic Matching | 4-1 to 4-5 | **100% (5/5)** |

---

## 2. Complete Level Solvability Matrix

| Level ID | Chapter | Name | Status | Min Steps | Explored States | Interactions | Solve Time | Warnings |
| :--- | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `ch1_01` | Ch 1 | The Blocked Alley | **SOLVED** | 5 | 63 | 1 | 0.0025s | None |
| `ch1_02` | Ch 1 | The Side Pocket | **SOLVED** | 7 | 27 | 3 | 0.0014s | None |
| `ch1_03` | Ch 1 | Turnabout | **SOLVED** | 13 | 106 | 3 | 0.0069s | None |
| `ch1_04` | Ch 1 | Squeeze Point | **SOLVED** | 8 | 106 | 3 | 0.0046s | None |
| `ch1_05` | Ch 1 | The Double Gate | **SOLVED** | 8 | 44 | 3 | 0.0021s | None |
| `ch2_01` | Ch 2 | First Gap | **SOLVED** | 6 | 15 | 2 | 0.0009s | None |
| `ch2_02` | Ch 2 | Obstacle to Bridge | **SOLVED** | 7 | 15 | 2 | 0.0008s | None |
| `ch2_03` | Ch 2 | Island Hop | **SOLVED** | 8 | 26 | 2 | 0.0022s | None |
| `ch2_04` | Ch 2 | The Leapfrog | **SOLVED** | 10 | 19 | 4 | 0.0009s | None |
| `ch2_05` | Ch 2 | The Grand Divide | **SOLVED** | 12 | 94 | 4 | 0.0043s | None |
| `ch3_01` | Ch 3 | Conduit Awakening | **SOLVED** | 5 | 41 | 2 | 0.0013s | None |
| `ch3_02` | Ch 3 | The Vault Niche | **SOLVED** | 10 | 56 | 2 | 0.0022s | None |
| `ch3_03` | Ch 3 | Conduit and Chasm | **SOLVED** | 12 | 184 | 3 | 0.0073s | None |
| `ch3_04` | Ch 3 | Dual Conduits | **SOLVED** | 14 | 727 | 4 | 0.0415s | None |
| `ch3_05` | Ch 3 | Vault Masterwork | **SOLVED** | 14 | 1751 | 4 | 0.0788s | None |
| `ch4_01` | Ch 4 | Prismatic Intro | **SOLVED** | 5 | 41 | 2 | 0.0029s | None |
| `ch4_02` | Ch 4 | Duo Resonators | **SOLVED** | 15 | 795 | 4 | 0.0476s | None |
| `ch4_03` | Ch 4 | Chromatic Bridge | **SOLVED** | 11 | 142 | 5 | 0.0049s | None |
| `ch4_04` | Ch 4 | Triad Conduits | **SOLVED** | 30 | 92 | 6 | 0.005s | None |
| `ch4_05` | Ch 4 | The Grand Core | **SOLVED** | 24 | 73 | 8 | 0.004s | None |

---

## 3. Chapter-by-Chapter Learning Progression Analysis

### Chapter 1: The Stolen Street (Obstacle Management)
- **1-1 (`ch1_01`):** Introduction of single floor obstacle. Player siphons block and walks to exit. Teaches `INTERACT` to steal.
- **1-2 (`ch1_02`):** Corridor clearing with side pocket. Player must place carried block into alcove to clear exit corridor.
- **1-3 (`ch1_03`):** Placement choices. Dropping a block in the wrong corridor creates a permanent self-obstruction.
- **1-4 (`ch1_04`):** Tight maneuvering. Siphoning and repositioning to squeeze past narrow corridors.
- **1-5 (`ch1_05`):** Dual-block coordination. Staging two obstacles into separate wall pockets to open the double gate.

### Chapter 2: The Broken Bridges (Void & Bridging)
- **2-1 (`ch2_01`):** Constructing a bridge across a 1-tile gap. Teaches that placing blocks in void creates walkable bridges.
- **2-2 (`ch2_02`):** Floor obstacle to void bridge. Clear an obstacle from path, then deploy it as a bridge.
- **2-3 (`ch2_03`):** Island hopping. Bridging to an isolated pillar to access the exit portal.
- **2-4 (`ch2_04`):** Siphon-back leapfrogging. Cross a bridge, turn around, siphon the bridge back out of the chasm from behind, and deploy it forward into a second chasm.
- **2-5 (`ch2_05`):** Multi-stage divide. Leapfrogging across multiple chasms with 2 blocks.

### Chapter 3: The Forgotten Vault (Neutral Sockets)
- **3-1 (`ch3_01`):** Single neutral socket. Placing any block onto the socket unlocks the sealed exit portal.
- **3-2 (`ch3_02`):** Side chamber socket. Positioning block into socket and navigating back through the room.
- **3-3 (`ch3_03`):** Bridge & Socket duality. 1 block bridges the void, 1 block powers the socket.
- **3-4 (`ch3_04`):** Constrained transfer. Transferring blocks across tight channels.
- **3-5 (`ch3_05`):** Vault masterwork. Powering two sockets while keeping path open to the exit.

### Chapter 4: The Chromatic Core (Color Matching & Grand Finale)
- **4-1 (`ch4_01`):** Cyan socket introduction. Only a Cyan block activates the Cyan socket.
- **4-2 (`ch4_02`):** Dual chromatic resonators (Cyan + Amber). Exact matching required.
- **4-3 (`ch4_03`):** Chromatic bridge. Using a neutral block to cross a chasm while carrying a Magenta fragment to its socket.
- **4-4 (`ch4_04`):** Triad conduits. Cyan, Amber, and Magenta fragments orchestrated through a central transfer depot.
- **4-5 (`ch4_05`):** The Grand Core. Master challenge integrating all 4 colors (Cyan, Amber, Magenta, Emerald), bridging, siphoning, and route planning to restore the world.

---

## 4. Verification Conclusion
The campaign meets all criteria of Phase 5 Acceptance Gate: 20 valid levels, 100% proven solvability, verified progression sequence, and zero rule regressions.