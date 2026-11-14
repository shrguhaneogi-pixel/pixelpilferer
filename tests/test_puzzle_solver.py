"""
A* and BFS Puzzle Solver and Solvability Verifier for all 20 Handcrafted Levels
"""

import json
import os
import sys
import time
import heapq
from collections import deque
from typing import Dict, List, Tuple, Optional, Any

from test_domain_model import (
    ActionType, TileType, BlockColor, BoardState, GameRules, ACTION_DIRS
)

CANDIDATE_ACTIONS = [
    ActionType.MOVE_NORTH,
    ActionType.MOVE_EAST,
    ActionType.MOVE_SOUTH,
    ActionType.MOVE_WEST,
    ActionType.INTERACT_NORTH,
    ActionType.INTERACT_EAST,
    ActionType.INTERACT_SOUTH,
    ActionType.INTERACT_WEST,
]

def load_level_from_dict(d: Dict[str, Any]) -> BoardState:
    w = d.get("width", 10)
    h = d.get("height", 8)
    state = BoardState(w, h)
    layout = d.get("layout", [])

    block_id = 1
    for y, row in enumerate(layout):
        for x, ch in enumerate(row):
            pos = (x, y)
            if ch == "#":
                state.tiles[pos] = TileType.WALL
            elif ch == ".":
                state.tiles[pos] = TileType.FLOOR
            elif ch == " ":
                state.tiles[pos] = TileType.VOID
            elif ch == "P":
                state.tiles[pos] = TileType.FLOOR
                state.player_pos = pos
            elif ch == "E":
                state.tiles[pos] = TileType.FLOOR
                state.exit_cell = pos
            elif ch == "S":
                state.tiles[pos] = TileType.FLOOR
                state.sockets[pos] = BlockColor.NEUTRAL
            elif ch == "1":
                state.tiles[pos] = TileType.FLOOR
                state.sockets[pos] = BlockColor.CYAN
            elif ch == "2":
                state.tiles[pos] = TileType.FLOOR
                state.sockets[pos] = BlockColor.AMBER
            elif ch == "3":
                state.tiles[pos] = TileType.FLOOR
                state.sockets[pos] = BlockColor.MAGENTA
            elif ch == "4":
                state.tiles[pos] = TileType.FLOOR
                state.sockets[pos] = BlockColor.EMERALD
            else:
                state.tiles[pos] = TileType.FLOOR

    if "player_start" in d:
        state.player_pos = tuple(d["player_start"])
    if "exit_pos" in d:
        state.exit_cell = tuple(d["exit_pos"])

    if "blocks" in d:
        for b in d["blocks"]:
            pos = (b["pos"][0], b["pos"][1])
            col = b.get("color", BlockColor.NEUTRAL)
            is_br = b.get("is_bridge", False)
            state.blocks[pos] = {
                "id": block_id,
                "color": col,
                "is_bridge": is_br
            }
            block_id += 1

    return state


def heuristic(state: BoardState) -> int:
    unsatisfied = sum(1 for pos in state.sockets if not state.is_socket_satisfied(pos))
    if unsatisfied == 0:
        return abs(state.player_pos[0] - state.exit_cell[0]) + abs(state.player_pos[1] - state.exit_cell[1])
    cost = unsatisfied * 20
    if state.carried_block:
        carried_col = state.carried_block["color"]
        for pos, col in state.sockets.items():
            if (col == carried_col or col == BlockColor.NEUTRAL) and not state.is_socket_satisfied(pos):
                cost += abs(state.player_pos[0] - pos[0]) + abs(state.player_pos[1] - pos[1])
                break
    else:
        cost += 10
    return cost


def solve_level(initial_state: BoardState, max_visited: int = 60000) -> Dict[str, Any]:
    t0 = time.time()
    start_hash = initial_state.get_state_hash()

    if initial_state.is_completed:
        return {
            "solved": True,
            "steps": 0,
            "actions": [],
            "visited_count": 1,
            "time_sec": round(time.time() - t0, 3)
        }

    start_h = heuristic(initial_state)
    counter = 0
    # Priority Queue: (f_score, g_score, counter, state, actions)
    pq = [(start_h, 0, counter, initial_state, [])]
    visited = {start_hash: 0}

    while pq:
        if len(visited) > max_visited:
            return {
                "solved": False,
                "steps": -1,
                "actions": [],
                "visited_count": len(visited),
                "time_sec": round(time.time() - t0, 3),
                "error": "Exceeded max visited states limit"
            }

        f, g, _, state, actions = heapq.heappop(pq)

        if state.is_completed:
            return {
                "solved": True,
                "steps": len(actions),
                "actions": actions,
                "visited_count": len(visited),
                "time_sec": round(time.time() - t0, 3)
            }

        for act in CANDIDATE_ACTIONS:
            res = GameRules.apply_action(state, act)
            if not res["success"]:
                continue
            next_state = res["next_state"]

            nh = next_state.get_state_hash()
            ng = g + 1
            if nh in visited and visited[nh] <= ng:
                continue

            visited[nh] = ng
            counter += 1
            nf = ng + heuristic(next_state)
            heapq.heappush(pq, (nf, ng, counter, next_state, actions + [act]))

    return {
        "solved": False,
        "steps": -1,
        "actions": [],
        "visited_count": len(visited),
        "time_sec": round(time.time() - t0, 3),
        "error": "No solution found"
    }


def verify_demo_levels(levels_dir: str = "data/levels") -> bool:
    print("=== Verifying Demo Levels with Solver ===")
    demo_path = os.path.join(levels_dir, "demo_levels.json")
    if not os.path.exists(demo_path):
        print(f"Error: Demo level file not found at {demo_path}")
        return False

    with open(demo_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    expected_steps = {
        "demo_01": 5,
        "demo_02": 6,
        "demo_03": 6
    }
    all_passed = True
    levels = data.get("levels", [])
    if len(levels) != 3:
        print(f"Error: Expected 3 demo levels, found {len(levels)}")
        return False

    for lvl in levels:
        lvl_id = lvl["id"]
        lvl_name = lvl["name"]
        state = load_level_from_dict(lvl)
        res = solve_level(state)
        if not res["solved"]:
            print(f"  [FAILED] {lvl_id} - '{lvl_name}': {res.get('error', 'Unsolvable')}")
            all_passed = False
            continue
        exp = expected_steps.get(lvl_id)
        if exp is not None and res["steps"] != exp:
            print(f"  [WARN] {lvl_id} solved in {res['steps']} steps (expected minimal: {exp})")
            if res["steps"] > exp:
                all_passed = False
        action_names = [act.name for act in res["actions"]]
        print(f"  [SOLVED] {lvl_id} - '{lvl_name}': {res['steps']} steps (Visited: {res['visited_count']}, Time: {res['time_sec']}s)")
        print(f"           Steps: {' -> '.join(action_names)}")
    return all_passed


def verify_all_levels(levels_dir: str = "data/levels") -> bool:
    print("=== Verifying All Handcrafted and Demo Levels with Solver ===")
    total_levels = 0
    solved_levels = 0

    chapter_files = sorted([f for f in os.listdir(levels_dir) if f.endswith(".json")])
    if not chapter_files:
        print(f"Error: No level files found in {levels_dir}")
        return False

    summary_rows = []

    for cf in chapter_files:
        path = os.path.join(levels_dir, cf)
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

        chapter_num = data.get("chapter", 0)
        chapter_title = data.get("title", "Unknown")
        print(f"\n--- Chapter {chapter_num}: {chapter_title} ({cf}) ---")

        for lvl in data.get("levels", []):
            total_levels += 1
            lvl_id = lvl["id"]
            lvl_name = lvl["name"]

            state = load_level_from_dict(lvl)
            res = solve_level(state)

            if res["solved"]:
                solved_levels += 1
                action_names = [act.name for act in res["actions"][:6]]
                suffix = "..." if len(res["actions"]) > 6 else ""
                print(f"  [SOLVED] {lvl_id} - '{lvl_name}': {res['steps']} steps (Visited: {res['visited_count']}, Time: {res['time_sec']}s)")
                print(f"           Preview: {' -> '.join(action_names)}{suffix}")
                summary_rows.append((chapter_num, lvl_id, lvl_name, res["steps"], res["visited_count"]))
            else:
                print(f"  [FAILED] {lvl_id} - '{lvl_name}': {res.get('error', 'Unsolvable')}")

    print("\n===========================================")
    print(f"Solvability Result: {solved_levels} / {total_levels} levels verified solvable.")
    return total_levels >= 20 and solved_levels == total_levels


if __name__ == "__main__":
    if len(sys.argv) > 1:
        success = verify_all_levels(sys.argv[1])
    else:
        success = verify_all_levels("data/levels")
    sys.exit(0 if success else 1)
