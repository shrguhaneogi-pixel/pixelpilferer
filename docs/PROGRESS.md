# Pixel Pilferer — Project Progress & Level Tracker

## 1. Project Milestone Overview

| Milestone | Scope | Status | Notes |
| :--- | :--- | :---: | :--- |
| **Phase 1** | Foundation & Architecture | **COMPLETE** | Godot 4.7.2 baseline, 640x360 viewport, `gl_compatibility` renderer, TileMapLayers, clean module boundaries. |
| **Phase 2** | Deterministic Puzzle Engine | **COMPLETE** | 8 canonical actions, structured `ActionResult`, 28 test cases, 500-step property fuzzing, demo corridor, and canonical hashing. |
| **Phase 3** | Playable Vertical Slice | **COMPLETE** | Full board rendering, 120ms smooth movement & particles, WASD + Shift+Dir + E + mouse adjacent clicks, input buffering, carried-block HUD, and 3 authored demo puzzles. |
| **Phase 4** | 20 Handcrafted Levels & Campaign Expansion | **COMPLETE** | All 20 campaign levels designed in JSON & mathematically proven solvable via A* search heuristic. |
| **Phase 5** | Pixel-Art Assets & Audio Synthesis | **COMPLETE** | 16x16 pixel sprites (Pip, blocks, tileset, sockets, portal, icon) & 6 WAV SFX. |
| **Phase 6** | UI, Progression, Settings & Release | **COMPLETE** | Title screen, chapter select, HUD, save system, desktop & web export presets. |

---

## 2. Level Solvability Matrix (23 / 23 Solved — 100% Verified)

### Authored Demo Levels (Chapter 0: Tutorial & Demo)
| Chapter | Level | ID | Name | Sockets | Blocks | A* Solved | Min Steps |
| :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: |
| **0** | 1 | `demo_01` | The Obstructed Path | 0 (None) | 1 (Neutral) | **YES** | 5 |
| **0** | 2 | `demo_02` | Chasm Bridge | 0 (None) | 1 (Neutral) | **YES** | 6 |
| **0** | 3 | `demo_03` | Chromatic Socket | 1 (Cyan) | 1 (Cyan) | **YES** | 6 |

### Campaign Chapters (Chapters 1–4)
| Chapter | Level | ID | Name | Sockets | Blocks | A* Solved | Min Steps |
| :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: |
| **1** | 1 | `ch1_01` | First Steps | 1 (Neutral) | 1 (Neutral) | **YES** | 13 |
| **1** | 2 | `ch1_02` | Alley Shortcut | 1 (Neutral) | 1 (Neutral) | **YES** | 7 |
| **1** | 3 | `ch1_03` | Void Cross | 1 (Neutral) | 1 (Neutral) | **YES** | 9 |
| **1** | 4 | `ch1_04` | Alleyway Duality | 1 (Neutral) | 2 (Neutral) | **YES** | 10 |
| **1** | 5 | `ch1_05` | The Twin Locks | 2 (Neutral) | 2 (Neutral) | **YES** | 18 |
| **2** | 1 | `ch2_01` | Chasm Hop | 1 (Neutral) | 1 (Neutral) | **YES** | 9 |
| **2** | 2 | `ch2_02` | The Leapfrog | 1 (Neutral) | 1 (Neutral) | **YES** | 12 |
| **2** | 3 | `ch2_03` | Double Plank | 1 (Neutral) | 2 (Neutral) | **YES** | 18 |
| **2** | 4 | `ch2_04` | Isolated Isle | 1 (Neutral) | 2 (Neutral) | **YES** | 16 |
| **2** | 5 | `ch2_05` | The Great Divide | 2 (Neutral) | 3 (Neutral) | **YES** | 19 |
| **3** | 1 | `ch3_01` | Amber Awakening | 1 (Amber) | 1 (Amber) | **YES** | 7 |
| **3** | 2 | `ch3_02` | Spectrum Split | 2 (1 Neut, 1 Amb) | 2 (1 Neut, 1 Amb) | **YES** | 18 |
| **3** | 3 | `ch3_03` | Tight Quarter Exchange | 2 (Amber) | 2 (Amber) | **YES** | 18 |
| **3** | 4 | `ch3_04` | The Vault Siphon | 2 (1 Neut, 1 Amb) | 2 (1 Neut, 1 Amb) | **YES** | 18 |
| **3** | 5 | `ch3_05` | The Triad Conduit | 2 (1 Amb, 1 Neut) | 3 (2 Amb, 1 Neut) | **YES** | 19 |
| **4** | 1 | `ch4_01` | Neon Spectrum | 2 (1 Cyan, 1 Mag) | 2 (1 Cyan, 1 Mag) | **YES** | 18 |
| **4** | 2 | `ch4_02` | Emerald Gate | 2 (1 Eme, 1 Amb) | 2 (1 Eme, 1 Amb) | **YES** | 18 |
| **4** | 3 | `ch4_03` | The Rainbow Bridge | 3 (C, M, E) | 3 (C, M, E) | **YES** | 18 |
| **4** | 4 | `ch4_04` | Chromatic Labyrinth | 3 (C, A, M) | 3 (C, A, M) | **YES** | 18 |
| **4** | 5 | `ch4_05` | The Core Chamber | 4 (C, A, M, E) | 4 (C, A, M, E) | **YES** | 34 |

---

## 3. Environment & Tools Verification Record

- **Host OS:** Windows 11 (AMD64)
- **Godot Binary:** Godot 4.7.2 stable official (`Godot_v4.7.2-stable_win64_console.exe`) installed via WinGet.
- **Python:** Python 3.14.3 utilized for automated dual test harness, level validation, and asset checks.
- **Godot Native Test Harness:** `tests/test_runner.gd` executes **198 assertions** (resource loading, data structures, invariants, all 28 deterministic tests, demo corridor scenario, 500-step randomized property fuzzing, board rendering, player animation & particles, block views, input handling & buffering, HUD upgrades, and sequential demo progression) with 100% success (exit code 0).
- **Master Test Runner:** `python tests/run_tests.py` executes 79 deterministic test assertions, the vertical slice demo verification suite, and all 23 level A* solvability proofs with 100% success (exit code 0).
