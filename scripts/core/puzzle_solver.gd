class_name PuzzleSolver extends RefCounted

## Authoritative puzzle solver for Pixel Pilferer.
## Uses pure breadth-first search (BFS) over the finite puzzle state space.
## Uses ONLY the authoritative GameRules.apply_action state transition function.
## Guarantees optimal (minimal action count) solution paths.

const ActionType = Constants.ActionType
const BlockColor = Constants.BlockColor

enum SolverStatus {
	SOLVED = 0,
	UNSOLVABLE = 1,
	LIMIT_REACHED = 2,
	INVALID_LEVEL = 3
}

const CANDIDATE_ACTIONS: Array[int] = [
	ActionType.MOVE_NORTH,
	ActionType.MOVE_EAST,
	ActionType.MOVE_SOUTH,
	ActionType.MOVE_WEST,
	ActionType.INTERACT_NORTH,
	ActionType.INTERACT_EAST,
	ActionType.INTERACT_SOUTH,
	ActionType.INTERACT_WEST
]

## Solves the puzzle starting from initial_state using pure BFS.
## Returns a structured result with SolverStatus, action sequence, visited count, and timing.
static func solve(initial_state: BoardState, max_visited: int = 50000, timeout_sec: float = 5.0) -> Dictionary:
	var start_msec: int = Time.get_ticks_msec()
	
	if initial_state == null:
		return _make_result(SolverStatus.INVALID_LEVEL, false, -1, [], 0, 0.0, "Initial state is null.")
		
	var start_key: String = initial_state.get_canonical_key()
	
	if initial_state.is_completed:
		var elapsed: float = (Time.get_ticks_msec() - start_msec) / 1000.0
		return _make_result(SolverStatus.SOLVED, true, 0, [], 1, elapsed, "Level already completed at start.")
		
	# BFS queue: stores BoardState instances
	var queue: Array = [initial_state]
	var q_head: int = 0
	
	# Visited state tracking: canonical_key -> true
	var visited: Dictionary = {}
	visited[start_key] = true
	
	# Predecessor map for path reconstruction: child_key -> [parent_key, action]
	var parent_map: Dictionary = {}
	
	var timeout_msec: int = int(timeout_sec * 1000.0)
	var win_key: String = ""
	var reached_goal: bool = false
	
	while q_head < queue.size():
		# Limit checks
		if visited.size() > max_visited or (max_visited == 0 and visited.size() > 50000):
			var elapsed: float = (Time.get_ticks_msec() - start_msec) / 1000.0
			return _make_result(SolverStatus.LIMIT_REACHED, false, -1, [], visited.size(), elapsed, "Search budget exceeded (%d visited states)." % visited.size())
			
		if timeout_sec > 0.0 and (Time.get_ticks_msec() - start_msec) >= timeout_msec:
			var elapsed: float = (Time.get_ticks_msec() - start_msec) / 1000.0
			return _make_result(SolverStatus.LIMIT_REACHED, false, -1, [], visited.size(), elapsed, "Search timed out after %.2f seconds (%d visited states)." % [elapsed, visited.size()])
			
		var cur_state: BoardState = queue[q_head]
		var cur_key: String = cur_state.get_canonical_key()
		q_head += 1
		
		# Compact queue array periodically to reclaim memory
		if q_head > 10000:
			queue = queue.slice(q_head)
			q_head = 0
			
		for act: int in CANDIDATE_ACTIONS:
			var res: Dictionary = GameRules.apply_action(cur_state, act)
			if not res["success"]:
				continue
				
			var next_state: BoardState = res["next_state"]
			var next_key: String = next_state.get_canonical_key()
			
			if visited.has(next_key):
				continue
				
			visited[next_key] = true
			parent_map[next_key] = [cur_key, act]
			
			if next_state.is_completed:
				win_key = next_key
				reached_goal = true
				break
				
			queue.append(next_state)
			
		if reached_goal:
			break
			
	var elapsed_sec: float = (Time.get_ticks_msec() - start_msec) / 1000.0
	
	if reached_goal:
		# Reconstruct action path from predecessor map
		var actions: Array[int] = []
		var backtrack_key: String = win_key
		while parent_map.has(backtrack_key):
			var record: Array = parent_map[backtrack_key]
			actions.append(int(record[1]))
			backtrack_key = str(record[0])
		actions.reverse()
		
		return _make_result(SolverStatus.SOLVED, true, actions.size(), actions, visited.size(), elapsed_sec, "Optimal solution found in %d steps." % actions.size())
	else:
		return _make_result(SolverStatus.UNSOLVABLE, false, -1, [], visited.size(), elapsed_sec, "Proven unsolvable within finite state space (%d visited states)." % visited.size())

## Replays an action sequence against initial_state using authoritative GameRules.
## Confirms every step succeeds and ends in completed state.
static func verify_solution(initial_state: BoardState, actions: Array) -> Dictionary:
	if initial_state == null:
		return {
			"valid": false,
			"failed_step": 0,
			"failed_action": -1,
			"rejection_reason": &"null_initial_state",
			"message": "Initial state is null.",
			"final_state": null
		}
		
	var cur: BoardState = initial_state.duplicate_state()
	
	if actions.is_empty():
		if cur.is_completed:
			return {
				"valid": true,
				"failed_step": -1,
				"failed_action": -1,
				"rejection_reason": &"",
				"message": "Level was already completed.",
				"final_state": cur
			}
		else:
			return {
				"valid": false,
				"failed_step": 0,
				"failed_action": -1,
				"rejection_reason": &"empty_actions_uncompleted",
				"message": "Action sequence is empty but level is not completed.",
				"final_state": cur
			}
			
	for step_idx: int in actions.size():
		var act: int = int(actions[step_idx])
		var res: Dictionary = GameRules.apply_action(cur, act)
		if not res["success"]:
			return {
				"valid": false,
				"failed_step": step_idx,
				"failed_action": act,
				"rejection_reason": res.get("rejection_reason", &"unknown"),
				"message": "Action %d failed at step %d: %s" % [act, step_idx, res.get("message", "")],
				"final_state": cur
			}
		cur = res["next_state"]
		
	if not cur.is_completed:
		return {
			"valid": false,
			"failed_step": actions.size(),
			"failed_action": -1,
			"rejection_reason": &"not_completed_at_end",
			"message": "All %d actions succeeded but level exit condition was not satisfied." % actions.size(),
			"final_state": cur
		}
		
	return {
		"valid": true,
		"failed_step": -1,
		"failed_action": -1,
		"rejection_reason": &"",
		"message": "Solution verification passed: all %d steps executed cleanly to completion." % actions.size(),
		"final_state": cur
	}

static func _make_result(status: SolverStatus, solved: bool, steps: int, actions: Array[int], visited_count: int, elapsed_sec: float, message: String) -> Dictionary:
	var status_str: String = ""
	match status:
		SolverStatus.SOLVED: status_str = "SOLVED"
		SolverStatus.UNSOLVABLE: status_str = "UNSOLVABLE"
		SolverStatus.LIMIT_REACHED: status_str = "LIMIT_REACHED"
		SolverStatus.INVALID_LEVEL: status_str = "INVALID_LEVEL"
		
	return {
		"status": status,
		"status_string": status_str,
		"solved": solved,
		"steps": steps,
		"actions": actions,
		"visited_count": visited_count,
		"time_sec": elapsed_sec,
		"message": message
	}
