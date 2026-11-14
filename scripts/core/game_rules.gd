class_name GameRules extends RefCounted

const ActionType = Constants.ActionType
const TileType = Constants.TileType
const BlockColor = Constants.BlockColor

## Transition result structure:
## {
##   "success": bool,
##   "next_state": BoardState,
##   "event": StringName,
##   "message": String
## }

static func apply_action(current_state: BoardState, action: int) -> Dictionary:
	if current_state.is_completed:
		return {
			"success": false,
			"next_state": current_state,
			"event": &"already_completed",
			"message": "Level is already completed."
		}

	if Constants.is_move_action(action):
		return _apply_move(current_state, action)
	elif Constants.is_interact_action(action):
		return _apply_interact(current_state, action)
	else:
		return {
			"success": false,
			"next_state": current_state,
			"event": &"invalid_action",
			"message": "Unknown action."
		}

static func _apply_move(current_state: BoardState, action: int) -> Dictionary:
	var dir: Vector2i = Constants.action_to_direction(action)
	var next: BoardState = current_state.duplicate_state()
	
	# Always turn to face move direction
	next.player_facing = dir
	
	var target_cell: Vector2i = current_state.player_pos + dir
	
	# Out of bounds check
	if not next.is_inside_grid(target_cell):
		return {
			"success": false,
			"next_state": next, # facing updated even if blocked
			"event": &"blocked_bounds",
			"message": "Cannot move out of bounds."
		}
		
	# Terrain and obstacle check
	if not next.is_walkable(target_cell):
		var tile: int = next.get_tile(target_cell)
		var reason: StringName = &"blocked"
		var msg: String = "Path obstructed."
		
		if tile == TileType.WALL:
			reason = &"blocked_wall"
			msg = "Cannot walk into solid wall."
		elif tile == TileType.VOID and not next.is_bridge_at(target_cell):
			reason = &"blocked_void"
			msg = "Cannot step into unbridged void."
		elif next.has_block_at(target_cell) and not next.is_bridge_at(target_cell):
			reason = &"blocked_block"
			msg = "Cell is obstructed by a movable block."
			
		return {
			"success": false,
			"next_state": next,
			"event": reason,
			"message": msg
		}
		
	# Move is valid!
	next.player_pos = target_cell
	next.turn_count += 1
	
	# Check exit condition
	if target_cell == next.exit_cell:
		if next.is_all_sockets_satisfied():
			next.is_completed = true
			return {
				"success": true,
				"next_state": next,
				"event": &"level_cleared",
				"message": "All sockets active! Level completed!"
			}
		else:
			# Player can step onto exit, but it doesn't trigger win yet
			return {
				"success": true,
				"next_state": next,
				"event": &"player_moved",
				"message": "Exit reached, but sockets remain unsatisfied."
			}
			
	return {
		"success": true,
		"next_state": next,
		"event": &"player_moved",
		"message": "Player moved."
	}

static func _apply_interact(current_state: BoardState, action: int) -> Dictionary:
	var dir: Vector2i = Constants.action_to_direction(action)
	var next: BoardState = current_state.duplicate_state()
	
	# Always turn to face interact direction
	next.player_facing = dir
	
	var target_cell: Vector2i = current_state.player_pos + dir
	
	# Target bounds check
	if not next.is_inside_grid(target_cell):
		return {
			"success": false,
			"next_state": next,
			"event": &"interact_out_of_bounds",
			"message": "Target cell is out of bounds."
		}

	# CASE 1: Player is currently carrying a block -> Attempt to PLACE block
	if next.is_carrying():
		return _apply_place_block(next, target_cell)
		
	# CASE 2: Player is NOT carrying a block -> Attempt to STEAL block
	else:
		return _apply_steal_block(next, target_cell)

static func _apply_place_block(next: BoardState, target_cell: Vector2i) -> Dictionary:
	# Rule: Cannot place block on player's current cell
	if target_cell == next.player_pos:
		return {
			"success": false,
			"next_state": next,
			"event": &"cannot_place_on_player",
			"message": "Cannot place block on player's position."
		}
		
	# Rule: Cannot place block on exit cell
	if target_cell == next.exit_cell:
		return {
			"success": false,
			"next_state": next,
			"event": &"cannot_place_on_exit",
			"message": "Cannot place block on the exit portal."
		}
		
	# Rule: Cannot place block on immutable wall
	var tile: int = next.get_tile(target_cell)
	if tile == TileType.WALL or tile == TileType.EMPTY:
		return {
			"success": false,
			"next_state": next,
			"event": &"cannot_place_on_wall",
			"message": "Cannot place block on immutable wall."
		}
		
	# Rule: Cannot place block on another existing block
	if next.has_block_at(target_cell):
		return {
			"success": false,
			"next_state": next,
			"event": &"cannot_place_on_block",
			"message": "Target cell already contains a block."
		}
		
	var block_to_place: Dictionary = next.carried_block
	next.carried_block = {}
	
	# Placing on VOID -> creates a bridge!
	if tile == TileType.VOID:
		next.blocks[target_cell] = {
			"id": block_to_place["id"],
			"color": block_to_place["color"],
			"is_bridge": true
		}
		next.turn_count += 1
		return {
			"success": true,
			"next_state": next,
			"event": &"bridge_created",
			"message": "Placed block as a bridge across void."
		}
		
	# Placing on FLOOR -> creates an obstacle / may satisfy socket!
	elif tile == TileType.FLOOR:
		next.blocks[target_cell] = {
			"id": block_to_place["id"],
			"color": block_to_place["color"],
			"is_bridge": false
		}
		next.turn_count += 1
		
		var event_name: StringName = &"block_placed"
		var msg: String = "Placed block on floor."
		
		# Check if placed on socket
		if next.sockets.has(target_cell):
			if next.is_socket_satisfied(target_cell):
				event_name = &"socket_activated"
				msg = "Block matches socket! Socket activated!"
			else:
				event_name = &"socket_mismatch"
				msg = "Block placed on socket, but color does not match."
				
		return {
			"success": true,
			"next_state": next,
			"event": event_name,
			"message": msg
		}
		
	return {
		"success": false,
		"next_state": next,
		"event": &"cannot_place",
		"message": "Invalid cell type for block placement."
	}

static func _apply_steal_block(next: BoardState, target_cell: Vector2i) -> Dictionary:
	# Rule: Pip cannot steal block from under their own feet
	if target_cell == next.player_pos:
		return {
			"success": false,
			"next_state": next,
			"event": &"cannot_steal_under_self",
			"message": "Cannot steal block beneath yourself."
		}

	# Check if target contains a movable block
	if not next.has_block_at(target_cell):
		return {
			"success": false,
			"next_state": next,
			"event": &"nothing_to_steal",
			"message": "No block in front of player to steal."
		}
		
	var target_block: Dictionary = next.blocks[target_cell]
	var was_bridge: bool = target_block.get("is_bridge", false)
	
	# Pick up block into player's glove
	next.carried_block = {
		"id": target_block["id"],
		"color": target_block["color"]
	}
	next.blocks.erase(target_cell)
	next.turn_count += 1
	
	var event_name: StringName = &"block_stolen"
	var msg: String = "Stole block into Pixel Glove."
	if was_bridge:
		event_name = &"bridge_stolen"
		msg = "Stole bridge block from void."
		
	return {
		"success": true,
		"next_state": next,
		"event": event_name,
		"message": msg
	}
