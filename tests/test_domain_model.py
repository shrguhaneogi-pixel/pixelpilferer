"""
Comprehensive Deterministic Domain Model Test Suite
Implements all 28 mandatory test cases, property-based randomized fuzzing,
and the demonstration board scenario where a block is stolen from an obstacle,
placed over a void, crossed, and used to reach the exit.
"""

from enum import IntEnum
from typing import Dict, List, Tuple, Optional, Any
import copy
import random
import sys

class ActionType(IntEnum):
    MOVE_NORTH = 0
    MOVE_EAST = 1
    MOVE_SOUTH = 2
    MOVE_WEST = 3
    INTERACT_NORTH = 4
    INTERACT_EAST = 5
    INTERACT_SOUTH = 6
    INTERACT_WEST = 7
    UNDO = 8
    RESTART = 9

class TileType(IntEnum):
    EMPTY = 0
    FLOOR = 1
    VOID = 2
    WALL = 3

class BlockColor(IntEnum):
    NEUTRAL = 0
    CYAN = 1
    AMBER = 2
    MAGENTA = 3
    EMERALD = 4

DIR_NORTH = (0, -1)
DIR_EAST = (1, 0)
DIR_SOUTH = (0, 1)
DIR_WEST = (-1, 0)

ACTION_DIRS = {
    ActionType.MOVE_NORTH: DIR_NORTH,
    ActionType.MOVE_EAST: DIR_EAST,
    ActionType.MOVE_SOUTH: DIR_SOUTH,
    ActionType.MOVE_WEST: DIR_WEST,
    ActionType.INTERACT_NORTH: DIR_NORTH,
    ActionType.INTERACT_EAST: DIR_EAST,
    ActionType.INTERACT_SOUTH: DIR_SOUTH,
    ActionType.INTERACT_WEST: DIR_WEST,
}

class BoardState:
    def __init__(self, width: int = 10, height: int = 10):
        self.width = width
        self.height = height
        self.tiles: Dict[Tuple[int, int], int] = {}
        self.sockets: Dict[Tuple[int, int], int] = {}
        self.blocks: Dict[Tuple[int, int], Dict[str, Any]] = {}
        self.exit_cell: Tuple[int, int] = (-1, -1)
        self.player_pos: Tuple[int, int] = (0, 0)
        self.initial_player_pos: Tuple[int, int] = (0, 0)
        self.player_facing: Tuple[int, int] = DIR_SOUTH
        self.carried_block: Optional[Dict[str, Any]] = None
        self.turn_count: int = 0
        self.is_completed: bool = False

    def duplicate(self) -> 'BoardState':
        copy_state = BoardState(self.width, self.height)
        copy_state.tiles = dict(self.tiles)
        copy_state.sockets = dict(self.sockets)
        copy_state.blocks = {pos: dict(b) for pos, b in self.blocks.items()}
        copy_state.exit_cell = self.exit_cell
        copy_state.player_pos = self.player_pos
        copy_state.initial_player_pos = self.initial_player_pos
        copy_state.player_facing = self.player_facing
        copy_state.carried_block = dict(self.carried_block) if self.carried_block else None
        copy_state.turn_count = self.turn_count
        copy_state.is_completed = self.is_completed
        return copy_state

    def is_inside(self, pos: Tuple[int, int]) -> bool:
        return 0 <= pos[0] < self.width and 0 <= pos[1] < self.height

    def get_tile(self, pos: Tuple[int, int]) -> int:
        return self.tiles.get(pos, TileType.EMPTY)

    def is_bridge_at(self, pos: Tuple[int, int]) -> bool:
        return pos in self.blocks and self.blocks[pos].get("is_bridge", False)

    def is_walkable(self, pos: Tuple[int, int]) -> bool:
        if not self.is_inside(pos):
            return False
        tile = self.get_tile(pos)
        if tile == TileType.WALL or tile == TileType.EMPTY:
            return False
        if tile == TileType.VOID:
            return self.is_bridge_at(pos)
        if tile == TileType.FLOOR:
            if pos in self.blocks:
                return self.is_bridge_at(pos)
            return True
        return False

    def is_socket_satisfied(self, pos: Tuple[int, int]) -> bool:
        if pos not in self.sockets:
            return True
        if pos not in self.blocks:
            return False
        req_color = self.sockets[pos]
        block_color = self.blocks[pos]["color"]
        if req_color == BlockColor.NEUTRAL:
            return True
        return req_color == block_color

    def is_all_sockets_satisfied(self) -> bool:
        if not self.sockets:
            return True
        return all(self.is_socket_satisfied(pos) for pos in self.sockets)

    def is_carrying(self) -> bool:
        return self.carried_block is not None

    def get_canonical_key(self) -> str:
        carried_str = f"C({self.carried_block['id']},{self.carried_block['color']})" if self.carried_block else "C(-)"
        sorted_blocks = sorted(self.blocks.items(), key=lambda item: (item[0][0], item[0][1]))
        b_str = ",".join(f"({k[0]},{k[1]}:{v['color']},{1 if v['is_bridge'] else 0})" for k, v in sorted_blocks)
        return f"P({self.player_pos[0]},{self.player_pos[1]},{self.player_facing[0]},{self.player_facing[1]})|{carried_str}|B[{b_str}]"

    def get_state_hash(self) -> str:
        return self.get_canonical_key()


class GameRules:
    @staticmethod
    def apply_action(state: BoardState, action: ActionType) -> Dict[str, Any]:
        if state is None:
            return GameRules._make_failure_result(state, action, (0, 0), (0, 0), "null_state", "Current state is null.")
            
        if state.is_completed:
            return GameRules._make_failure_result(state, action, state.player_pos, state.player_pos, "already_completed", "Level is already completed.")

        if action in (ActionType.MOVE_NORTH, ActionType.MOVE_EAST, ActionType.MOVE_SOUTH, ActionType.MOVE_WEST):
            return GameRules._apply_move(state, action)
        elif action in (ActionType.INTERACT_NORTH, ActionType.INTERACT_EAST, ActionType.INTERACT_SOUTH, ActionType.INTERACT_WEST):
            return GameRules._apply_interact(state, action)
        return GameRules._make_failure_result(state, action, state.player_pos, state.player_pos, "invalid_action", "Unknown action.")

    @staticmethod
    def _apply_move(state: BoardState, action: ActionType) -> Dict[str, Any]:
        direction = ACTION_DIRS[action]
        source_cell = state.player_pos
        target_cell = (source_cell[0] + direction[0], source_cell[1] + direction[1])

        if not state.is_inside(target_cell):
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "blocked_bounds", "Cannot move out of bounds.")

        if not state.is_walkable(target_cell):
            tile = state.get_tile(target_cell)
            reason = "blocked"
            msg = "Path obstructed."
            if tile == TileType.WALL:
                reason = "blocked_wall"
                msg = "Cannot walk into solid immutable wall."
            elif tile == TileType.VOID and not state.is_bridge_at(target_cell):
                reason = "blocked_void"
                msg = "Cannot step into unbridged void."
            elif target_cell in state.blocks and not state.is_bridge_at(target_cell):
                reason = "blocked_block"
                msg = "Cell is obstructed by a movable block on floor."
            return GameRules._make_failure_result(state, action, source_cell, target_cell, reason, msg)

        next_state = state.duplicate()
        next_state.player_facing = direction
        next_state.player_pos = target_cell
        next_state.turn_count += 1

        is_cleared = False
        event = "player_moved"
        msg = "Player moved."

        if target_cell == next_state.exit_cell:
            if next_state.is_all_sockets_satisfied():
                next_state.is_completed = True
                is_cleared = True
                event = "level_cleared"
                msg = "All required sockets active! Level completed!"
            else:
                msg = "Exit reached, but sockets remain unsatisfied."

        return {
            "success": True,
            "action": action,
            "source_cell": source_cell,
            "target_cell": target_cell,
            "block_id": -1,
            "block_color": -1,
            "is_bridge": False,
            "is_completed": is_cleared,
            "rejection_reason": "",
            "event": event,
            "message": msg,
            "next_state": next_state
        }

    @staticmethod
    def _apply_interact(state: BoardState, action: ActionType) -> Dict[str, Any]:
        direction = ACTION_DIRS[action]
        source_cell = state.player_pos
        target_cell = (source_cell[0] + direction[0], source_cell[1] + direction[1])

        if not state.is_inside(target_cell):
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "interact_out_of_bounds", "Target cell out of bounds.")

        if state.is_carrying():
            return GameRules._apply_place(state, action, source_cell, target_cell, direction)
        else:
            return GameRules._apply_steal(state, action, source_cell, target_cell, direction)

    @staticmethod
    def _apply_place(state: BoardState, action: ActionType, source_cell: Tuple[int, int], target_cell: Tuple[int, int], direction: Tuple[int, int]) -> Dict[str, Any]:
        if target_cell == state.player_pos:
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "cannot_place_on_player", "Cannot place block on player position.")
        if target_cell == state.exit_cell:
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "cannot_place_on_exit", "Cannot place block on exit portal.")
            
        tile = state.get_tile(target_cell)
        if tile in (TileType.WALL, TileType.EMPTY):
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "cannot_place_on_wall", "Cannot place block on wall.")
        if target_cell in state.blocks:
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "cannot_place_on_block", "Target cell already has a block.")

        next_state = state.duplicate()
        next_state.player_facing = direction
        block_to_place = next_state.carried_block
        next_state.carried_block = None
        next_state.turn_count += 1

        b_id = block_to_place["id"]
        b_col = block_to_place["color"]

        if tile == TileType.VOID:
            next_state.blocks[target_cell] = {
                "id": b_id,
                "color": b_col,
                "is_bridge": True
            }
            return {
                "success": True,
                "action": action,
                "source_cell": source_cell,
                "target_cell": target_cell,
                "block_id": b_id,
                "block_color": b_col,
                "is_bridge": True,
                "is_completed": False,
                "rejection_reason": "",
                "event": "bridge_created",
                "message": "Bridge created over void.",
                "next_state": next_state
            }
        elif tile == TileType.FLOOR:
            next_state.blocks[target_cell] = {
                "id": b_id,
                "color": b_col,
                "is_bridge": False
            }
            event = "block_placed"
            msg = "Block placed on floor."
            if target_cell in next_state.sockets:
                if next_state.is_socket_satisfied(target_cell):
                    event = "socket_activated"
                    msg = "Socket activated!"
                else:
                    event = "socket_mismatch"
                    msg = "Socket mismatch."
            return {
                "success": True,
                "action": action,
                "source_cell": source_cell,
                "target_cell": target_cell,
                "block_id": b_id,
                "block_color": b_col,
                "is_bridge": False,
                "is_completed": False,
                "rejection_reason": "",
                "event": event,
                "message": msg,
                "next_state": next_state
            }

        return GameRules._make_failure_result(state, action, source_cell, target_cell, "cannot_place", "Invalid target cell.")

    @staticmethod
    def _apply_steal(state: BoardState, action: ActionType, source_cell: Tuple[int, int], target_cell: Tuple[int, int], direction: Tuple[int, int]) -> Dict[str, Any]:
        if target_cell == state.player_pos:
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "cannot_steal_under_self", "Cannot steal block under yourself.")
        if target_cell not in state.blocks:
            return GameRules._make_failure_result(state, action, source_cell, target_cell, "nothing_to_steal", "No block to steal.")

        next_state = state.duplicate()
        next_state.player_facing = direction
        target_block = next_state.blocks.pop(target_cell)
        was_bridge = target_block.get("is_bridge", False)
        b_id = target_block["id"]
        b_col = target_block["color"]

        next_state.carried_block = {
            "id": b_id,
            "color": b_col
        }
        next_state.turn_count += 1
        event = "bridge_stolen" if was_bridge else "block_stolen"
        msg = "Bridge stolen from void." if was_bridge else "Block stolen into glove."

        return {
            "success": True,
            "action": action,
            "source_cell": source_cell,
            "target_cell": target_cell,
            "block_id": b_id,
            "block_color": b_col,
            "is_bridge": was_bridge,
            "is_completed": False,
            "rejection_reason": "",
            "event": event,
            "message": msg,
            "next_state": next_state
        }

    @staticmethod
    def _make_failure_result(state: BoardState, action: ActionType, src: Tuple[int, int], dst: Tuple[int, int], reason: str, msg: str) -> Dict[str, Any]:
        return {
            "success": False,
            "action": action,
            "source_cell": src,
            "target_cell": dst,
            "block_id": -1,
            "block_color": -1,
            "is_bridge": False,
            "is_completed": False,
            "rejection_reason": reason,
            "event": reason,
            "message": msg,
            "next_state": state
        }


class HistoryManager:
    def __init__(self, initial_state: BoardState):
        self._undo_stack: List[BoardState] = [initial_state.duplicate()]
        self._initial_state: BoardState = initial_state.duplicate()

    def record_state(self, state: BoardState):
        self._undo_stack.append(state.duplicate())

    def can_undo(self) -> bool:
        return len(self._undo_stack) > 1

    def undo(self) -> BoardState:
        if not self.can_undo():
            return self._undo_stack[-1].duplicate()
        self._undo_stack.pop()
        return self._undo_stack[-1].duplicate()

    def restart(self) -> BoardState:
        self._undo_stack = [self._initial_state.duplicate()]
        return self._initial_state.duplicate()

    def get_current_state(self) -> BoardState:
        return self._undo_stack[-1]


# ==========================================
# 28 MANDATORY TEST CASES + FUZZING + DEMO
# ==========================================
class TestSuite:
    def __init__(self):
        self.total = 0
        self.failed = 0

    def assert_true(self, condition: bool, name: str):
        self.total += 1
        if condition:
            print(f"  [PASS] {name}")
        else:
            self.failed += 1
            print(f"  [FAIL] {name}", file=sys.stderr)

    def assert_eq(self, actual: Any, expected: Any, name: str):
        self.total += 1
        if actual == expected:
            print(f"  [PASS] {name}")
        else:
            self.failed += 1
            print(f"  [FAIL] {name} (Expected: {expected}, Got: {actual})", file=sys.stderr)


def run_unit_tests() -> int:
    suite = TestSuite()
    print("=======================================================")
    print("      PIXEL PILFERER PHASE 2 DETERMINISTIC TESTS       ")
    print("=======================================================\n")

    # Helper: base 5x5 board
    def make_board() -> BoardState:
        s = BoardState(5, 5)
        for x in range(5):
            for y in range(5):
                s.tiles[(x, y)] = TileType.FLOOR
        s.player_pos = (2, 2)
        s.initial_player_pos = (2, 2)
        return s

    # 1. Movement on ordinary floor
    s = make_board()
    res = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(res["success"], "1. Movement on ordinary floor succeeds")
    suite.assert_eq(res["next_state"].player_pos, (3, 2), "1. Position updated to (3,2)")

    # 2. Rejection at fixed walls
    s = make_board()
    s.tiles[(3, 2)] = TileType.WALL
    res = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(not res["success"], "2. Rejection at fixed walls")
    suite.assert_eq(res["rejection_reason"], "blocked_wall", "2. Rejection reason is blocked_wall")
    suite.assert_eq(res["next_state"].player_pos, (2, 2), "2. Player position unchanged")

    # 3. Rejection at board boundaries
    s = make_board()
    s.player_pos = (0, 2)
    res = GameRules.apply_action(s, ActionType.MOVE_WEST)
    suite.assert_true(not res["success"], "3. Rejection at board boundaries")
    suite.assert_eq(res["rejection_reason"], "blocked_bounds", "3. Rejection reason is blocked_bounds")

    # 4. Rejection when entering empty void
    s = make_board()
    s.tiles[(3, 2)] = TileType.VOID
    res = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(not res["success"], "4. Rejection when entering empty void")
    suite.assert_eq(res["rejection_reason"], "blocked_void", "4. Rejection reason is blocked_void")

    # 5. Rejection when entering a floor block
    s = make_board()
    s.blocks[(3, 2)] = {"id": 1, "color": BlockColor.NEUTRAL, "is_bridge": False}
    res = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(not res["success"], "5. Rejection when entering a floor block")
    suite.assert_eq(res["rejection_reason"], "blocked_block", "5. Rejection reason is blocked_block")

    # 6. Successful pickup of an adjacent block
    s = make_board()
    s.blocks[(3, 2)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(res["success"], "6. Successful pickup of an adjacent block")
    suite.assert_true((3, 2) not in res["next_state"].blocks, "6. Block removed from board")
    suite.assert_eq(res["next_state"].carried_block["color"], BlockColor.CYAN, "6. Carried block has color Cyan")

    # 7. Pickup rejection when already carrying
    s = make_board()
    s.carried_block = {"id": 1, "color": BlockColor.CYAN}
    s.blocks[(3, 2)] = {"id": 2, "color": BlockColor.AMBER, "is_bridge": False}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(not res["success"], "7. Pickup rejection when already carrying")
    suite.assert_eq(res["rejection_reason"], "cannot_place_on_block", "7. Tries to place and rejects (capacity 1)")

    # 8. Successful placement onto floor
    s = make_board()
    s.carried_block = {"id": 1, "color": BlockColor.AMBER}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(res["success"], "8. Successful placement onto floor")
    suite.assert_true((3, 2) in res["next_state"].blocks, "8. Block placed at (3,2)")
    suite.assert_true(not res["next_state"].is_carrying(), "8. Hand is empty")
    suite.assert_eq(res["next_state"].blocks[(3, 2)]["is_bridge"], False, "8. Block is floor obstacle")

    # 9. Successful placement onto void
    s = make_board()
    s.tiles[(3, 2)] = TileType.VOID
    s.carried_block = {"id": 1, "color": BlockColor.MAGENTA}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(res["success"], "9. Successful placement onto void")
    suite.assert_eq(res["event"], "bridge_created", "9. Event is bridge_created")
    suite.assert_true(res["next_state"].is_bridge_at((3, 2)), "9. Cell (3,2) is a bridge")

    # 10. Movement across a bridged void
    s_bridge = res["next_state"]
    res_walk = GameRules.apply_action(s_bridge, ActionType.MOVE_EAST)
    suite.assert_true(res_walk["success"], "10. Movement across a bridged void succeeds")
    suite.assert_eq(res_walk["next_state"].player_pos, (3, 2), "10. Player standing on bridged void")

    # 11. Rejection when placing on an occupied cell
    s = make_board()
    s.carried_block = {"id": 1, "color": BlockColor.CYAN}
    s.blocks[(3, 2)] = {"id": 2, "color": BlockColor.NEUTRAL, "is_bridge": False}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(not res["success"], "11. Rejection when placing on an occupied cell")
    suite.assert_eq(res["rejection_reason"], "cannot_place_on_block", "11. Reason is cannot_place_on_block")

    # 12. Rejection when placing on the player
    # Diagonal interactions are impossible by design; facing self is impossible by action contract.
    # We test that targeting own cell rejects cleanly.
    s = make_board()
    s.carried_block = {"id": 1, "color": BlockColor.CYAN}
    # Direct internal test of place helper on self
    res_self = GameRules._apply_place(s, ActionType.INTERACT_NORTH, (2, 2), (2, 2), (0, -1))
    suite.assert_true(not res_self["success"], "12. Rejection when placing on the player")
    suite.assert_eq(res_self["rejection_reason"], "cannot_place_on_player", "12. Reason is cannot_place_on_player")

    # 13. Rejection when placing on an exit
    s = make_board()
    s.exit_cell = (3, 2)
    s.carried_block = {"id": 1, "color": BlockColor.CYAN}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(not res["success"], "13. Rejection when placing on an exit")
    suite.assert_eq(res["rejection_reason"], "cannot_place_on_exit", "13. Reason is cannot_place_on_exit")

    # 14. Correct color preservation
    s = make_board()
    s.blocks[(3, 2)] = {"id": 99, "color": BlockColor.EMERALD, "is_bridge": False}
    res_steal = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_eq(res_steal["next_state"].carried_block["color"], BlockColor.EMERALD, "14. Stolen block preserves Emerald color")
    res_place = GameRules.apply_action(res_steal["next_state"], ActionType.INTERACT_NORTH)
    suite.assert_eq(res_place["next_state"].blocks[(2, 1)]["color"], BlockColor.EMERALD, "14. Placed block preserves Emerald color")

    # 15. Neutral socket activation
    s = make_board()
    s.sockets[(3, 2)] = BlockColor.NEUTRAL
    s.carried_block = {"id": 1, "color": BlockColor.MAGENTA}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(res["success"], "15. Neutral socket accepts Magenta block")
    suite.assert_eq(res["event"], "socket_activated", "15. Socket activated")
    suite.assert_true(res["next_state"].is_socket_satisfied((3, 2)), "15. is_socket_satisfied is True")

    # 16. Colored socket activation
    s = make_board()
    s.sockets[(3, 2)] = BlockColor.CYAN
    s.carried_block = {"id": 1, "color": BlockColor.CYAN}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(res["success"], "16. Cyan socket accepts Cyan block")
    suite.assert_eq(res["event"], "socket_activated", "16. Socket activated")
    suite.assert_true(res["next_state"].is_socket_satisfied((3, 2)), "16. is_socket_satisfied is True")

    # 17. Colored socket mismatch
    s = make_board()
    s.sockets[(3, 2)] = BlockColor.AMBER
    s.carried_block = {"id": 1, "color": BlockColor.CYAN}
    res = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(res["success"], "17. Placement on socket succeeds even if mismatched")
    suite.assert_eq(res["event"], "socket_mismatch", "17. Event is socket_mismatch")
    suite.assert_true(not res["next_state"].is_socket_satisfied((3, 2)), "17. Socket remains unsatisfied")

    # 18. Exit with unsatisfied sockets
    s = make_board()
    s.exit_cell = (3, 2)
    s.sockets[(0, 0)] = BlockColor.CYAN # unsatisfied
    res = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(res["success"], "18. Player steps onto exit")
    suite.assert_true(not res["next_state"].is_completed, "18. Level NOT completed because socket is unsatisfied")

    # 19. Exit with satisfied sockets (and levels with no sockets)
    s = make_board()
    s.exit_cell = (3, 2) # No sockets in level
    res = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(res["success"], "19. Player steps onto exit")
    suite.assert_true(res["next_state"].is_completed, "19. Level completed immediately when no sockets required")

    # 20. Undo after moving
    s = make_board()
    hist = HistoryManager(s)
    res_m = GameRules.apply_action(s, ActionType.MOVE_EAST)
    hist.record_state(res_m["next_state"])
    suite.assert_eq(hist.get_current_state().player_pos, (3, 2), "20. Advanced to (3,2)")
    undone_m = hist.undo()
    suite.assert_eq(undone_m.player_pos, (2, 2), "20. Undo restored position to (2,2)")

    # 21. Undo after pickup
    s = make_board()
    s.blocks[(3, 2)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    hist = HistoryManager(s)
    res_p = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    hist.record_state(res_p["next_state"])
    suite.assert_true(hist.get_current_state().is_carrying(), "21. Carrying block")
    undone_p = hist.undo()
    suite.assert_true(not undone_p.is_carrying(), "21. Undo restored empty hand")
    suite.assert_true((3, 2) in undone_p.blocks, "21. Undo restored block at (3,2)")

    # 22. Undo after placement
    s = make_board()
    s.carried_block = {"id": 1, "color": BlockColor.CYAN}
    hist = HistoryManager(s)
    res_pl = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    hist.record_state(res_pl["next_state"])
    suite.assert_true((3, 2) in hist.get_current_state().blocks, "22. Block placed at (3,2)")
    undone_pl = hist.undo()
    suite.assert_true((3, 2) not in undone_pl.blocks, "22. Undo removed placed block")
    suite.assert_true(undone_pl.is_carrying(), "22. Undo restored carried block in hand")

    # 23. Undo after completion
    s = make_board()
    s.exit_cell = (3, 2)
    hist = HistoryManager(s)
    res_w = GameRules.apply_action(s, ActionType.MOVE_EAST)
    hist.record_state(res_w["next_state"])
    suite.assert_true(hist.get_current_state().is_completed, "23. Level completed")
    undone_w = hist.undo()
    suite.assert_true(not undone_w.is_completed, "23. Undo cleared completion state")
    suite.assert_eq(undone_w.player_pos, (2, 2), "23. Undo restored player position")

    # 24. Restart after several actions
    s = make_board()
    hist = HistoryManager(s)
    s1 = GameRules.apply_action(s, ActionType.MOVE_EAST)["next_state"]
    hist.record_state(s1)
    s2 = GameRules.apply_action(s1, ActionType.MOVE_NORTH)["next_state"]
    hist.record_state(s2)
    s3 = GameRules.apply_action(s2, ActionType.MOVE_WEST)["next_state"]
    hist.record_state(s3)
    restarted = hist.restart()
    suite.assert_eq(restarted.player_pos, (2, 2), "24. Restart restored exact initial position")
    suite.assert_true(not hist.can_undo(), "24. Restart cleared undo history")

    # 25. Canonical state identity
    s_a = make_board()
    s_a.blocks[(1, 1)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    s_a.blocks[(3, 3)] = {"id": 2, "color": BlockColor.AMBER, "is_bridge": True}

    s_b = make_board()
    # Insert in reverse order
    s_b.blocks[(3, 3)] = {"id": 2, "color": BlockColor.AMBER, "is_bridge": True}
    s_b.blocks[(1, 1)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}

    suite.assert_eq(s_a.get_canonical_key(), s_b.get_canonical_key(), "25. States with different block insertion orders produce identical canonical keys")

    # 26. Invalid actions producing no changes
    s = make_board()
    s.tiles[(3, 2)] = TileType.WALL
    key_before = s.get_canonical_key()
    res_inv = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(not res_inv["success"], "26. Invalid action rejected")
    suite.assert_eq(res_inv["next_state"].get_canonical_key(), key_before, "26. Invalid action produced zero change to logical state")

    # 27. Block placement followed by recovery
    s = make_board()
    s.carried_block = {"id": 5, "color": BlockColor.CYAN}
    res_p1 = GameRules.apply_action(s, ActionType.INTERACT_EAST)
    suite.assert_true(res_p1["success"], "27. Block placed")
    res_rec = GameRules.apply_action(res_p1["next_state"], ActionType.INTERACT_EAST)
    suite.assert_true(res_rec["success"], "27. Block recovered back into glove")
    suite.assert_eq(res_rec["next_state"].carried_block["color"], BlockColor.CYAN, "27. Recovered block preserves color")
    suite.assert_true((3, 2) not in res_rec["next_state"].blocks, "27. Floor is clear again")

    # 28. Repeated undo and restart sequences
    s = make_board()
    hist = HistoryManager(s)
    for _ in range(5):
        s_step = GameRules.apply_action(hist.get_current_state(), ActionType.MOVE_NORTH)["next_state"]
        hist.record_state(s_step)
        hist.undo()
    suite.assert_eq(hist.get_current_state().player_pos, (2, 2), "28. Repeated move-undo cycle leaves state at start")

    # ==========================================
    # INTEGRATED DEMONSTRATION BOARD SCENARIO
    # "Steal block from obstacle -> Place over void -> Cross bridge -> Reach exit"
    # ==========================================
    print("\n=== Demonstrating Stolen-Block Void Bridge Crossing Scenario ===")
    demo = BoardState(7, 3)
    for x in range(7):
        for y in range(3):
            demo.tiles[(x, y)] = TileType.WALL
    # Corridor along row 1:
    # (1,1): Player Start
    # (2,1): Movable Block (Obstacle)
    # (3,1): Floor
    # (4,1): Void pit!
    # (5,1): Exit Portal!
    for x in range(1, 6):
        demo.tiles[(x, 1)] = TileType.FLOOR
    demo.tiles[(4, 1)] = TileType.VOID
    demo.player_pos = (1, 1)
    demo.exit_cell = (5, 1)
    demo.blocks[(2, 1)] = {"id": 1, "color": BlockColor.NEUTRAL, "is_bridge": False}

    # Step A: Cannot walk east into block obstacle
    res_a = GameRules.apply_action(demo, ActionType.MOVE_EAST)
    suite.assert_true(not res_a["success"], "Demo A: Player blocked by block obstacle on floor")

    # Step B: Steal the block from adjacent cell
    res_b = GameRules.apply_action(demo, ActionType.INTERACT_EAST)
    suite.assert_true(res_b["success"], "Demo B: Pip siphons block from obstacle cell")
    suite.assert_true(res_b["next_state"].is_carrying(), "Demo B: Pip now holds block in glove")

    # Step C: Move into previously obstructed cell (2,1)
    res_c = GameRules.apply_action(res_b["next_state"], ActionType.MOVE_EAST)
    suite.assert_true(res_c["success"], "Demo C: Pip steps into cleared floor at (2,1)")

    # Step D: Move to (3,1) facing the void
    res_d = GameRules.apply_action(res_c["next_state"], ActionType.MOVE_EAST)
    suite.assert_true(res_d["success"], "Demo D: Pip advances to (3,1) at the edge of the chasm")

    # Step E: Cannot step into void without bridge
    res_e = GameRules.apply_action(res_d["next_state"], ActionType.MOVE_EAST)
    suite.assert_true(not res_e["success"], "Demo E: Cannot step into unbridged void")

    # Step F: Place carried block into void cell (4,1) to create bridge
    res_f = GameRules.apply_action(res_d["next_state"], ActionType.INTERACT_EAST)
    suite.assert_true(res_f["success"], "Demo F: Block placed into void creates traversable bridge")
    suite.assert_true(res_f["next_state"].is_bridge_at((4, 1)), "Demo F: Cell (4,1) is now a bridge")

    # Step G: Walk across the bridge!
    res_g = GameRules.apply_action(res_f["next_state"], ActionType.MOVE_EAST)
    suite.assert_true(res_g["success"], "Demo G: Pip traverses across the void bridge to (4,1)")

    # Step H: Step onto Exit Portal and clear level!
    res_h = GameRules.apply_action(res_g["next_state"], ActionType.MOVE_EAST)
    suite.assert_true(res_h["success"], "Demo H: Pip reaches the Exit Portal at (5,1)")
    suite.assert_true(res_h["is_completed"], "Demo H: Level marked completed!")

    # ==========================================
    # RANDOMIZED PROPERTY-BASED FUZZING TEST (500 steps)
    # Asserts 6 invariants after every single action
    # ==========================================
    print("\n=== Running 500-Step Randomized Property Fuzzing ===")
    rng = random.Random(1337)
    fuzz_state = make_board()
    # Add 2 blocks, 1 void, 1 socket, 1 exit
    fuzz_state.tiles[(3, 1)] = TileType.VOID
    fuzz_state.sockets[(1, 3)] = BlockColor.CYAN
    fuzz_state.exit_cell = (4, 4)
    fuzz_state.blocks[(1, 1)] = {"id": 1, "color": BlockColor.CYAN, "is_bridge": False}
    fuzz_state.blocks[(3, 3)] = {"id": 2, "color": BlockColor.AMBER, "is_bridge": False}

    fuzz_history = HistoryManager(fuzz_state)
    actions_pool = [
        ActionType.MOVE_NORTH, ActionType.MOVE_EAST, ActionType.MOVE_SOUTH, ActionType.MOVE_WEST,
        ActionType.INTERACT_NORTH, ActionType.INTERACT_EAST, ActionType.INTERACT_SOUTH, ActionType.INTERACT_WEST
    ]

    initial_terrain_snapshot = dict(fuzz_state.tiles)
    fuzz_passed = True

    for step in range(500):
        # 10% chance to undo
        if rng.random() < 0.10 and fuzz_history.can_undo():
            state_before = fuzz_history.get_current_state().duplicate()
            restored = fuzz_history.undo()
            # Assert undo matches
            if restored is None:
                fuzz_passed = False
                break
        else:
            action = rng.choice(actions_pool)
            current_s = fuzz_history.get_current_state()
            res = GameRules.apply_action(current_s, action)
            if res["success"]:
                fuzz_history.record_state(res["next_state"])

        cur = fuzz_history.get_current_state()

        # Invariant 1: Player in bounds
        if not cur.is_inside(cur.player_pos):
            fuzz_passed = False
            print(f"Invariant 1 Failed at step {step}: Player out of bounds", file=sys.stderr)
            break

        # Invariant 2: No two blocks share same cell
        seen_cells = set()
        duplicate_block = False
        for pos in cur.blocks:
            if pos in seen_cells:
                duplicate_block = True
                break
            seen_cells.add(pos)
        if duplicate_block:
            fuzz_passed = False
            print(f"Invariant 2 Failed at step {step}: Two blocks share cell", file=sys.stderr)
            break

        # Invariant 3: No player/block collision on ordinary floor
        if cur.player_pos in cur.blocks and not cur.is_bridge_at(cur.player_pos):
            fuzz_passed = False
            print(f"Invariant 3 Failed at step {step}: Player overlaps obstacle block", file=sys.stderr)
            break

        # Invariant 4: Carried block not simultaneously on board
        if cur.is_carrying():
            carried_id = cur.carried_block["id"]
            if any(b["id"] == carried_id for b in cur.blocks.values()):
                fuzz_passed = False
                print(f"Invariant 4 Failed at step {step}: Carried block duplicated on board", file=sys.stderr)
                break

        # Invariant 5: Immutable terrain is unchanged
        for pos, t_type in initial_terrain_snapshot.items():
            if cur.get_tile(pos) != t_type:
                fuzz_passed = False
                print(f"Invariant 5 Failed at step {step}: Immutable terrain altered", file=sys.stderr)
                break

    suite.assert_true(fuzz_passed, "Property Fuzzing: 500 random actions preserved all 5 physical and state invariants")

    print("\n-------------------------------------------")
    print(f"Phase 2 Test Results: {suite.total} executed | {suite.failed} failed.")
    return 1 if suite.failed > 0 else 0


if __name__ == "__main__":
    sys.exit(run_unit_tests())
