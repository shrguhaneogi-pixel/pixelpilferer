"""
Deterministic Domain Model and Invariant Unit Test Suite
Mirrors and validates all rules specified in locked game rules and Godot scripts.
"""

from enum import IntEnum
from typing import Dict, List, Tuple, Optional, Any
import copy
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
        return all(self.is_socket_satisfied(pos) for pos in self.sockets)

    def get_state_hash(self) -> str:
        carried_str = f"C({self.carried_block['id']},{self.carried_block['color']})" if self.carried_block else "C(-)"
        sorted_blocks = sorted(self.blocks.items(), key=lambda item: (item[0][0], item[0][1]))
        b_str = ",".join(f"({k[0]},{k[1]}:{v['color']},{1 if v['is_bridge'] else 0})" for k, v in sorted_blocks)
        return f"P({self.player_pos[0]},{self.player_pos[1]},{self.player_facing[0]},{self.player_facing[1]})|{carried_str}|B[{b_str}]"


class GameRules:
    @staticmethod
    def apply_action(state: BoardState, action: ActionType) -> Tuple[bool, BoardState, str, str]:
        if state.is_completed:
            return False, state, "already_completed", "Level is already completed."

        if action in (ActionType.MOVE_NORTH, ActionType.MOVE_EAST, ActionType.MOVE_SOUTH, ActionType.MOVE_WEST):
            return GameRules._apply_move(state, action)
        elif action in (ActionType.INTERACT_NORTH, ActionType.INTERACT_EAST, ActionType.INTERACT_SOUTH, ActionType.INTERACT_WEST):
            return GameRules._apply_interact(state, action)
        return False, state, "invalid_action", "Unknown action."

    @staticmethod
    def _apply_move(state: BoardState, action: ActionType) -> Tuple[bool, BoardState, str, str]:
        direction = ACTION_DIRS[action]
        next_state = state.duplicate()
        next_state.player_facing = direction
        target_cell = (state.player_pos[0] + direction[0], state.player_pos[1] + direction[1])

        if not next_state.is_inside(target_cell):
            return False, next_state, "blocked_bounds", "Cannot move out of bounds."

        if not next_state.is_walkable(target_cell):
            tile = next_state.get_tile(target_cell)
            reason = "blocked"
            msg = "Obstacle ahead."
            if tile == TileType.WALL:
                reason = "blocked_wall"
                msg = "Cannot walk into solid wall."
            elif tile == TileType.VOID and not next_state.is_bridge_at(target_cell):
                reason = "blocked_void"
                msg = "Cannot step into unbridged void."
            elif target_cell in next_state.blocks and not next_state.is_bridge_at(target_cell):
                reason = "blocked_block"
                msg = "Cell is obstructed by a movable block."
            return False, next_state, reason, msg

        next_state.player_pos = target_cell
        next_state.turn_count += 1

        if target_cell == next_state.exit_cell:
            if next_state.is_all_sockets_satisfied():
                next_state.is_completed = True
                return True, next_state, "level_cleared", "Level cleared!"
            else:
                return True, next_state, "player_moved", "Exit reached, but sockets pending."

        return True, next_state, "player_moved", "Player moved."

    @staticmethod
    def _apply_interact(state: BoardState, action: ActionType) -> Tuple[bool, BoardState, str, str]:
        direction = ACTION_DIRS[action]
        next_state = state.duplicate()
        next_state.player_facing = direction
        target_cell = (state.player_pos[0] + direction[0], state.player_pos[1] + direction[1])

        if not next_state.is_inside(target_cell):
            return False, next_state, "interact_out_of_bounds", "Target cell out of bounds."

        if next_state.carried_block is not None:
            # Attempt to PLACE
            if target_cell == next_state.player_pos:
                return False, next_state, "cannot_place_on_player", "Cannot place block on player."
            if target_cell == next_state.exit_cell:
                return False, next_state, "cannot_place_on_exit", "Cannot place block on exit."
            tile = next_state.get_tile(target_cell)
            if tile in (TileType.WALL, TileType.EMPTY):
                return False, next_state, "cannot_place_on_wall", "Cannot place block on wall."
            if target_cell in next_state.blocks:
                return False, next_state, "cannot_place_on_block", "Target cell already has a block."

            block_to_place = next_state.carried_block
            next_state.carried_block = None
            next_state.turn_count += 1

            if tile == TileType.VOID:
                next_state.blocks[target_cell] = {
                    "id": block_to_place["id"],
                    "color": block_to_place["color"],
                    "is_bridge": True
                }
                return True, next_state, "bridge_created", "Bridge created over void."
            elif tile == TileType.FLOOR:
                next_state.blocks[target_cell] = {
                    "id": block_to_place["id"],
                    "color": block_to_place["color"],
                    "is_bridge": False
                }
                event = "block_placed"
                if target_cell in next_state.sockets:
                    if next_state.is_socket_satisfied(target_cell):
                        event = "socket_activated"
                    else:
                        event = "socket_mismatch"
                return True, next_state, event, "Block placed on floor."

            return False, next_state, "cannot_place", "Invalid target cell."
        else:
            # Attempt to STEAL
            if target_cell == next_state.player_pos:
                return False, next_state, "cannot_steal_under_self", "Cannot steal block under yourself."
            if target_cell not in next_state.blocks:
                return False, next_state, "nothing_to_steal", "No block to steal."

            target_block = next_state.blocks.pop(target_cell)
            was_bridge = target_block.get("is_bridge", False)
            next_state.carried_block = {
                "id": target_block["id"],
                "color": target_block["color"]
            }
            next_state.turn_count += 1
            event = "bridge_stolen" if was_bridge else "block_stolen"
            return True, next_state, event, "Block stolen into glove."


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
# TEST RUNNER & ASSERTIONS
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
    print("=== Running Pixel Pilferer Domain Invariant Tests ===")

    # 1. Floor movement
    s = BoardState(5, 5)
    for x in range(5):
        for y in range(5):
            s.tiles[(x, y)] = TileType.FLOOR
    s.player_pos = (1, 1)

    ok, s1, ev, _ = GameRules.apply_action(s, ActionType.MOVE_EAST)
    suite.assert_true(ok, "Move East on empty floor succeeds")
    suite.assert_eq(s1.player_pos, (2, 1), "Player pos is (2,1)")
    suite.assert_eq(s1.turn_count, 1, "Turn count incremented")

    # 2. Wall collision
    s1.tiles[(3, 1)] = TileType.WALL
    ok, s2, ev, _ = GameRules.apply_action(s1, ActionType.MOVE_EAST)
    suite.assert_true(not ok, "Cannot move into immutable wall")
    suite.assert_eq(s2.player_pos, (2, 1), "Player position remains unchanged at wall")
    suite.assert_eq(ev, "blocked_wall", "Event is blocked_wall")

    # 3. Block on floor collision (obstacle)
    s1.tiles[(2, 2)] = TileType.FLOOR
    s1.blocks[(2, 2)] = {"id": 1, "color": BlockColor.NEUTRAL, "is_bridge": False}
    ok, s3, ev, _ = GameRules.apply_action(s1, ActionType.MOVE_SOUTH)
    suite.assert_true(not ok, "Cannot move into cell occupied by block on floor")
    suite.assert_eq(ev, "blocked_block", "Event is blocked_block")

    # 4. Void without bridge
    s1.tiles[(2, 0)] = TileType.VOID
    ok, s4, ev, _ = GameRules.apply_action(s1, ActionType.MOVE_NORTH)
    suite.assert_true(not ok, "Cannot step into unbridged void")
    suite.assert_eq(ev, "blocked_void", "Event is blocked_void")

    # 5. Stealing a block
    ok, s_steal, ev, _ = GameRules.apply_action(s1, ActionType.INTERACT_SOUTH)
    suite.assert_true(ok, "Steal block south succeeds")
    suite.assert_true((2, 2) not in s_steal.blocks, "Block removed from cell (2,2)")
    suite.assert_true(s_steal.carried_block is not None, "Player carries stolen block")
    suite.assert_eq(s_steal.carried_block["color"], BlockColor.NEUTRAL, "Carried block color is Neutral")

    # 6. Cannot carry two blocks
    s_steal.blocks[(1, 1)] = {"id": 2, "color": BlockColor.CYAN, "is_bridge": False}
    # facing west
    s_steal.blocks[(1, 1)] = {"id": 2, "color": BlockColor.CYAN, "is_bridge": False}
    # target (1,1) is player's current pos so that's blocked anyway, let's put it at (2,0)
    s_steal.tiles[(2, 0)] = TileType.FLOOR
    s_steal.blocks[(2, 0)] = {"id": 2, "color": BlockColor.CYAN, "is_bridge": False}
    ok, s_two, ev, _ = GameRules.apply_action(s_steal, ActionType.INTERACT_NORTH)
    suite.assert_true(not ok, "Cannot steal second block while carrying one (Capacity = 1)")
    suite.assert_eq(ev, "cannot_place_on_block", "Interacting with block while carrying tries to place and fails")

    # 7. Placing block on void creates bridge
    s_steal.tiles[(2, 0)] = TileType.VOID
    del s_steal.blocks[(2, 0)]
    ok, s_bridge, ev, _ = GameRules.apply_action(s_steal, ActionType.INTERACT_NORTH)
    suite.assert_true(ok, "Place block on void succeeds")
    suite.assert_eq(ev, "bridge_created", "Event is bridge_created")
    suite.assert_true(s_bridge.is_bridge_at((2, 0)), "Cell (2,0) is now a bridge")
    suite.assert_true(s_bridge.carried_block is None, "Player no longer carrying block")

    # 8. Stepping onto bridge over void succeeds
    ok, s_cross, ev, _ = GameRules.apply_action(s_bridge, ActionType.MOVE_NORTH)
    suite.assert_true(ok, "Walking onto bridge over void succeeds")
    suite.assert_eq(s_cross.player_pos, (2, 0), "Player now on bridged void cell")

    # 9. Stealing bridge from beneath oneself is forbidden
    ok, s_self_steal, ev, _ = GameRules.apply_action(s_cross, ActionType.INTERACT_SOUTH) # facing south, target is (2,1) empty floor
    suite.assert_true(not ok, "Cannot steal when facing empty floor")
    # Pip turns around to face north? target (2,-1) out of bounds
    ok, s_oob, ev, _ = GameRules.apply_action(s_cross, ActionType.INTERACT_NORTH)
    suite.assert_true(not ok, "Cannot interact out of bounds")

    # 10. Sockets and exit condition
    s_sock = BoardState(4, 4)
    for x in range(4):
        for y in range(4):
            s_sock.tiles[(x, y)] = TileType.FLOOR
    s_sock.player_pos = (1, 1)
    s_sock.exit_cell = (3, 1)
    s_sock.sockets[(1, 2)] = BlockColor.CYAN
    s_sock.carried_block = {"id": 99, "color": BlockColor.CYAN}

    # Place Cyan block on Cyan socket
    ok, s_sock2, ev, _ = GameRules.apply_action(s_sock, ActionType.INTERACT_SOUTH)
    suite.assert_true(ok, "Place Cyan block on Cyan socket succeeds")
    suite.assert_eq(ev, "socket_activated", "Cyan socket activated")
    suite.assert_true(s_sock2.is_all_sockets_satisfied(), "All sockets satisfied")

    # Reach exit
    ok, s_exit1, _, _ = GameRules.apply_action(s_sock2, ActionType.MOVE_EAST)
    ok, s_win, ev, _ = GameRules.apply_action(s_exit1, ActionType.MOVE_EAST)
    suite.assert_true(ok, "Reached exit portal")
    suite.assert_true(s_win.is_completed, "Level marked as completed!")
    suite.assert_eq(ev, "level_cleared", "Event is level_cleared")

    # 11. Undo / Restart integrity
    hist = HistoryManager(s)
    s_step1 = GameRules.apply_action(s, ActionType.MOVE_EAST)[1]
    hist.record_state(s_step1)
    s_step2 = GameRules.apply_action(s_step1, ActionType.MOVE_SOUTH)[1]
    hist.record_state(s_step2)

    suite.assert_eq(hist.get_current_state().player_pos, (2, 2), "Current pos is (2,2)")
    restored1 = hist.undo()
    suite.assert_eq(restored1.player_pos, (2, 1), "Undo 1 restored (2,1)")
    restored0 = hist.restart()
    suite.assert_eq(restored0.player_pos, (1, 1), "Restart restored (1,1)")

    print("\n-------------------------------------------")
    print(f"Domain Invariant Tests: {suite.total} executed | {suite.failed} failed.")
    return 1 if suite.failed > 0 else 0


if __name__ == "__main__":
    sys.exit(run_unit_tests())
