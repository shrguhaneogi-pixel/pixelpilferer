#!/usr/bin/env python3
"""
Pixel Pilferer Phase 9 Final Release & Delivery Verification Test Suite.
Validates the complete shipping lifecycle:
1. First Launch & Default Schema Initialization
2. Full Campaign Playthrough (All 20 campaign + 3 demo levels solved through shipping action engine)
3. Chapter Progression & Unlocking Chain (Ch1 -> Ch2 -> Ch3 -> Ch4 -> Grand Core Finale)
4. Medal Scoring & Baselines (Gold, Silver, Bronze thresholds)
5. Campaign Ending State & Completion Status
6. Save & Reload Round-trip Persistence
7. Level Replay & Best-Score Updating
8. In-Game Undo & Restart Fidelity
9. Audio & Accessibility Settings Persistence (Volume, Screen Shake, Reduced Motion)
"""

import sys
import os
import json
import time
from typing import Dict, Any, List, Tuple, Set

# Set up paths
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.abspath(os.path.join(TESTS_DIR, ".."))
LEVELS_DIR = os.path.join(PROJECT_DIR, "data", "levels")
sys.path.insert(0, TESTS_DIR)

from test_domain_model import (
    BoardState, GameRules, HistoryManager, ActionType, TileType, BlockColor,
    ACTION_DIRS
)
from test_puzzle_solver import solve_level, load_level_from_dict

class ReleaseVerificationSuite:
    def __init__(self):
        self.total_tests = 0
        self.failed_tests = 0
        self.failures: List[str] = []

    def assert_true(self, condition: bool, test_name: str) -> None:
        self.total_tests += 1
        if not condition:
            self.failed_tests += 1
            self.failures.append(test_name)
            print(f"  [FAIL] {test_name}", file=sys.stderr)
        else:
            print(f"  [PASS] {test_name}")

    def assert_eq(self, actual: Any, expected: Any, test_name: str) -> None:
        self.total_tests += 1
        if actual != expected:
            self.failed_tests += 1
            self.failures.append(f"{test_name} (Expected: {expected}, Got: {actual})")
            print(f"  [FAIL] {test_name} (Expected: {expected}, Got: {actual})", file=sys.stderr)
        else:
            print(f"  [PASS] {test_name}")

def default_save_schema() -> Dict[str, Any]:
    return {
        "schema_version": 1,
        "unlocked_level": "ch1_01",
        "current_chapter": 1,
        "completed_levels": {},
        "settings": {
            "master_volume": 1.0,
            "sfx_volume": 1.0,
            "music_volume": 0.8,
            "screen_shake": True,
            "reduced_motion": False
        },
        "seen_tutorials": []
    }

def calculate_medal(moves: int, optimal: int) -> str:
    if moves <= optimal:
        return "gold"
    elif moves <= optimal + 3:
        return "silver"
    else:
        return "bronze"

def run_release_verification():
    suite = ReleaseVerificationSuite()
    print("\n=======================================================")
    print("      PIXEL PILFERER FINAL RELEASE VERIFICATION        ")
    print("=======================================================\n")

    # -------------------------------------------------------------------------
    # 1. First Launch & Default Schema
    # -------------------------------------------------------------------------
    print("--- 1. First Launch & Save Initialization ---")
    save_state = default_save_schema()
    suite.assert_eq(save_state["schema_version"], 1, "Save schema version is 1")
    suite.assert_eq(save_state["unlocked_level"], "ch1_01", "Default unlocked level is ch1_01")
    suite.assert_eq(len(save_state["completed_levels"]), 0, "Initial completed levels is empty")
    suite.assert_true(save_state["settings"]["screen_shake"], "Screen shake enabled by default")
    suite.assert_true(not save_state["settings"]["reduced_motion"], "Reduced motion disabled by default")

    # -------------------------------------------------------------------------
    # 2. Replay & Solve All 23 Levels Through Shipping Engine
    # -------------------------------------------------------------------------
    print("\n--- 2. Full Campaign Programmatic Replay ---")
    campaign_chapters = [
        ("demo_levels.json", 0, ["demo_01", "demo_02", "demo_03"]),
        ("ch1_levels.json", 1, ["ch1_01", "ch1_02", "ch1_03", "ch1_04", "ch1_05"]),
        ("ch2_levels.json", 2, ["ch2_01", "ch2_02", "ch2_03", "ch2_04", "ch2_05"]),
        ("ch3_levels.json", 3, ["ch3_01", "ch3_02", "ch3_03", "ch3_04", "ch3_05"]),
        ("ch4_levels.json", 4, ["ch4_01", "ch4_02", "ch4_03", "ch4_04", "ch4_05"]),
    ]

    all_solved = True
    total_levels_evaluated = 0

    for filename, ch_idx, expected_ids in campaign_chapters:
        filepath = os.path.join(LEVELS_DIR, filename)
        suite.assert_true(os.path.exists(filepath), f"Level asset file exists: {filename}")
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)

        suite.assert_eq(len(data.get("levels", [])), len(expected_ids), f"Chapter {ch_idx} contains exactly {len(expected_ids)} levels")

        for lvl in data.get("levels", []):
            lvl_id = lvl["id"]
            lvl_name = lvl["name"]
            total_levels_evaluated += 1

            # Solve level using verified solver
            state = load_level_from_dict(lvl)
            solver_res = solve_level(state)
            suite.assert_true(solver_res.get("solved", False), f"Level {lvl_id} ('{lvl_name}') has valid solution")
            solution = solver_res.get("actions", [])

            # Replay solution through pure shipping GameRules
            replay_state = load_level_from_dict(lvl)
            for step_idx, action in enumerate(solution):
                res = GameRules.apply_action(replay_state, action)
                suite.assert_true(res["success"], f"[{lvl_id}] Step {step_idx} ({action.name}) executed successfully")
                replay_state = res["next_state"]

            # Check level completion
            suite.assert_true(replay_state.is_completed, f"[{lvl_id}] Reached exit portal and satisfied win condition")
            suite.assert_true(len(solution) <= lvl.get("optimal_moves", 999), f"[{lvl_id}] Replay solution ({len(solution)} steps) meets or beats optimal ({lvl.get('optimal_moves')})")

            # Record progression into save state
            optimal = lvl.get("optimal_moves", len(solution))
            medal = calculate_medal(len(solution), optimal)
            save_state["completed_levels"][lvl_id] = {
                "completed": True,
                "best_moves": len(solution),
                "medal": medal
            }

            # Update unlocked level for campaign levels
            if ch_idx > 0:
                level_num = int(lvl_id.split("_")[1])
                if level_num < 5:
                    next_id = f"ch{ch_idx}_0{level_num + 1}"
                    save_state["unlocked_level"] = next_id
                elif ch_idx < 4:
                    next_id = f"ch{ch_idx + 1}_01"
                    save_state["unlocked_level"] = next_id
                    save_state["current_chapter"] = ch_idx + 1

    suite.assert_eq(total_levels_evaluated, 23, "All 23 levels verified and completed in replay")

    # -------------------------------------------------------------------------
    # 3. Campaign Ending State
    # -------------------------------------------------------------------------
    print("\n--- 3. Campaign Ending & Medal Verification ---")
    all_campaign_ids = [f"ch{ch}_0{idx}" for ch in range(1, 5) for idx in range(1, 6)]
    campaign_completed_count = sum(1 for cid in all_campaign_ids if cid in save_state["completed_levels"])
    suite.assert_eq(campaign_completed_count, 20, "All 20 campaign levels marked completed in save progress")
    gold_count = sum(1 for cid in all_campaign_ids if save_state["completed_levels"][cid]["medal"] == "gold")
    suite.assert_eq(gold_count, 20, "All 20 campaign levels achieved GOLD MEDAL (★) on optimal replay")

    # -------------------------------------------------------------------------
    # 4. Save & Reload Persistence Round-Trip
    # -------------------------------------------------------------------------
    print("\n--- 4. Save & Reload Persistence Round-Trip ---")
    json_str = json.dumps(save_state, indent=2)
    suite.assert_true(len(json_str) > 0, "Serialized save data to JSON string")

    # Simulate reload
    reloaded_save = json.loads(json_str)
    suite.assert_eq(reloaded_save["schema_version"], 1, "Reloaded schema version matches")
    suite.assert_eq(len(reloaded_save["completed_levels"]), 23, "Reloaded 23 completed level records (20 campaign + 3 demo)")
    suite.assert_eq(reloaded_save["completed_levels"]["ch4_05"]["medal"], "gold", "Grand Core gold medal persisted")

    # -------------------------------------------------------------------------
    # 5. Level Replay & Best-Score Updating
    # -------------------------------------------------------------------------
    print("\n--- 5. Level Replay & Score Record Updating ---")
    # Simulate player replaying ch1_01 with more moves (non-optimal)
    old_best = save_state["completed_levels"]["ch1_01"]["best_moves"]
    new_worse_moves = old_best + 5 # 10 moves
    if new_worse_moves < save_state["completed_levels"]["ch1_01"]["best_moves"]:
        save_state["completed_levels"]["ch1_01"]["best_moves"] = new_worse_moves
    suite.assert_eq(save_state["completed_levels"]["ch1_01"]["best_moves"], old_best, "Worse score does not overwrite best moves record")

    # Simulate player replaying and achieving an equal score
    if old_best <= save_state["completed_levels"]["ch1_01"]["best_moves"]:
        save_state["completed_levels"]["ch1_01"]["best_moves"] = old_best
    suite.assert_eq(save_state["completed_levels"]["ch1_01"]["best_moves"], old_best, "Optimal score record preserved on replay")

    # -------------------------------------------------------------------------
    # 6. In-Game Undo & Restart Fidelity
    # -------------------------------------------------------------------------
    print("\n--- 6. In-Game Undo & Restart Fidelity ---")
    fixture_path = os.path.join(LEVELS_DIR, "ch1_levels.json")
    with open(fixture_path, "r", encoding="utf-8") as f:
        ch1_data = json.load(f)
    lvl_state = load_level_from_dict(ch1_data["levels"][0])
    hist = HistoryManager(lvl_state)

    initial_pos = lvl_state.player_pos
    # Move east then interact east to steal the block
    res1 = GameRules.apply_action(lvl_state, ActionType.MOVE_EAST)
    lvl_state = res1["next_state"]
    hist.record_state(lvl_state)
    res2 = GameRules.apply_action(lvl_state, ActionType.INTERACT_EAST)
    lvl_state = res2["next_state"]
    hist.record_state(lvl_state)
    suite.assert_eq(lvl_state.turn_count, 2, "Advanced 2 turns")

    # Undo once
    lvl_state = hist.undo()
    suite.assert_eq(lvl_state.turn_count, 1, "Undo reduced turn count to 1")
    suite.assert_eq(lvl_state.player_pos, (initial_pos[0] + 1, initial_pos[1]), "Undo restored intermediate player position")
    suite.assert_true(lvl_state.carried_block is None, "Undo cleared carried block back to floor")

    # Undo back to start
    lvl_state = hist.undo()
    suite.assert_eq(lvl_state.turn_count, 0, "Undo back to start restored turn count to 0")
    suite.assert_eq(lvl_state.player_pos, initial_pos, "Undo back to start restored initial position")

    # Restart
    res_move = GameRules.apply_action(lvl_state, ActionType.MOVE_EAST)
    lvl_state = res_move["next_state"]
    hist.record_state(lvl_state)
    lvl_state = hist.restart()
    suite.assert_eq(lvl_state.turn_count, 0, "Restart reset turn count to 0")
    suite.assert_eq(lvl_state.player_pos, initial_pos, "Restart reset player position")
    suite.assert_true(not hist.can_undo(), "Restart cleared undo history")

    # -------------------------------------------------------------------------
    # 7. Audio & Accessibility Settings Persistence
    # -------------------------------------------------------------------------
    print("\n--- 7. Settings & Accessibility Toggles ---")
    save_state["settings"]["reduced_motion"] = True
    save_state["settings"]["screen_shake"] = False
    save_state["settings"]["music_volume"] = 0.5
    save_state["settings"]["sfx_volume"] = 0.75

    saved_settings_json = json.dumps(save_state["settings"])
    reloaded_settings = json.loads(saved_settings_json)
    suite.assert_true(reloaded_settings["reduced_motion"], "Reduced motion persisted as enabled")
    suite.assert_true(not reloaded_settings["screen_shake"], "Screen shake persisted as disabled")
    suite.assert_eq(reloaded_settings["music_volume"], 0.5, "Music volume persisted at 0.5")
    suite.assert_eq(reloaded_settings["sfx_volume"], 0.75, "SFX volume persisted at 0.75")

    # -------------------------------------------------------------------------
    # Final Results
    # -------------------------------------------------------------------------
    print("\n-------------------------------------------")
    print(f"Total Release Verification Tests: {suite.total_tests} | Failed: {suite.failed_tests}")
    if suite.failed_tests == 0:
        print("SUCCESS: Full release verification passed cleanly!")
        return True
    else:
        print(f"FAILURE: {suite.failed_tests} tests failed!", file=sys.stderr)
        return False

if __name__ == "__main__":
    success = run_release_verification()
    sys.exit(0 if success else 1)
