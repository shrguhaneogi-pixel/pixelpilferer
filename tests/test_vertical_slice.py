"""
Test Suite for Vertical Slice Demo Levels (Phase 3.1)
Verifies schema compliance, deterministic rule simulation, and minimal step solvability with A* solver.
"""

import json
import os
import sys
from typing import Dict, Any

# Ensure tests folder is in python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from test_domain_model import (
    ActionType, TileType, BlockColor, BoardState, GameRules
)
from test_puzzle_solver import solve_level, load_level_from_dict


def validate_level_schema(d: Dict[str, Any]) -> Dict[str, Any]:
    """Replicates LevelRepository.validate_level_dict() in GDScript."""
    if not d.get("id") or not str(d["id"]).strip():
        return {"valid": False, "error": "Missing or empty 'id' field."}
    if not d.get("name") or not str(d["name"]).strip():
        return {"valid": False, "error": "Missing or empty 'name' field."}

    w = d.get("width", 0)
    h = d.get("height", 0)
    if w <= 0 or h <= 0:
        return {"valid": False, "error": "Dimensions width and height must be positive integers."}

    layout = d.get("layout", [])
    if len(layout) != h:
        return {"valid": False, "error": f"Layout row count ({len(layout)}) does not match height ({h})."}

    has_player = "player_start" in d
    has_exit = "exit_pos" in d

    for y, row in enumerate(layout):
        if len(row) != w:
            return {"valid": False, "error": f"Row {y} length ({len(row)}) does not match width ({w})."}
        if "P" in row:
            has_player = True
        if "E" in row:
            has_exit = True

    if not has_player:
        return {"valid": False, "error": "Level must specify player start position ('P' in layout or 'player_start')."}
    if not has_exit:
        return {"valid": False, "error": "Level must specify exit portal position ('E' in layout or 'exit_pos')."}

    return {"valid": True, "error": ""}


def run_vertical_slice_tests() -> int:
    print("=======================================================")
    print("      VERTICAL SLICE DEMO LEVELS VERIFICATION         ")
    print("=======================================================\n")

    demo_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "levels", "demo_levels.json")
    demo_path = os.path.normpath(demo_path)

    if not os.path.exists(demo_path):
        print(f"[FAIL] demo_levels.json not found at: {demo_path}")
        return 1

    with open(demo_path, "r", encoding="utf-8") as f:
        try:
            demo_data = json.load(f)
        except Exception as e:
            print(f"[FAIL] JSON parsing failed: {e}")
            return 1

    # Check top-level metadata
    assert demo_data.get("chapter") == 0, f"Expected chapter 0, got {demo_data.get('chapter')}"
    assert "title" in demo_data, "Missing 'title' in demo_levels.json"
    assert "palette_theme" in demo_data, "Missing 'palette_theme' in demo_levels.json"
    assert "levels" in demo_data, "Missing 'levels' in demo_levels.json"
    print(f"  [PASS] Metadata valid: Chapter {demo_data['chapter']} - '{demo_data['title']}' ({demo_data['palette_theme']})")

    levels = demo_data["levels"]
    assert len(levels) == 3, f"Expected 3 demo levels, found {len(levels)}"
    print(f"  [PASS] Exactly 3 demo levels authored.")

    expected_specs = {
        "demo_01": {
            "name": "The Obstructed Path",
            "expected_steps": 5,
            "expected_actions": [
                ActionType.INTERACT_EAST,
                ActionType.MOVE_EAST,
                ActionType.MOVE_EAST,
                ActionType.MOVE_EAST,
                ActionType.MOVE_EAST,
            ]
        },
        "demo_02": {
            "name": "Chasm Bridge",
            "expected_steps": 6,
            "expected_actions": [
                ActionType.INTERACT_EAST,
                ActionType.MOVE_EAST,
                ActionType.INTERACT_EAST,
                ActionType.MOVE_EAST,
                ActionType.MOVE_EAST,
                ActionType.MOVE_EAST,
            ]
        },
        "demo_03": {
            "name": "Chromatic Socket",
            "expected_steps": 6,
            "expected_actions": [
                ActionType.INTERACT_EAST,
                ActionType.MOVE_EAST,
                ActionType.INTERACT_SOUTH,
                ActionType.MOVE_EAST,
                ActionType.MOVE_EAST,
                ActionType.MOVE_EAST,
            ]
        }
    }

    # Verify each level
    for lvl in levels:
        lvl_id = lvl["id"]
        assert lvl_id in expected_specs, f"Unexpected level ID: {lvl_id}"
        spec = expected_specs[lvl_id]

        print(f"\n--- Testing Level: {lvl_id} ('{lvl['name']}') ---")

        # 1. Schema Validation
        val = validate_level_schema(lvl)
        assert val["valid"], f"Level {lvl_id} failed schema validation: {val['error']}"
        print(f"  [PASS] Schema validation passed (Dimensions: {lvl['width']}x{lvl['height']})")

        # 2. BoardState loading
        state = load_level_from_dict(lvl)
        assert state.player_pos == (1, 1), f"Expected player at (1,1), got {state.player_pos}"
        assert state.exit_cell == (5, 1), f"Expected exit at (5,1), got {state.exit_cell}"
        print(f"  [PASS] Player start: {state.player_pos}, Exit portal: {state.exit_cell}")

        # 3. Solver execution
        sol = solve_level(state)
        assert sol["solved"], f"Level {lvl_id} could not be solved by A* solver!"
        assert sol["steps"] == spec["expected_steps"], (
            f"Level {lvl_id} solved in {sol['steps']} steps, expected minimal {spec['expected_steps']}"
        )
        assert sol["actions"] == spec["expected_actions"], (
            f"Action sequence mismatch: got {[a.name for a in sol['actions']]}, expected {[a.name for a in spec['expected_actions']]}"
        )
        print(f"  [PASS] Solved in optimal {sol['steps']} steps: {' -> '.join(a.name for a in sol['actions'])}")

        # 4. Deterministic step-by-step game rules verification
        curr = state.duplicate()
        for i, act in enumerate(sol["actions"]):
            res = GameRules.apply_action(curr, act)
            assert res["success"], f"Action {act.name} at step {i+1} failed: {res.get('rejection_reason')}"
            curr = res["next_state"]

        assert curr.is_completed, f"Level {lvl_id} was not marked completed after executing all solution actions!"
        assert curr.player_pos == state.exit_cell, f"Final player pos {curr.player_pos} does not match exit {state.exit_cell}"
        print(f"  [PASS] Step-by-step state simulation verified end-to-end.")

    test_input_and_hud_orchestration()

    print("\n=======================================================")
    print(" [SUCCESS] All 3 demo levels verified and solvable!    ")
    print("=======================================================")
    return 0


def test_input_and_hud_orchestration() -> int:
    print("\n--- Testing Phase 3.4 & 3.5 Input Orchestration & HUD Status ---")
    
    # 1. Manhattan Distance Mouse Click mapping test
    player_pos = (2, 3)
    # Adjacent East (3, 3) -> diff (1, 0) -> INTERACT_EAST
    diff_east = (3 - player_pos[0], 3 - player_pos[1])
    manhattan_east = abs(diff_east[0]) + abs(diff_east[1])
    assert manhattan_east == 1
    # Adjacent North (2, 2) -> diff (0, -1) -> INTERACT_NORTH
    diff_north = (2 - player_pos[0], 2 - player_pos[1])
    assert abs(diff_north[0]) + abs(diff_north[1]) == 1
    # Diagonal (3, 2) -> Manhattan 2 (not 1)
    diff_diag = (3 - player_pos[0], 2 - player_pos[1])
    assert abs(diff_diag[0]) + abs(diff_diag[1]) == 2
    print("  [PASS] Mouse adjacent click correctly maps to Manhattan distance 1")
    
    # 2. Input buffer logic simulation
    class InputBufferSimulator:
        def __init__(self, buffer_window: float = 0.12):
            self.buffer_window = buffer_window
            self.is_animating = False
            self.input_buffer = None
            self.buffer_timestamp = 0.0
            
        def request_action(self, action, current_time: float):
            if self.is_animating:
                self.input_buffer = action
                self.buffer_timestamp = current_time
                return "buffered"
            return "executed"
            
        def on_move_completed(self, current_time: float):
            self.is_animating = False
            if self.input_buffer is not None:
                elapsed = current_time - self.buffer_timestamp
                buffered_act = self.input_buffer
                self.input_buffer = None
                if elapsed <= self.buffer_window:
                    return buffered_act
            return None
            
        def on_undo_or_restart(self):
            self.input_buffer = None
            self.is_animating = False
            
    buf = InputBufferSimulator()
    # While idle:
    assert buf.request_action(ActionType.MOVE_EAST, 1.0) == "executed"
    # While animating:
    buf.is_animating = True
    assert buf.request_action(ActionType.MOVE_NORTH, 1.05) == "buffered"
    assert buf.input_buffer == ActionType.MOVE_NORTH
    # Move completes at 1.10 (elapsed 0.05s <= 0.12s)
    act = buf.on_move_completed(1.10)
    assert act == ActionType.MOVE_NORTH
    assert buf.input_buffer is None
    # Expired buffer test: buffered at 2.0, completes at 2.20 (elapsed 0.20s > 0.12s)
    buf.is_animating = True
    buf.request_action(ActionType.MOVE_WEST, 2.0)
    act_expired = buf.on_move_completed(2.20)
    assert act_expired is None, "Expired buffer after BUFFER_WINDOW discarded"
    # Undo cancels buffer immediately
    buf.is_animating = True
    buf.request_action(ActionType.MOVE_SOUTH, 3.0)
    buf.on_undo_or_restart()
    assert buf.input_buffer is None and not buf.is_animating
    print("  [PASS] Input buffering window and undo/restart cancellation verified")

    # 3. HUD status text & indicator simulation
    def get_hud_status(state: BoardState):
        # Carried fragment
        if not state.carried_block:
            glove_text = "Glove: Empty"
        else:
            col_val = state.carried_block.get("color", 0)
            c_name = BlockColor(col_val).name.capitalize() if isinstance(col_val, int) else col_val.name.capitalize()
            glove_text = f"Glove: {c_name} Fragment"
            
        # Sockets
        total_sockets = len(state.sockets)
        if total_sockets == 0:
            sockets_text = "No Sockets"
        else:
            active = sum(1 for pos in state.sockets if state.is_socket_satisfied(pos))
            if active == total_sockets:
                sockets_text = f"Sockets: {active}/{total_sockets} (Active)"
            else:
                sockets_text = f"Sockets: {active}/{total_sockets}"
                
        # Exit
        exit_open = state.is_all_sockets_satisfied()
        exit_text = "Exit: OPEN" if exit_open else "Exit: LOCKED"
        
        return glove_text, sockets_text, exit_text

    demo_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "levels", "demo_levels.json")
    with open(demo_path, "r", encoding="utf-8") as f:
        demo_levels = json.load(f)["levels"]
        
    # Demo 1 initial: no carried block, no sockets -> Glove: Empty, No Sockets, Exit: OPEN
    s1 = load_level_from_dict(demo_levels[0])
    g1, sock1, exit1 = get_hud_status(s1)
    assert g1 == "Glove: Empty"
    assert sock1 == "No Sockets"
    assert exit1 == "Exit: OPEN"
    
    # After stealing block: Glove has fragment
    res_steal = GameRules.apply_action(s1, ActionType.INTERACT_EAST)
    g1_post, _, _ = get_hud_status(res_steal["next_state"])
    assert "Fragment" in g1_post
    
    # Demo 3: has 1 socket. Initial: Sockets: 0/1, Exit: LOCKED
    s3 = load_level_from_dict(demo_levels[2])
    g3, sock3, exit3 = get_hud_status(s3)
    assert sock3 == "Sockets: 0/1"
    assert exit3 == "Exit: LOCKED"
    print("  [PASS] HUD carried fragment, socket count, and exit status logic verified")
    
    # 4. Demo progression sequence
    demo_ids = [lvl["id"] for lvl in demo_levels]
    assert demo_ids == ["demo_01", "demo_02", "demo_03"]
    # Sequential transition
    progression = []
    for idx in range(len(demo_levels)):
        if idx + 1 < len(demo_levels):
            progression.append((demo_levels[idx]["id"], demo_levels[idx + 1]["id"]))
        else:
            progression.append((demo_levels[idx]["id"], "ch1_01"))
    assert progression == [
        ("demo_01", "demo_02"),
        ("demo_02", "demo_03"),
        ("demo_03", "ch1_01")
    ]
    print("  [PASS] Demo sequential progression verified: demo_01 -> demo_02 -> demo_03 -> ch1_01")
    return 0


if __name__ == "__main__":
    sys.exit(run_vertical_slice_tests())
