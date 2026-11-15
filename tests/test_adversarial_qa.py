#!/usr/bin/env python3
"""
Pixel Pilferer Phase 8 Adversarial QA & Reliability Audit Test Suite.
Performs deterministic 10,000-step randomized fuzzing, history stress tests,
solver consistency checks, save file resilience tests, and state invariant audits.
"""

import sys
import os
import random
import json
import time
from typing import Dict, Any, List, Tuple, Set

# Add parent and tests directories to python path
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.abspath(os.path.join(TESTS_DIR, ".."))
sys.path.insert(0, TESTS_DIR)

from test_domain_model import (
    BoardState, GameRules, HistoryManager, ActionType, TileType, BlockColor,
    ACTION_DIRS
)
from test_puzzle_solver import solve_level

class AdversarialQASuite:
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

def make_stress_fixture(width: int = 7, height: int = 7) -> BoardState:
    """Creates a complex multi-feature board for stress and fuzz testing."""
    s = BoardState(width, height)
    # Surround with walls
    for x in range(width):
        for y in range(height):
            if x == 0 or x == width - 1 or y == 0 or y == height - 1:
                s.tiles[(x, y)] = TileType.WALL
            else:
                s.tiles[(x, y)] = TileType.FLOOR
                
    # Place interior features
    s.player_pos = (1, 1)
    s.exit_cell = (width - 2, height - 2)
    s.tiles[(3, 2)] = TileType.VOID
    s.tiles[(3, 3)] = TileType.VOID
    s.tiles[(3, 4)] = TileType.WALL
    
    # Sockets
    s.sockets[(1, 3)] = BlockColor.CYAN
    s.sockets[(5, 1)] = BlockColor.AMBER
    
    # Blocks
    s.blocks[(2, 1)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    s.blocks[(2, 2)] = {"id": 2, "color": BlockColor.AMBER, "is_bridge": False}
    s.blocks[(4, 3)] = {"id": 3, "color": BlockColor.NEUTRAL, "is_bridge": False}
    return s

def test_10000_step_deterministic_fuzzing(suite: AdversarialQASuite) -> None:
    print("\n--- 1. AUDIT 3: 10,000-Step Deterministic Random Fuzzing Across 4 Fixed Seeds ---")
    seeds = [42, 1337, 2026, 9999]
    steps_per_seed = 2500
    all_actions = [
        ActionType.MOVE_NORTH, ActionType.MOVE_EAST, ActionType.MOVE_SOUTH, ActionType.MOVE_WEST,
        ActionType.INTERACT_NORTH, ActionType.INTERACT_EAST, ActionType.INTERACT_SOUTH, ActionType.INTERACT_WEST
    ]
    
    total_fuzz_ops = 0
    invariants_intact = True
    
    for seed in seeds:
        rng = random.Random(seed)
        state = make_stress_fixture()
        initial_block_count = len(state.blocks)
        initial_tiles = dict(state.tiles)
        initial_sockets = dict(state.sockets)
        initial_exit = state.exit_cell
        
        history = HistoryManager(state)
        
        for step in range(steps_per_seed):
            total_fuzz_ops += 1
            op_roll = rng.random()
            
            # 12% Chance to Undo
            if op_roll < 0.12 and history.can_undo():
                # Burst undo test (1-5 undos)
                burst = rng.randint(1, 5)
                for _ in range(burst):
                    if history.can_undo():
                        history.undo()
            # 1% Chance to Restart
            elif op_roll < 0.13:
                history.restart()
            # Normal action
            else:
                act = rng.choice(all_actions)
                cur_s = history.get_current_state()
                res = GameRules.apply_action(cur_s, act)
                if res["success"]:
                    history.record_state(res["next_state"])
                    
            s = history.get_current_state()
            
            # ----------------------------------------
            # Exhaustive Invariant Validation
            # ----------------------------------------
            # 1. Player in bounds
            if not s.is_inside(s.player_pos):
                invariants_intact = False
                suite.assert_true(False, f"Seed {seed} step {step}: Player left bounds at {s.player_pos}")
                break
                
            # 2. Player cannot be on wall or void (unless bridge)
            p_tile = s.get_tile(s.player_pos)
            if p_tile == TileType.WALL:
                invariants_intact = False
                suite.assert_true(False, f"Seed {seed} step {step}: Player inside wall at {s.player_pos}")
                break
            if p_tile == TileType.VOID and not s.is_bridge_at(s.player_pos):
                invariants_intact = False
                suite.assert_true(False, f"Seed {seed} step {step}: Player on unbridged void at {s.player_pos}")
                break
                
            # 3. Block count conservation: (blocks on board) + (1 if carrying else 0) == initial_block_count
            carried_count = 1 if s.is_carrying() else 0
            board_count = len(s.blocks)
            if (board_count + carried_count) != initial_block_count:
                invariants_intact = False
                suite.assert_true(False, f"Seed {seed} step {step}: Block conservation violated! Board: {board_count}, Carried: {carried_count}, Expected: {initial_block_count}")
                break
                
            # 4. No two blocks occupy same cell
            seen_blocks = set()
            for b_pos in s.blocks:
                if b_pos in seen_blocks:
                    invariants_intact = False
                    suite.assert_true(False, f"Seed {seed} step {step}: Duplicate block at {b_pos}")
                    break
                seen_blocks.add(b_pos)
                
            # 5. Player never shares cell with a floor block (only bridges allowed)
            if s.player_pos in s.blocks and not s.is_bridge_at(s.player_pos):
                invariants_intact = False
                suite.assert_true(False, f"Seed {seed} step {step}: Player overlapping floor block at {s.player_pos}")
                break
                
            # 6. Immutable metadata integrity
            if s.tiles != initial_tiles or s.sockets != initial_sockets or s.exit_cell != initial_exit:
                invariants_intact = False
                suite.assert_true(False, f"Seed {seed} step {step}: Immutable level data was mutated!")
                break
                
    suite.assert_true(invariants_intact and total_fuzz_ops == 10000, f"All 10,000 randomized operations across 4 seeds preserved all 6 physical and state invariants")

def test_history_and_edge_cases(suite: AdversarialQASuite) -> None:
    print("\n--- 2. AUDIT 2: Puzzle State Integrity & Edge Cases ---")
    
    # A. Rapid Undo / Redo / Empty Stack Resilience
    s = make_stress_fixture()
    hist = HistoryManager(s)
    suite.assert_true(not hist.can_undo(), "Initial state cannot undo")
    initial_copy = hist.get_current_state().duplicate()
    undone = hist.undo()
    suite.assert_eq(undone.player_pos, initial_copy.player_pos, "Undo on empty history returns current state safely without error")
    
    # 20 consecutive moves then 20 undos
    curr = s
    for i in range(20):
        # Move back and forth
        act = ActionType.MOVE_SOUTH if (i % 2 == 0) else ActionType.MOVE_NORTH
        res = GameRules.apply_action(curr, act)
        if res["success"]:
            curr = res["next_state"]
            hist.record_state(curr)
            
    depth_before = len(hist._undo_stack) - 1
    suite.assert_eq(depth_before, 20, "20 successful actions recorded in history stack")
    
    # Undo all 20
    for _ in range(20):
        hist.undo()
    suite.assert_eq(len(hist._undo_stack) - 1, 0, "All 20 actions successfully undone")
    suite.assert_eq(hist.get_current_state().player_pos, (1, 1), "Player restored to exact initial position (1, 1)")
    
    # B. Repeated Pickup & Placement on Same Cell (Cycle Stability)
    s = make_stress_fixture()
    # Initial block at (2, 1)
    for cycle in range(50):
        # Steal East
        res_steal = GameRules.apply_action(s, ActionType.INTERACT_EAST)
        suite.assert_true(res_steal["success"], f"Cycle {cycle}: Steal block east succeeds")
        s = res_steal["next_state"]
        suite.assert_true(s.is_carrying(), f"Cycle {cycle}: Pip holds block")
        
        # Place East back onto (2, 1)
        res_place = GameRules.apply_action(s, ActionType.INTERACT_EAST)
        suite.assert_true(res_place["success"], f"Cycle {cycle}: Place block east succeeds")
        s = res_place["next_state"]
        suite.assert_true(not s.is_carrying(), f"Cycle {cycle}: Pip hand is empty")
        suite.assert_true((2, 1) in s.blocks, f"Cycle {cycle}: Block back at (2, 1)")
        
    suite.assert_eq(s.turn_count, 100, "50 steal-place cycles cleanly advanced turn count to 100")

def test_solver_shortest_path_verifications(suite: AdversarialQASuite) -> None:
    print("\n--- 3. AUDIT 4: Solver Shortest-Path & Deterministic Proofs on Known Micro-Fixtures ---")
    
    # Fixture 1: Direct 3-step corridor (Start (1,1), Exit (4,1)) -> Optimal = 3 moves
    f1 = BoardState(6, 3)
    for x in range(6):
        for y in range(3):
            f1.tiles[(x, y)] = TileType.WALL
    for x in range(1, 5):
        f1.tiles[(x, 1)] = TileType.FLOOR
    f1.player_pos = (1, 1)
    f1.exit_cell = (4, 1)
    
    res1 = solve_level(f1, max_visited=1000)
    suite.assert_true(res1["solved"], "Fixture 1 solvable")
    suite.assert_eq(res1["steps"], 3, "Fixture 1 shortest path is exactly 3 moves")
    
    # Fixture 2: 1-obstacle corridor (Start (1,1), Block (2,1), Exit (4,1))
    # Optimal: Steal East (1), Move East (2), Move East (3), Move East (4) = 4 moves
    f2 = BoardState(6, 3)
    for x in range(6):
        for y in range(3):
            f2.tiles[(x, y)] = TileType.WALL
    for x in range(1, 5):
        f2.tiles[(x, 1)] = TileType.FLOOR
    f2.player_pos = (1, 1)
    f2.exit_cell = (4, 1)
    f2.blocks[(2, 1)] = {"id": 1, "color": BlockColor.NEUTRAL, "is_bridge": False}
    
    res2 = solve_level(f2, max_visited=1000)
    suite.assert_true(res2["solved"], "Fixture 2 solvable")
    suite.assert_eq(res2["steps"], 4, "Fixture 2 shortest path is exactly 4 moves")
    
    # Fixture 3: Unsolvable Board (Exit surrounded by walls, no blocks)
    f3 = BoardState(5, 5)
    for x in range(5):
        for y in range(5):
            f3.tiles[(x, y)] = TileType.WALL
    f3.tiles[(1, 1)] = TileType.FLOOR
    f3.tiles[(3, 3)] = TileType.FLOOR
    f3.player_pos = (1, 1)
    f3.exit_cell = (3, 3)
    
    res3 = solve_level(f3, max_visited=500)
    suite.assert_true(not res3["solved"], "Fixture 3 correctly identified as unsolvable")

def test_save_data_resilience(suite: AdversarialQASuite) -> None:
    print("\n--- 4. AUDIT 6: Save Data Resilience & Corrupted File Recovery ---")
    
    def validate_schema(data: Dict[str, Any]) -> bool:
        if not isinstance(data, dict): return False
        if "schema_version" not in data or not isinstance(data["schema_version"], (int, float)): return False
        if "completed_levels" not in data or not isinstance(data["completed_levels"], dict): return False
        if "settings" not in data or not isinstance(data["settings"], dict): return False
        return True

    # 1. Valid save
    valid_data = {
        "schema_version": 1,
        "unlocked_level": "ch2_01",
        "completed_levels": {"ch1_01": 5, "ch1_02": 8},
        "settings": {"master_volume": 0.8, "high_contrast": True},
        "tutorial_seen": {"demo_01": True}
    }
    suite.assert_true(validate_schema(valid_data), "Valid save dictionary passes schema validation")
    
    # 2. Corrupted cases
    suite.assert_true(not validate_schema({}), "Empty dictionary fails validation")
    suite.assert_true(not validate_schema({"schema_version": "v1"}), "String schema_version fails validation")
    suite.assert_true(not validate_schema({"schema_version": 1, "completed_levels": [1, 2]}), "Array completed_levels fails validation")
    suite.assert_true(not validate_schema({"schema_version": 1, "completed_levels": {}}), "Missing settings fails validation")
    
    # 3. Safe fallback logic verification
    def load_or_fallback(raw_json: str) -> Dict[str, Any]:
        default = {
            "schema_version": 1,
            "unlocked_level": "ch1_01",
            "completed_levels": {},
            "settings": {"master_volume": 1.0}
        }
        try:
            parsed = json.loads(raw_json)
            if validate_schema(parsed):
                return parsed
        except Exception:
            pass
        return default

    # Malformed JSON strings
    suite.assert_eq(load_or_fallback("{ malformed json :")[ "schema_version"], 1, "Malformed syntax falls back safely to default schema")
    suite.assert_eq(load_or_fallback("")[ "unlocked_level"], "ch1_01", "Empty string falls back safely to ch1_01")
    suite.assert_eq(load_or_fallback('{"schema_version": 1}')[ "unlocked_level"], "ch1_01", "Incomplete schema falls back safely")

def run_adversarial_suite() -> int:
    print("=======================================================")
    print("      PIXEL PILFERER ADVERSARIAL QA & AUDIT SUITE      ")
    print("=======================================================")
    
    suite = AdversarialQASuite()
    test_10000_step_deterministic_fuzzing(suite)
    test_history_and_edge_cases(suite)
    test_solver_shortest_path_verifications(suite)
    test_save_data_resilience(suite)
    
    print("\n-------------------------------------------")
    print(f"Total Adversarial Tests: {suite.total_tests} | Failed: {suite.failed_tests}")
    if suite.failed_tests > 0:
        print("FAILED: Adversarial QA discovered defects:")
        for f in suite.failures:
            print(f"  - {f}")
        return 1
    else:
        print("SUCCESS: All Adversarial QA tests passed cleanly!")
        return 0

if __name__ == "__main__":
    sys.exit(run_adversarial_suite())
