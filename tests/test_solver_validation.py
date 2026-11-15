#!/usr/bin/env python3
"""
Phase 4: Puzzle Solver, Formal Level Validator, and Hint System Automated Test Suite
Implements and verifies all 14 test cases specified in the operating contract.
"""

import sys
import os
import time
from collections import deque
from enum import Enum
from typing import Dict, List, Tuple, Optional, Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from test_domain_model import (
    ActionType, TileType, BlockColor, BoardState, GameRules, HistoryManager, ACTION_DIRS
)
from test_puzzle_solver import CANDIDATE_ACTIONS, load_level_from_dict


class SolverStatus(Enum):
    SOLVED = "SOLVED"
    UNSOLVABLE = "UNSOLVABLE"
    LIMIT_REACHED = "LIMIT_REACHED"
    INVALID_LEVEL = "INVALID_LEVEL"


class LevelValidator:
    VALID_LAYOUT_CHARS = set("#. PSE1234")

    @classmethod
    def validate_level(cls, d: Dict[str, Any], seen_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        if seen_ids is None:
            seen_ids = []

        # 1. Identity & Metadata
        if "id" not in d or not str(d["id"]).strip():
            return {"valid": False, "error": "Missing or empty 'id' field.", "field": "id", "cell": (-1, -1)}
        level_id = str(d["id"]).strip()

        if level_id in seen_ids:
            return {"valid": False, "error": f"Duplicate level ID '{level_id}' found in campaign.", "field": "id", "cell": (-1, -1), "level_id": level_id}

        if "name" not in d or not str(d["name"]).strip():
            return {"valid": False, "error": f"Level '{level_id}' has missing or empty 'name' field.", "field": "name", "cell": (-1, -1), "level_id": level_id}

        # 2. Dimensions
        w = d.get("width", 0)
        h = d.get("height", 0)
        if w <= 0 or h <= 0:
            return {"valid": False, "error": f"Level '{level_id}' dimensions width ({w}) and height ({h}) must be positive integers.", "field": "dimensions", "cell": (w, h), "level_id": level_id}

        # 3. Layout checks
        if "layout" not in d or not isinstance(d["layout"], list):
            return {"valid": False, "error": f"Level '{level_id}' is missing required 'layout' array.", "field": "layout", "cell": (-1, -1), "level_id": level_id}

        layout = d["layout"]
        if len(layout) != h:
            return {"valid": False, "error": f"Level '{level_id}' layout row count ({len(layout)}) does not match declared height ({h}).", "field": "layout", "cell": (0, len(layout)), "level_id": level_id}

        layout_p_cells = []
        layout_e_cells = []
        terrain_map = {}
        socket_map = {}

        for y, row in enumerate(layout):
            if not isinstance(row, str):
                return {"valid": False, "error": f"Level '{level_id}' row {y} is not a valid string.", "field": "layout", "cell": (0, y), "level_id": level_id}
            if len(row) != w:
                return {"valid": False, "error": f"Level '{level_id}' has ragged layout: Row {y} length ({len(row)}) does not match declared width ({w}).", "field": "layout", "cell": (len(row), y), "level_id": level_id}

            for x, ch in enumerate(row):
                cell = (x, y)
                if ch not in cls.VALID_LAYOUT_CHARS:
                    return {"valid": False, "error": f"Level '{level_id}' contains unknown character '{ch}' at cell ({x}, {y}).", "field": "layout", "cell": cell, "level_id": level_id}

                if ch == "#":
                    terrain_map[cell] = TileType.WALL
                elif ch == ".":
                    terrain_map[cell] = TileType.FLOOR
                elif ch == " ":
                    terrain_map[cell] = TileType.VOID
                elif ch == "P":
                    terrain_map[cell] = TileType.FLOOR
                    layout_p_cells.append(cell)
                elif ch == "E":
                    terrain_map[cell] = TileType.FLOOR
                    layout_e_cells.append(cell)
                elif ch == "S":
                    terrain_map[cell] = TileType.FLOOR
                    socket_map[cell] = BlockColor.NEUTRAL
                elif ch == "1":
                    terrain_map[cell] = TileType.FLOOR
                    socket_map[cell] = BlockColor.CYAN
                elif ch == "2":
                    terrain_map[cell] = TileType.FLOOR
                    socket_map[cell] = BlockColor.AMBER
                elif ch == "3":
                    terrain_map[cell] = TileType.FLOOR
                    socket_map[cell] = BlockColor.MAGENTA
                elif ch == "4":
                    terrain_map[cell] = TileType.FLOOR
                    socket_map[cell] = BlockColor.EMERALD

        # 4. Player start validation
        if len(layout_p_cells) > 1:
            return {"valid": False, "error": f"Level '{level_id}' has {len(layout_p_cells)} duplicate player start markers in layout.", "field": "player_start", "cell": layout_p_cells[1], "level_id": level_id}

        player_start_pos = None
        if "player_start" in d:
            p_raw = d["player_start"]
            if not isinstance(p_raw, (list, tuple)) or len(p_raw) != 2:
                return {"valid": False, "error": f"Level '{level_id}' player_start must be a 2-element array [x, y].", "field": "player_start", "cell": (-1, -1), "level_id": level_id}
            p_cand = (int(p_raw[0]), int(p_raw[1]))
            if p_cand[0] < 0 or p_cand[0] >= w or p_cand[1] < 0 or p_cand[1] >= h:
                return {"valid": False, "error": f"Level '{level_id}' player_start ({p_cand[0]}, {p_cand[1]}) is out of bounds.", "field": "player_start", "cell": p_cand, "level_id": level_id}
            if layout_p_cells and layout_p_cells[0] != p_cand:
                return {"valid": False, "error": f"Level '{level_id}' has conflicting player start in layout ({layout_p_cells[0]}) and player_start ({p_cand}).", "field": "player_start", "cell": p_cand, "level_id": level_id}
            player_start_pos = p_cand
        elif layout_p_cells:
            player_start_pos = layout_p_cells[0]
        else:
            return {"valid": False, "error": f"Level '{level_id}' is missing required player start position ('P' in layout or 'player_start').", "field": "player_start", "cell": (-1, -1), "level_id": level_id}

        p_tile = terrain_map.get(player_start_pos, TileType.EMPTY)
        if p_tile == TileType.WALL:
            return {"valid": False, "error": f"Level '{level_id}' player start at ({player_start_pos[0]}, {player_start_pos[1]}) is inside an impassable wall.", "field": "player_start", "cell": player_start_pos, "level_id": level_id}
        elif p_tile == TileType.VOID:
            return {"valid": False, "error": f"Level '{level_id}' player start at ({player_start_pos[0]}, {player_start_pos[1]}) is inside an impassable void.", "field": "player_start", "cell": player_start_pos, "level_id": level_id}

        # 5. Exit portal validation
        if len(layout_e_cells) > 1:
            return {"valid": False, "error": f"Level '{level_id}' has {len(layout_e_cells)} duplicate exit portal markers in layout.", "field": "exit", "cell": layout_e_cells[1], "level_id": level_id}

        exit_pos = None
        if "exit_pos" in d:
            e_raw = d["exit_pos"]
            if not isinstance(e_raw, (list, tuple)) or len(e_raw) != 2:
                return {"valid": False, "error": f"Level '{level_id}' exit_pos must be a 2-element array [x, y].", "field": "exit_pos", "cell": (-1, -1), "level_id": level_id}
            e_cand = (int(e_raw[0]), int(e_raw[1]))
            if e_cand[0] < 0 or e_cand[0] >= w or e_cand[1] < 0 or e_cand[1] >= h:
                return {"valid": False, "error": f"Level '{level_id}' exit_pos ({e_cand[0]}, {e_cand[1]}) is out of bounds.", "field": "exit_pos", "cell": e_cand, "level_id": level_id}
            if layout_e_cells and layout_e_cells[0] != e_cand:
                return {"valid": False, "error": f"Level '{level_id}' has conflicting exit in layout ({layout_e_cells[0]}) and exit_pos ({e_cand}).", "field": "exit_pos", "cell": e_cand, "level_id": level_id}
            exit_pos = e_cand
        elif layout_e_cells:
            exit_pos = layout_e_cells[0]
        else:
            return {"valid": False, "error": f"Level '{level_id}' is missing required exit portal position ('E' in layout or 'exit_pos').", "field": "exit", "cell": (-1, -1), "level_id": level_id}

        e_tile = terrain_map.get(exit_pos, TileType.EMPTY)
        if e_tile == TileType.WALL:
            return {"valid": False, "error": f"Level '{level_id}' exit portal at ({exit_pos[0]}, {exit_pos[1]}) is inside an impassable wall.", "field": "exit", "cell": exit_pos, "level_id": level_id}
        elif e_tile == TileType.VOID:
            return {"valid": False, "error": f"Level '{level_id}' exit portal at ({exit_pos[0]}, {exit_pos[1]}) is inside an impassable void.", "field": "exit", "cell": exit_pos, "level_id": level_id}

        # 6. Sockets validation
        if "sockets" in d and isinstance(d["sockets"], list):
            for s_item in d["sockets"]:
                spos = tuple(s_item["pos"])
                if spos[0] < 0 or spos[0] >= w or spos[1] < 0 or spos[1] >= h:
                    return {"valid": False, "error": f"Level '{level_id}' socket coordinate {spos} is out of bounds.", "field": "sockets", "cell": spos, "level_id": level_id}
                st = terrain_map.get(spos, TileType.EMPTY)
                if st == TileType.WALL:
                    return {"valid": False, "error": f"Level '{level_id}' socket at {spos} cannot be placed on solid wall.", "field": "sockets", "cell": spos, "level_id": level_id}
                elif st == TileType.VOID:
                    return {"valid": False, "error": f"Level '{level_id}' socket at {spos} cannot be placed on void.", "field": "sockets", "cell": spos, "level_id": level_id}
                scol = s_item.get("color", BlockColor.NEUTRAL)
                if scol < 0 or scol > 4:
                    return {"valid": False, "error": f"Level '{level_id}' socket at {spos} has invalid color {scol}.", "field": "sockets", "cell": spos, "level_id": level_id}
                socket_map[spos] = scol

        # 7. Movable Blocks validation
        block_cells = {}
        if "blocks" in d and isinstance(d["blocks"], list):
            for b_idx, b in enumerate(d["blocks"]):
                b_pos_raw = b.get("pos")
                if not isinstance(b_pos_raw, (list, tuple)) or len(b_pos_raw) != 2:
                    return {"valid": False, "error": f"Level '{level_id}' block index {b_idx} pos must be [x, y].", "field": "blocks", "cell": (-1, -1), "level_id": level_id}
                b_pos = (int(b_pos_raw[0]), int(b_pos_raw[1]))

                if b_pos[0] < 0 or b_pos[0] >= w or b_pos[1] < 0 or b_pos[1] >= h:
                    return {"valid": False, "error": f"Level '{level_id}' block at index {b_idx} has out-of-bounds coordinate {b_pos}.", "field": "blocks", "cell": b_pos, "level_id": level_id}

                b_col = b.get("color", BlockColor.NEUTRAL)
                if b_col < 0 or b_col > 4:
                    return {"valid": False, "error": f"Level '{level_id}' block at {b_pos} has invalid fragment color {b_col} (must be 0..4).", "field": "blocks", "cell": b_pos, "level_id": level_id}

                if b_pos in block_cells:
                    return {"valid": False, "error": f"Level '{level_id}' has overlapping movable blocks at cell {b_pos}.", "field": "blocks", "cell": b_pos, "level_id": level_id}
                block_cells[b_pos] = b

                b_tile = terrain_map.get(b_pos, TileType.EMPTY)
                if b_tile == TileType.WALL:
                    return {"valid": False, "error": f"Level '{level_id}' movable block at {b_pos} is placed on an immutable wall.", "field": "blocks", "cell": b_pos, "level_id": level_id}

                if b_pos == player_start_pos:
                    return {"valid": False, "error": f"Level '{level_id}' movable block at {b_pos} overlaps player start position.", "field": "blocks", "cell": b_pos, "level_id": level_id}

                if b_pos == exit_pos:
                    return {"valid": False, "error": f"Level '{level_id}' movable block at {b_pos} overlaps exit portal.", "field": "blocks", "cell": b_pos, "level_id": level_id}

        # 8. Start-completed check
        allow_start_completed = d.get("allow_start_completed", False)
        if not allow_start_completed:
            if player_start_pos == exit_pos:
                all_sockets_ok = True
                for spos, req_col in socket_map.items():
                    if spos not in block_cells:
                        all_sockets_ok = False
                        break
                    cur_col = block_cells[spos].get("color", BlockColor.NEUTRAL)
                    if req_col != BlockColor.NEUTRAL and req_col != cur_col:
                        all_sockets_ok = False
                        break
                if all_sockets_ok:
                    return {"valid": False, "error": f"Level '{level_id}' starts in an already completed state at {player_start_pos}. Set 'allow_start_completed': true if intentional.", "field": "completion", "cell": player_start_pos, "level_id": level_id}

        return {"valid": True, "error": "", "field": "", "cell": (-1, -1), "level_id": level_id}


class BFSSolver:
    @staticmethod
    def solve(initial_state: BoardState, max_visited: int = 50000, timeout_sec: float = 5.0) -> Dict[str, Any]:
        t0 = time.time()
        if initial_state is None:
            return {
                "status": SolverStatus.INVALID_LEVEL,
                "status_string": SolverStatus.INVALID_LEVEL.value,
                "solved": False,
                "steps": -1,
                "actions": [],
                "visited_count": 0,
                "time_sec": 0.0,
                "message": "Initial state is null."
            }

        start_key = initial_state.get_canonical_key()
        if initial_state.is_completed:
            return {
                "status": SolverStatus.SOLVED,
                "status_string": SolverStatus.SOLVED.value,
                "solved": True,
                "steps": 0,
                "actions": [],
                "visited_count": 1,
                "time_sec": round(time.time() - t0, 4),
                "message": "Level already completed at start."
            }

        queue = deque([initial_state])
        visited = {start_key: True}
        parent_map = {}  # child_key -> (parent_key, action)
        win_key = None

        while queue:
            if len(visited) > max_visited:
                return {
                    "status": SolverStatus.LIMIT_REACHED,
                    "status_string": SolverStatus.LIMIT_REACHED.value,
                    "solved": False,
                    "steps": -1,
                    "actions": [],
                    "visited_count": len(visited),
                    "time_sec": round(time.time() - t0, 4),
                    "message": f"Search budget exceeded ({len(visited)} visited states)."
                }

            if timeout_sec > 0 and (time.time() - t0) >= timeout_sec:
                return {
                    "status": SolverStatus.LIMIT_REACHED,
                    "status_string": SolverStatus.LIMIT_REACHED.value,
                    "solved": False,
                    "steps": -1,
                    "actions": [],
                    "visited_count": len(visited),
                    "time_sec": round(time.time() - t0, 4),
                    "message": f"Search timed out after {round(time.time() - t0, 2)} seconds."
                }

            cur_state = queue.popleft()
            cur_key = cur_state.get_canonical_key()

            for act in CANDIDATE_ACTIONS:
                res = GameRules.apply_action(cur_state, act)
                if not res["success"]:
                    continue

                next_state = res["next_state"]
                next_key = next_state.get_canonical_key()

                if next_key in visited:
                    continue

                visited[next_key] = True
                parent_map[next_key] = (cur_key, act)

                if next_state.is_completed:
                    win_key = next_key
                    break

                queue.append(next_state)

            if win_key:
                break

        elapsed = round(time.time() - t0, 4)
        if win_key:
            actions = []
            curr = win_key
            while curr in parent_map:
                p_key, act = parent_map[curr]
                actions.append(act)
                curr = p_key
            actions.reverse()

            return {
                "status": SolverStatus.SOLVED,
                "status_string": SolverStatus.SOLVED.value,
                "solved": True,
                "steps": len(actions),
                "actions": actions,
                "visited_count": len(visited),
                "time_sec": elapsed,
                "message": f"Optimal solution found in {len(actions)} steps."
            }
        else:
            return {
                "status": SolverStatus.UNSOLVABLE,
                "status_string": SolverStatus.UNSOLVABLE.value,
                "solved": False,
                "steps": -1,
                "actions": [],
                "visited_count": len(visited),
                "time_sec": elapsed,
                "message": f"Proven unsolvable within finite state space ({len(visited)} visited states)."
            }

    @staticmethod
    def verify_solution(initial_state: BoardState, actions: List[ActionType]) -> Dict[str, Any]:
        if initial_state is None:
            return {
                "valid": False,
                "failed_step": 0,
                "failed_action": None,
                "rejection_reason": "null_initial_state",
                "message": "Initial state is null.",
                "final_state": None
            }

        cur = initial_state.duplicate()

        if not actions:
            if cur.is_completed:
                return {"valid": True, "failed_step": -1, "failed_action": None, "rejection_reason": "", "message": "Already completed.", "final_state": cur}
            else:
                return {"valid": False, "failed_step": 0, "failed_action": None, "rejection_reason": "empty_actions_uncompleted", "message": "Action sequence is empty but level not completed.", "final_state": cur}

        for idx, act in enumerate(actions):
            res = GameRules.apply_action(cur, act)
            if not res["success"]:
                return {
                    "valid": False,
                    "failed_step": idx,
                    "failed_action": act,
                    "rejection_reason": res.get("rejection_reason", "unknown"),
                    "message": f"Action {act} failed at step {idx}: {res.get('message', '')}",
                    "final_state": cur
                }
            cur = res["next_state"]

        if not cur.is_completed:
            return {
                "valid": False,
                "failed_step": len(actions),
                "failed_action": None,
                "rejection_reason": "not_completed_at_end",
                "message": f"All {len(actions)} actions succeeded but exit condition not met.",
                "final_state": cur
            }

        return {
            "valid": True,
            "failed_step": -1,
            "failed_action": None,
            "rejection_reason": "",
            "message": f"Solution verification passed: all {len(actions)} steps executed cleanly to completion.",
            "final_state": cur
        }


class HintService:
    @staticmethod
    def generate_hint(current_state: BoardState, max_visited: int = 20000) -> Dict[str, Any]:
        if current_state is None:
            return {"has_hint": False, "status": "INVALID", "next_action": None, "hint_text": "Board state is null."}

        if current_state.is_completed:
            return {"has_hint": True, "status": "COMPLETED", "next_action": None, "hint_text": "Level is already completed!", "remaining_steps": 0}

        solve_res = BFSSolver.solve(current_state, max_visited=max_visited)
        status_str = solve_res["status_string"]

        if status_str == "SOLVED":
            actions = solve_res["actions"]
            if not actions:
                return {"has_hint": True, "status": "COMPLETED", "next_action": None, "hint_text": "Standing on open exit portal!", "remaining_steps": 0}

            next_act = actions[0]
            dir_vec = ACTION_DIRS[next_act]
            dir_name = { (0, -1): "North", (1, 0): "East", (0, 1): "South", (-1, 0): "West" }.get(dir_vec, "forward")
            target_cell = (current_state.player_pos[0] + dir_vec[0], current_state.player_pos[1] + dir_vec[1])

            if next_act in (ActionType.MOVE_NORTH, ActionType.MOVE_EAST, ActionType.MOVE_SOUTH, ActionType.MOVE_WEST):
                if target_cell == current_state.exit_cell and current_state.is_all_sockets_satisfied():
                    text = f"Step {dir_name} into the open exit portal to complete the level."
                elif current_state.is_bridge_at(target_cell):
                    text = f"Step {dir_name} across the void bridge."
                else:
                    text = f"Step {dir_name} toward your next objective."
            else:
                if current_state.is_carrying():
                    col_name = ["Neutral", "Cyan", "Amber", "Magenta", "Emerald"][current_state.carried_block["color"]]
                    tile = current_state.tiles.get(target_cell, TileType.EMPTY)
                    if tile == TileType.VOID:
                        text = f"Place your carried {col_name} fragment {dir_name} to bridge the chasm."
                    elif target_cell in current_state.sockets:
                        req_name = ["Neutral", "Cyan", "Amber", "Magenta", "Emerald"][current_state.sockets[target_cell]]
                        text = f"Place your carried {col_name} fragment {dir_name} into the {req_name} socket."
                    else:
                        text = f"Place your carried {col_name} fragment {dir_name} to clear your path."
                else:
                    block = current_state.blocks.get(target_cell, {})
                    col_name = ["Neutral", "Cyan", "Amber", "Magenta", "Emerald"][block.get("color", 0)]
                    if current_state.is_bridge_at(target_cell):
                        text = f"Siphon the {col_name} bridge fragment {dir_name} back into your Pixel Glove."
                    elif target_cell in current_state.sockets:
                        text = f"Siphon the {col_name} fragment {dir_name} from the socket into your Pixel Glove."
                    else:
                        text = f"Siphon the {col_name} fragment {dir_name} into your Pixel Glove."

            return {
                "has_hint": True,
                "status": "SOLVED",
                "next_action": next_act,
                "direction": dir_vec,
                "hint_text": text,
                "remaining_steps": len(actions)
            }
        elif status_str == "LIMIT_REACHED":
            return {"has_hint": False, "status": "LIMIT_REACHED", "next_action": None, "hint_text": "Search budget exceeded. Try undoing a few steps (Z) or restart (R)."}
        else:
            return {"has_hint": False, "status": "UNSOLVABLE", "next_action": None, "hint_text": "No path to victory from this position. Press Z to Undo or R to Restart."}


def run_solver_validation_tests() -> int:
    print("=======================================================")
    print("   PHASE 4: PUZZLE SOLVER & LEVEL VALIDATION TESTS     ")
    print("=======================================================\n")

    passed = 0
    failed = 0

    def assert_eq(actual, expected, msg):
        nonlocal passed, failed
        if actual == expected:
            print(f"  [PASS] {msg}")
            passed += 1
        else:
            print(f"  [FAIL] {msg} -> Expected {expected}, got {actual}")
            failed += 1

    def assert_true(val, msg):
        assert_eq(bool(val), True, msg)

    # ---------------------------------------------------------
    # TEST 1: Simple route with no movable fragments
    # ---------------------------------------------------------
    lvl1 = {
        "id": "t1_simple",
        "name": "Simple Route",
        "width": 5, "height": 3,
        "layout": [
            "#####",
            "#P.E#",
            "#####"
        ]
    }
    v_res = LevelValidator.validate_level(lvl1)
    assert_true(v_res["valid"], "1. Level 1 layout is valid")
    s1 = load_level_from_dict(lvl1)
    sol1 = BFSSolver.solve(s1)
    assert_eq(sol1["status"], SolverStatus.SOLVED, "1. Solved simple route")
    assert_eq(sol1["steps"], 2, "1. Exactly 2 steps (MOVE_EAST -> MOVE_EAST)")
    assert_eq(sol1["actions"], [ActionType.MOVE_EAST, ActionType.MOVE_EAST], "1. Optimal action sequence")
    vr1 = BFSSolver.verify_solution(s1, sol1["actions"])
    assert_true(vr1["valid"], "1. Solution replay verification passed")

    # ---------------------------------------------------------
    # TEST 2: Puzzle requiring pickup (obstacle clearance)
    # ---------------------------------------------------------
    lvl2 = {
        "id": "t2_pickup",
        "name": "Pickup Obstacle",
        "width": 6, "height": 3,
        "layout": [
            "######",
            "#P..E#",
            "######"
        ],
        "blocks": [
            {"pos": [2, 1], "color": BlockColor.CYAN}
        ]
    }
    s2 = load_level_from_dict(lvl2)
    sol2 = BFSSolver.solve(s2)
    assert_eq(sol2["status"], SolverStatus.SOLVED, "2. Solved puzzle requiring pickup")
    assert_eq(sol2["actions"][0], ActionType.INTERACT_EAST, "2. First action must be INTERACT_EAST to siphon obstacle")
    vr2 = BFSSolver.verify_solution(s2, sol2["actions"])
    assert_true(vr2["valid"], "2. Replay verification passed for pickup puzzle")

    # ---------------------------------------------------------
    # TEST 3: Puzzle requiring bridge placement
    # ---------------------------------------------------------
    lvl3 = {
        "id": "t3_bridge",
        "name": "Bridge Chasm",
        "width": 6, "height": 3,
        "layout": [
            "######",
            "#P E#",
            "######"
        ],
        "blocks": [
            {"pos": [1, 1], "color": BlockColor.NEUTRAL} # Wait, placed at player start would be invalid!
        ]
    }
    # Place block next to player at (1, 2) wait wall, or start player holding block!
    s3 = BoardState(6, 3)
    for x in range(6):
        for y in range(3):
            s3.tiles[(x, y)] = TileType.WALL
    s3.tiles[(1, 1)] = TileType.FLOOR
    s3.tiles[(2, 1)] = TileType.VOID
    s3.tiles[(3, 1)] = TileType.FLOOR
    s3.tiles[(4, 1)] = TileType.FLOOR
    s3.player_pos = (1, 1)
    s3.exit_cell = (4, 1)
    s3.carried_block = {"id": 1, "color": BlockColor.CYAN}
    sol3 = BFSSolver.solve(s3)
    assert_eq(sol3["status"], SolverStatus.SOLVED, "3. Solved puzzle requiring bridge placement")
    assert_eq(sol3["actions"][0], ActionType.INTERACT_EAST, "3. First action places bridge eastward into void")
    vr3 = BFSSolver.verify_solution(s3, sol3["actions"])
    assert_true(vr3["valid"], "3. Bridge placement replay verification passed")

    # ---------------------------------------------------------
    # TEST 4: Puzzle requiring neutral socket
    # ---------------------------------------------------------
    lvl4 = {
        "id": "t4_neutral_socket",
        "name": "Neutral Socket",
        "width": 6, "height": 4,
        "layout": [
            "######",
            "#P..E#",
            "#. S.#",
            "######"
        ],
        "blocks": [
            {"pos": [2, 1], "color": BlockColor.MAGENTA}
        ]
    }
    s4 = load_level_from_dict(lvl4)
    sol4 = BFSSolver.solve(s4)
    assert_eq(sol4["status"], SolverStatus.SOLVED, "4. Solved neutral socket puzzle")
    vr4 = BFSSolver.verify_solution(s4, sol4["actions"])
    assert_true(vr4["valid"], "4. Neutral socket replay verification passed")
    assert_true(vr4["final_state"].is_socket_satisfied((3, 2)), "4. Socket is satisfied in final state")

    # ---------------------------------------------------------
    # TEST 5: Puzzle requiring colored socket
    # ---------------------------------------------------------
    # Player has Amber block, two sockets: Cyan (pos (3,1)) and Amber (pos (1,2))
    s5 = BoardState(5, 5)
    for x in range(5):
        for y in range(5):
            s5.tiles[(x, y)] = TileType.WALL
    s5.tiles[(2, 2)] = TileType.FLOOR # Player start
    s5.tiles[(3, 2)] = TileType.FLOOR # Cyan socket
    s5.tiles[(2, 1)] = TileType.FLOOR # Amber socket
    s5.tiles[(1, 2)] = TileType.FLOOR # Exit
    s5.player_pos = (2, 2)
    s5.exit_cell = (1, 2)
    s5.sockets[(3, 2)] = BlockColor.CYAN
    s5.sockets[(2, 1)] = BlockColor.AMBER
    # Player starts holding Amber block; only amber socket needs to be satisfied?
    # Both sockets must be satisfied! Let's provide a Cyan block at (2,3) floor
    s5.tiles[(2, 3)] = TileType.FLOOR
    s5.blocks[(2, 3)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    s5.carried_block = {"id": 2, "color": BlockColor.AMBER}
    sol5 = BFSSolver.solve(s5)
    assert_eq(sol5["status"], SolverStatus.SOLVED, "5. Solved colored socket puzzle")
    vr5 = BFSSolver.verify_solution(s5, sol5["actions"])
    assert_true(vr5["valid"], "5. Colored sockets replay verification passed")
    assert_true(vr5["final_state"].is_all_sockets_satisfied(), "5. All colored sockets satisfied")

    # ---------------------------------------------------------
    # TEST 6: Two indistinguishable fragments producing identical canonical key
    # ---------------------------------------------------------
    s6_a = BoardState(5, 5)
    s6_a.player_pos = (2, 2)
    s6_a.blocks[(1, 1)] = {"id": 10, "color": BlockColor.CYAN, "is_bridge": False}
    s6_a.blocks[(3, 3)] = {"id": 20, "color": BlockColor.CYAN, "is_bridge": False}

    s6_b = BoardState(5, 5)
    s6_b.player_pos = (2, 2)
    # Swap IDs between identical-color blocks
    s6_b.blocks[(1, 1)] = {"id": 20, "color": BlockColor.CYAN, "is_bridge": False}
    s6_b.blocks[(3, 3)] = {"id": 10, "color": BlockColor.CYAN, "is_bridge": False}

    assert_eq(s6_a.get_canonical_key(), s6_b.get_canonical_key(), "6. Identical block colors with swapped IDs produce identical canonical key")

    # Also test carrying block with different IDs:
    s6_c = BoardState(5, 5)
    s6_c.player_pos = (2, 2)
    s6_c.carried_block = {"id": 1, "color": BlockColor.CYAN}

    s6_d = BoardState(5, 5)
    s6_d.player_pos = (2, 2)
    s6_d.carried_block = {"id": 99, "color": BlockColor.CYAN}

    assert_eq(s6_c.get_canonical_key(), s6_d.get_canonical_key(), "6. Carried blocks with identical color but different IDs produce identical canonical key")

    # ---------------------------------------------------------
    # TEST 7: Deliberately impossible level (reports UNSOLVABLE)
    # ---------------------------------------------------------
    lvl7 = {
        "id": "t7_impossible",
        "name": "Sealed Vault",
        "width": 7, "height": 3,
        "layout": [
            "#######",
            "#P#.#E#",
            "#######"
        ]
    }
    s7 = load_level_from_dict(lvl7)
    sol7 = BFSSolver.solve(s7)
    assert_eq(sol7["status"], SolverStatus.UNSOLVABLE, "7. Impossible level reports UNSOLVABLE")
    assert_eq(sol7["solved"], False, "7. Solved is False")
    assert_eq(sol7["steps"], -1, "7. Steps is -1")

    # ---------------------------------------------------------
    # TEST 8: Invalid level (reports validation failure with specific field/coords)
    # ---------------------------------------------------------
    lvl8_wall_block = {
        "id": "t8_invalid",
        "name": "Wall Block Error",
        "width": 5, "height": 3,
        "layout": [
            "#####",
            "#P.E#",
            "#####"
        ],
        "blocks": [
            {"pos": [2, 0], "color": BlockColor.CYAN} # Block on wall at (2, 0)
        ]
    }
    v_res8 = LevelValidator.validate_level(lvl8_wall_block)
    assert_eq(v_res8["valid"], False, "8. Block on wall rejected")
    assert_eq(v_res8["cell"], (2, 0), "8. Error names offending cell (2, 0)")
    assert_true("immutable wall" in v_res8["error"], "8. Error message specifies immutable wall rule")

    # Ragged layout check
    lvl8_ragged = {
        "id": "t8_ragged",
        "name": "Ragged",
        "width": 5, "height": 3,
        "layout": [
            "#####",
            "#P.E", # Length 4 instead of 5
            "#####"
        ]
    }
    v_res_ragged = LevelValidator.validate_level(lvl8_ragged)
    assert_eq(v_res_ragged["valid"], False, "8. Ragged layout rejected")
    assert_true("ragged layout" in v_res_ragged["error"], "8. Error specifies ragged layout")

    # Overlapping blocks check
    lvl8_overlap = {
        "id": "t8_overlap",
        "name": "Overlap",
        "width": 5, "height": 3,
        "layout": [
            "#####",
            "#P.E#",
            "#####"
        ],
        "blocks": [
            {"pos": [2, 1], "color": BlockColor.CYAN},
            {"pos": [2, 1], "color": BlockColor.AMBER}
        ]
    }
    v_res_overlap = LevelValidator.validate_level(lvl8_overlap)
    assert_eq(v_res_overlap["valid"], False, "8. Overlapping blocks rejected")
    assert_eq(v_res_overlap["cell"], (2, 1), "8. Overlap coordinates identified")

    # ---------------------------------------------------------
    # TEST 9: Multi-step puzzle requiring multiple steals and placements
    # ---------------------------------------------------------
    # demo_02 requires: siphon block -> step east -> place bridge -> step east -> step east -> step east
    lvl9 = {
        "id": "t9_multistep",
        "name": "Demo 02 Bridge Crossing",
        "width": 8, "height": 5,
        "layout": [
            "########",
            "#P... E#",
            "#..#### #",
            "#..#    #",
            "########"
        ],
        "blocks": [
            {"pos": [2, 1], "color": BlockColor.CYAN}
        ]
    }
    s9 = load_level_from_dict(lvl9)
    sol9 = BFSSolver.solve(s9)
    assert_eq(sol9["status"], SolverStatus.SOLVED, "9. Multi-step puzzle solved")
    assert_true(sol9["steps"] >= 5, f"9. Requires multiple steps (actual: {sol9['steps']})")
    vr9 = BFSSolver.verify_solution(s9, sol9["actions"])
    assert_true(vr9["valid"], "9. Multi-step solution replay verification succeeded")

    # ---------------------------------------------------------
    # TEST 10: Equivalent states with reordered fragments produce same canonical hash
    # ---------------------------------------------------------
    s10_1 = BoardState(6, 6)
    s10_1.player_pos = (2, 2)
    s10_1.blocks[(1, 2)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    s10_1.blocks[(3, 2)] = {"id": 2, "color": BlockColor.AMBER, "is_bridge": False}
    s10_1.blocks[(2, 3)] = {"id": 3, "color": BlockColor.EMERALD, "is_bridge": True}

    s10_2 = BoardState(6, 6)
    s10_2.player_pos = (2, 2)
    # Insert in different order
    s10_2.blocks[(2, 3)] = {"id": 3, "color": BlockColor.EMERALD, "is_bridge": True}
    s10_2.blocks[(1, 2)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    s10_2.blocks[(3, 2)] = {"id": 2, "color": BlockColor.AMBER, "is_bridge": False}

    assert_eq(s10_1.get_canonical_key(), s10_2.get_canonical_key(), "10. Insertion order differences produce identical canonical keys")
    assert_eq(s10_1.get_state_hash(), s10_2.get_state_hash(), "10. Hashes match identically")

    # ---------------------------------------------------------
    # TEST 11: Current-state hint after several moves
    # ---------------------------------------------------------
    s11 = load_level_from_dict(lvl9) # Player at (1,1), block at (2,1)
    # Advance 1 step: INTERACT_EAST to siphon the block
    res_step1 = GameRules.apply_action(s11, ActionType.INTERACT_EAST)
    assert_true(res_step1["success"], "11. Move 1 succeeded")
    state_after_step1 = res_step1["next_state"]

    hint1 = HintService.generate_hint(state_after_step1)
    assert_true(hint1["has_hint"], "11. Hint generated from intermediate state")
    assert_eq(hint1["status"], "SOLVED", "11. Hint status is SOLVED")
    assert_eq(hint1["next_action"], ActionType.MOVE_EAST, "11. Hint suggests moving East next")
    assert_true("East" in hint1["hint_text"], "11. Hint mentions East direction")

    # Unwinnable state hint check
    s11_unwinnable = load_level_from_dict(lvl7)
    hint_fail = HintService.generate_hint(s11_unwinnable)
    assert_eq(hint_fail["has_hint"], False, "11. Unwinnable state has has_hint=False")
    assert_eq(hint_fail["status"], "UNSOLVABLE", "11. Unwinnable state has status=UNSOLVABLE")
    assert_true("Undo" in hint_fail["hint_text"], "11. Hint recommends Undo or Restart")

    # ---------------------------------------------------------
    # TEST 12: Search limit behavior (reports LIMIT_REACHED with max_visited=5)
    # ---------------------------------------------------------
    s12 = load_level_from_dict(lvl9)
    sol12 = BFSSolver.solve(s12, max_visited=5)
    assert_eq(sol12["status"], SolverStatus.LIMIT_REACHED, "12. Search limit reached reports LIMIT_REACHED")
    assert_eq(sol12["solved"], False, "12. Solved is False")
    assert_true(sol12["visited_count"] > 5, "12. Visited count reflects threshold")
    assert_true("budget" in sol12["message"].lower(), "12. Message specifies budget exceeded")

    # ---------------------------------------------------------
    # TEST 13: Solution replay verification passes & catches illegal modifications
    # ---------------------------------------------------------
    s13 = load_level_from_dict(lvl1)
    sol13 = BFSSolver.solve(s13)
    vr13_good = BFSSolver.verify_solution(s13, sol13["actions"])
    assert_true(vr13_good["valid"], "13. Replay verification passes on genuine solution")

    # Tamper with action sequence: inject move into wall
    tampered_actions = [ActionType.MOVE_NORTH] + sol13["actions"]
    vr13_bad = BFSSolver.verify_solution(s13, tampered_actions)
    assert_eq(vr13_bad["valid"], False, "13. Replay verification catches illegal move")
    assert_eq(vr13_bad["failed_step"], 0, "13. Identified step 0 as failure")
    assert_eq(vr13_bad["rejection_reason"], "blocked_wall", "13. Rejection reason is blocked_wall")

    # ---------------------------------------------------------
    # TEST 14: Solver solution followed by live model completion
    # ---------------------------------------------------------
    s14 = load_level_from_dict(lvl1)
    hist14 = HistoryManager(s14)
    sol14 = BFSSolver.solve(s14)

    cur14 = hist14.get_current_state()
    for act in sol14["actions"]:
        step_res = GameRules.apply_action(cur14, act)
        assert_true(step_res["success"], "14. Model action executed cleanly")
        cur14 = step_res["next_state"]
        hist14.record_state(cur14)

    assert_true(hist14.get_current_state().is_completed, "14. Live model reached completed status")
    assert_eq(hist14.get_current_state().player_pos, (3, 1), "14. Final player position matches exit")

    print("\n-------------------------------------------")
    print(f"Phase 4 Test Results: {passed} executed | {failed} failed.")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(run_solver_validation_tests())
