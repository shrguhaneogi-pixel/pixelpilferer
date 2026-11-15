# Pixel Pilferer — Project Progress & Level Tracker

## 1. Project Milestone Overview

| Milestone | Scope | Status | Notes |
| :--- | :--- | :---: | :--- |
| **Phase 1** | Foundation & Architecture | **COMPLETE** | Godot 4.7.2 baseline, 640x360 viewport, `gl_compatibility` renderer, TileMapLayers, clean module boundaries. |
| **Phase 2** | Deterministic Puzzle Engine | **COMPLETE** | 8 canonical actions, structured `ActionResult`, 28 test cases, 500-step property fuzzing, demo corridor, and canonical hashing. |
| **Phase 3** | Playable Vertical Slice | **COMPLETE** | Full board rendering, 120ms smooth movement & particles, WASD + Shift+Dir + E + mouse adjacent clicks, input buffering, carried-block HUD, and 3 authored demo puzzles. |
| **Phase 4** | Puzzle Solver & Level Validation | **COMPLETE** | BFS & A* solver engine, schema validator, solution replay verifier, and contextual hint generator. |
| **Phase 5** | Complete Campaign & Puzzle Design | **COMPLETE** | 20 campaign levels across 4 chapters with strict pedagogical curriculum, 100% solver-verified solvability, progression persistence, and restoration victory flow. |
| **Phase 6** | Polish, Accessibility, Web & Release | **NEXT** | Audio enhancement, UI polish, accessibility settings, and desktop/web release exports. |

---

## 2. Level Solvability Matrix (23 / 23 Solved — 100% Verified)

### Authored Demo Levels (Chapter 0: Tutorial & Demo)
| Chapter | Level | ID | Name | Sockets | Blocks | BFS Solved | Min Steps |
| :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: |
| **0** | 1 | `demo_01` | The Obstructed Path | 0 (None) | 1 (Neutral) | **YES** | 5 |
| **0** | 2 | `demo_02` | Chasm Bridge | 0 (None) | 1 (Neutral) | **YES** | 6 |
| **0** | 3 | `demo_03` | Chromatic Socket | 1 (Cyan) | 1 (Cyan) | **YES** | 6 |

### Campaign Chapters (Chapters 1–4)
| Chapter | Level | ID | Name | Introduced Mechanics | Sockets | Blocks | BFS/A* Solved | Min Steps |
| :---: | :---: | :---: | :--- | :--- | :---: | :---: | :---: | :---: |
| **1** | 1 | `ch1_01` | The Blocked Alley | Obstacle theft & clear passage | 0 | 1 | **YES** | 5 |
| **1** | 2 | `ch1_02` | The Side Pocket | Side alcove relocation | 0 | 1 | **YES** | 7 |
| **1** | 3 | `ch1_03` | Turnabout | Placement choices & loopback | 0 | 1 | **YES** | 13 |
| **1** | 4 | `ch1_04` | Squeeze Point | Tight corridor maneuvering | 0 | 1 | **YES** | 8 |
| **1** | 5 | `ch1_05` | The Double Gate | Dual obstacle coordination | 0 | 2 | **YES** | 8 |
| **2** | 1 | `ch2_01` | First Gap | 1-tile void chasm bridge | 0 | 1 | **YES** | 6 |
| **2** | 2 | `ch2_02` | Obstacle to Bridge | Obstacle siphoning into bridge | 0 | 1 | **YES** | 7 |
| **2** | 3 | `ch2_03` | Island Hop | Stepping onto isolated pillar | 0 | 1 | **YES** | 8 |
| **2** | 4 | `ch2_04` | The Leapfrog | Bridge siphon-back from behind | 0 | 1 | **YES** | 10 |
| **2** | 5 | `ch2_05` | The Grand Divide | Multi-gap leapfrog coordination | 0 | 2 | **YES** | 12 |
| **3** | 1 | `ch3_01` | Conduit Awakening | Single neutral socket | 1 | 1 | **YES** | 5 |
| **3** | 2 | `ch3_02` | The Vault Niche | Side niche socket navigation | 1 | 1 | **YES** | 10 |
| **3** | 3 | `ch3_03` | Conduit and Chasm | Bridge & socket duality | 1 | 2 | **YES** | 12 |
| **3** | 4 | `ch3_04` | Dual Conduits | Dual neutral sockets | 2 | 2 | **YES** | 14 |
| **3** | 5 | `ch3_05` | Vault Masterwork | Multi-corridor socket planning | 2 | 2 | **YES** | 14 |
| **4** | 1 | `ch4_01` | Prismatic Intro | Cyan socket matching | 1 | 1 | **YES** | 5 |
| **4** | 2 | `ch4_02` | Duo Resonators | Cyan & Amber matching | 2 | 2 | **YES** | 15 |
| **4** | 3 | `ch4_03` | Chromatic Bridge | Neutral bridge + Magenta socket | 1 | 2 | **YES** | 11 |
| **4** | 4 | `ch4_04` | Triad Conduits | Cyan, Amber, Magenta conduits | 3 | 3 | **YES** | 30 |
| **4** | 5 | `ch4_05` | The Grand Core | 4-Color masterwork finale | 4 | 4 | **YES** | 24 |

---

## 3. Environment & Tools Verification Record

- **Host OS:** Windows 11 (AMD64)
- **Godot Binary:** Godot 4.7.2 stable official (`Godot_v4.7.2-stable_win64_console.exe`) installed via WinGet.
- **Python:** Python 3.14.3 utilized for automated dual test harness, level validation, and campaign audit.
- **Godot Native Test Harness:** `tests/test_runner.gd` executes **313 assertions** (resource loading, data structures, invariants, all 28 deterministic tests, demo corridor scenario, 500-step randomized property fuzzing, board rendering, player animation & particles, block views, input handling & buffering, HUD upgrades, sequential demo progression, Phase 4 solver/validator/hint verification tests, and Phase 5 campaign & progression tests) with 100% success (exit code 0).
- **Master Test Runner:** `python tests/run_tests.py` executes 79 deterministic test assertions, the vertical slice demo verification suite, 54 Phase 4 solver & validator assertions, and all 23 levels verified solvable with 100% success (exit code 0).
- **Campaign Audit:** `python tests/test_campaign_audit.py` formally audits all 20 campaign levels against curriculum invariants, bounds, optimal steps, and solution replay verification. Generated `docs/CAMPAIGN_VALIDATION.md`.
