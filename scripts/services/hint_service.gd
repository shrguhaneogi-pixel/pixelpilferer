class_name HintService extends RefCounted

## Intelligent hint service for Pixel Pilferer.
## Analyzes the player's CURRENT BoardState and generates optimal next-step guidance
## with contextual, natural-language explanations.

const ActionType = Constants.ActionType
const BlockColor = Constants.BlockColor
const TileType = Constants.TileType

## Evaluates the current state and returns next optimal action and guidance text.
## Returns:
## {
##   "has_hint": bool,
##   "status": String,          # "SOLVED", "UNSOLVABLE", "LIMIT_REACHED", "COMPLETED"
##   "next_action": int,        # ActionType or -1
##   "direction": Vector2i,     # Direction vector
##   "hint_text": String,       # Player-facing explanation
##   "action_name": String,     # Canonical action name
##   "remaining_steps": int     # Steps to victory
## }
static func generate_hint(current_state: BoardState, max_visited: int = 20000, timeout_sec: float = 3.0) -> Dictionary:
	if current_state == null:
		return {
			"has_hint": false,
			"status": "INVALID",
			"next_action": -1,
			"direction": Vector2i.ZERO,
			"hint_text": "Board state is invalid.",
			"action_name": "NONE",
			"remaining_steps": -1
		}
		
	if current_state.is_completed:
		return {
			"has_hint": true,
			"status": "COMPLETED",
			"next_action": -1,
			"direction": Vector2i.ZERO,
			"hint_text": "The exit is already open and you have completed the puzzle!",
			"action_name": "NONE",
			"remaining_steps": 0
		}
		
	var solve_res: Dictionary = PuzzleSolver.solve(current_state, max_visited, timeout_sec)
	var status_str: String = solve_res.get("status_string", "UNSOLVABLE")
	
	if status_str == "SOLVED":
		var actions: Array = solve_res.get("actions", [])
		if actions.is_empty():
			return {
				"has_hint": true,
				"status": "COMPLETED",
				"next_action": -1,
				"direction": Vector2i.ZERO,
				"hint_text": "You are standing on the unlocked exit portal!",
				"action_name": "NONE",
				"remaining_steps": 0
			}
			
		var next_act: int = int(actions[0])
		var dir: Vector2i = Constants.action_to_direction(next_act)
		var dir_name: String = _get_direction_name(dir)
		var act_name: String = Constants.action_name(next_act)
		var remaining: int = actions.size()
		var text: String = _describe_action(current_state, next_act, dir, dir_name)
		
		return {
			"has_hint": true,
			"status": "SOLVED",
			"next_action": next_act,
			"direction": dir,
			"hint_text": text,
			"action_name": act_name,
			"remaining_steps": remaining
		}
		
	elif status_str == "LIMIT_REACHED":
		return {
			"has_hint": false,
			"status": "LIMIT_REACHED",
			"next_action": -1,
			"direction": Vector2i.ZERO,
			"hint_text": "Search budget exceeded. Try undoing a few steps (Z) or restart (R).",
			"action_name": "NONE",
			"remaining_steps": -1
		}
	else:
		# UNSOLVABLE from this state
		return {
			"has_hint": false,
			"status": "UNSOLVABLE",
			"next_action": -1,
			"direction": Vector2i.ZERO,
			"hint_text": "No path to victory from this position. Press Z to Undo or R to Restart.",
			"action_name": "NONE",
			"remaining_steps": -1
		}

static func _describe_action(state: BoardState, act: int, dir: Vector2i, dir_name: String) -> String:
	var target_cell: Vector2i = state.player_pos + dir
	
	if Constants.is_move_action(act):
		if target_cell == state.exit_cell and state.is_all_sockets_satisfied():
			return "Step %s into the open exit portal to complete the level." % dir_name
		elif state.is_bridge_at(target_cell):
			return "Step %s across the void bridge." % dir_name
		else:
			return "Step %s toward your next objective." % dir_name
			
	elif Constants.is_interact_action(act):
		if state.is_carrying():
			# Placing carried fragment
			var carried_col: int = state.carried_block.get("color", BlockColor.NEUTRAL)
			var col_name: String = Constants.color_name(carried_col)
			var tile: int = state.get_tile(target_cell)
			
			if tile == TileType.VOID:
				return "Place your carried %s fragment %s to bridge the chasm." % [col_name, dir_name]
			elif state.sockets.has(target_cell):
				var req_col: int = state.sockets[target_cell]
				var req_name: String = Constants.color_name(req_col)
				return "Place your carried %s fragment %s into the %s socket." % [col_name, dir_name, req_name]
			else:
				return "Place your carried %s fragment %s to clear your path." % [col_name, dir_name]
		else:
			# Stealing / siphoning fragment
			var b: Dictionary = state.get_block_at(target_cell)
			var col_name: String = Constants.color_name(b.get("color", BlockColor.NEUTRAL))
			if state.is_bridge_at(target_cell):
				return "Siphon the %s bridge fragment %s back into your Pixel Glove." % [col_name, dir_name]
			elif state.sockets.has(target_cell):
				return "Siphon the %s fragment %s from the socket into your Pixel Glove." % [col_name, dir_name]
			else:
				return "Siphon the %s fragment %s into your Pixel Glove." % [col_name, dir_name]
				
	return "Execute action %s." % Constants.action_name(act)

static func _get_direction_name(dir: Vector2i) -> String:
	if dir == Constants.DIR_NORTH: return "North"
	if dir == Constants.DIR_EAST: return "East"
	if dir == Constants.DIR_SOUTH: return "South"
	if dir == Constants.DIR_WEST: return "West"
	return "forward"
