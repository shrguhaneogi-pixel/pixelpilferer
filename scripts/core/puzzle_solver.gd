class_name PuzzleSolver extends RefCounted

const ActionType = Constants.ActionType
const BlockColor = Constants.BlockColor

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

static func heuristic(state: BoardState) -> int:
	var unsatisfied: int = 0
	for pos: Vector2i in state.sockets:
		if not state.is_socket_satisfied(pos):
			unsatisfied += 1
			
	if unsatisfied == 0:
		return abs(state.player_pos.x - state.exit_cell.x) + abs(state.player_pos.y - state.exit_cell.y)
		
	var cost: int = unsatisfied * 20
	if state.is_carrying():
		var carried_col: int = state.carried_block["color"]
		for pos: Vector2i in state.sockets:
			var req_col: int = state.sockets[pos]
			if (req_col == carried_col or req_col == BlockColor.NEUTRAL) and not state.is_socket_satisfied(pos):
				cost += abs(state.player_pos.x - pos.x) + abs(state.player_pos.y - pos.y)
				break
	else:
		cost += 10
		
	return cost

static func solve(initial_state: BoardState, max_visited: int = 50000) -> Dictionary:
	var start_hash: String = initial_state.get_state_hash()
	
	if initial_state.is_completed:
		return {
			"solved": true,
			"steps": 0,
			"actions": [],
			"visited_count": 1,
			"message": "Level already completed at start."
		}

	# Min-heap / priority queue simulated with bucket array or sorted insertion
	# Entry: [f_score: int, g_score: int, state: BoardState, actions: Array[int]]
	var open_set: Array = []
	var start_h: int = heuristic(initial_state)
	open_set.append([start_h, 0, initial_state, []])
	
	var visited: Dictionary = {}
	visited[start_hash] = 0
	
	while not open_set.is_empty():
		if visited.size() > max_visited:
			return {
				"solved": false,
				"steps": -1,
				"actions": [],
				"visited_count": visited.size(),
				"message": "Exceeded max visited states limit."
			}
			
		# Extract lowest f_score
		var current_entry: Array = open_set.pop_front()
		var g_score: int = current_entry[1]
		var state: BoardState = current_entry[2]
		var actions: Array = current_entry[3]
		
		if state.is_completed:
			return {
				"solved": true,
				"steps": actions.size(),
				"actions": actions,
				"visited_count": visited.size(),
				"message": "Optimal solution found."
			}
			
		for act: int in CANDIDATE_ACTIONS:
			var res: Dictionary = GameRules.apply_action(state, act)
			if not res["success"]:
				continue
				
			var next_state: BoardState = res["next_state"]
			var next_hash: String = next_state.get_state_hash()
			var next_g: int = g_score + 1
			
			if visited.has(next_hash) and visited[next_hash] <= next_g:
				continue
				
			visited[next_hash] = next_g
			var next_actions: Array = actions.duplicate()
			next_actions.append(act)
			
			var next_f: int = next_g + heuristic(next_state)
			var new_entry: Array = [next_f, next_g, next_state, next_actions]
			
			# Insert in sorted order by f_score (binary search or linear insert)
			_insert_sorted(open_set, new_entry)
			
	return {
		"solved": false,
		"steps": -1,
		"actions": [],
		"visited_count": visited.size(),
		"message": "Unsolvable within search space."
	}

static func _insert_sorted(arr: Array, entry: Array) -> void:
	var f: int = entry[0]
	var low: int = 0
	var high: int = arr.size()
	while low < high:
		var mid: int = (low + high) / 2
		if arr[mid][0] < f:
			low = mid + 1
		else:
			high = mid
	arr.insert(low, entry)
