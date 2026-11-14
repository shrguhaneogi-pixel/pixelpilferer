class_name GameRules extends RefCounted

## Authoritative state transition engine for Pixel Pilferer.
## Implements (S_t, Action) -> ActionResult.
## Completely independent of rendering and framerate.

const ActionType = Constants.ActionType
const TileType = Constants.TileType
const BlockColor = Constants.BlockColor

static func apply_action(current_state: BoardState, action: int) -> Dictionary:
	if current_state == null:
		return _make_failure_result(current_state, action, Vector2i.ZERO, Vector2i.ZERO, &"null_state", "Current state is null.")
		
	if current_state.is_completed:
		return _make_failure_result(current_state, action, current_state.player_pos, current_state.player_pos, &"already_completed", "Level is already completed.")

	if Constants.is_move_action(action):
		return _apply_move(current_state, action)
	elif Constants.is_interact_action(action):
		return _apply_interact(current_state, action)
	else:
		return _make_failure_result(current_state, action, current_state.player_pos, current_state.player_pos, &"invalid_action", "Unknown action.")

static func _apply_move(current_state: BoardState, action: int) -> Dictionary:
	var dir: Vector2i = Constants.action_to_direction(action)
	var source_cell: Vector2i = current_state.player_pos
	var target_cell: Vector2i = source_cell + dir
	
	# Out of bounds check
	if not current_state.is_inside_grid(target_cell):
		return _make_failure_result(current_state, action, source_cell, target_cell, &"blocked_bounds", "Cannot move out of bounds.")
		
	# Terrain and obstacle check
	if not current_state.is_walkable(target_cell):
		var tile: int = current_state.get_tile(target_cell)
		var reason: StringName = &"blocked"
		var msg: String = "Path obstructed."
		
		if tile == TileType.WALL:
			reason = &"blocked_wall"
			msg = "Cannot walk into solid immutable wall."
		elif tile == TileType.VOID and not current_state.is_bridge_at(target_cell):
			reason = &"blocked_void"
			msg = "Cannot step into unbridged void."
		elif current_state.has_block_at(target_cell) and not current_state.is_bridge_at(target_cell):
			reason = &"blocked_block"
			msg = "Cell is obstructed by a movable block on floor."
			
		return _make_failure_result(current_state, action, source_cell, target_cell, reason, msg)
		
	# Move is valid! Create deep copy for next state
	var next: BoardState = current_state.duplicate_state()
	next.player_facing = dir
	next.player_pos = target_cell
	next.turn_count += 1
	
	# Check exit condition
	if target_cell == next.exit_cell:
		if next.is_all_sockets_satisfied():
			next.is_completed = true
			return {
				"success": true,
				"action": action,
				"source_cell": source_cell,
				"target_cell": target_cell,
				"block_id": -1,
				"block_color": -1,
				"is_bridge": false,
				"is_completed": true,
				"rejection_reason": &"",
				"event": &"level_cleared",
				"message": "All required sockets active! Level completed!",
				"next_state": next
			}
		else:
			return {
				"success": true,
				"action": action,
				"source_cell": source_cell,
				"target_cell": target_cell,
				"block_id": -1,
				"block_color": -1,
				"is_bridge": false,
				"is_completed": false,
				"rejection_reason": &"",
				"event": &"player_moved",
				"message": "Exit reached, but sockets remain unsatisfied.",
				"next_state": next
			}
			
	return {
		"success": true,
		"action": action,
		"source_cell": source_cell,
		"target_cell": target_cell,
		"block_id": -1,
		"block_color": -1,
		"is_bridge": false,
		"is_completed": false,
		"rejection_reason": &"",
		"event": &"player_moved",
		"message": "Player moved.",
		"next_state": next
	}

static func _apply_interact(current_state: BoardState, action: int) -> Dictionary:
	var dir: Vector2i = Constants.action_to_direction(action)
	var source_cell: Vector2i = current_state.player_pos
	var target_cell: Vector2i = source_cell + dir
	
	# Target bounds check
	if not current_state.is_inside_grid(target_cell):
		return _make_failure_result(current_state, action, source_cell, target_cell, &"interact_out_of_bounds", "Target cell is out of bounds.")

	# CASE 1: Player is currently carrying a block -> Attempt to PLACE
	if current_state.is_carrying():
		return _apply_place(current_state, action, source_cell, target_cell, dir)
		
	# CASE 2: Player is carrying nothing -> Attempt to PICK UP / STEAL
	else:
		return _apply_steal(current_state, action, source_cell, target_cell, dir)

static func _apply_place(current_state: BoardState, action: int, source_cell: Vector2i, target_cell: Vector2i, dir: Vector2i) -> Dictionary:
	# Rule: Cannot place on player's current cell
	if target_cell == current_state.player_pos:
		return _make_failure_result(current_state, action, source_cell, target_cell, &"cannot_place_on_player", "Cannot place block on player position.")
		
	# Rule: Cannot place on exit cell
	if target_cell == current_state.exit_cell:
		return _make_failure_result(current_state, action, source_cell, target_cell, &"cannot_place_on_exit", "Cannot place block on the exit portal.")
		
	# Rule: Cannot place on immutable wall
	var tile: int = current_state.get_tile(target_cell)
	if tile == TileType.WALL or tile == TileType.EMPTY:
		return _make_failure_result(current_state, action, source_cell, target_cell, &"cannot_place_on_wall", "Cannot place block on immutable wall.")
		
	# Rule: Cannot place on another existing block
	if current_state.has_block_at(target_cell):
		return _make_failure_result(current_state, action, source_cell, target_cell, &"cannot_place_on_block", "Target cell already contains a block.")
		
	var next: BoardState = current_state.duplicate_state()
	next.player_facing = dir
	
	var block_to_place: Dictionary = next.carried_block
	next.carried_block = {}
	next.turn_count += 1
	
	var b_id: int = block_to_place["id"]
	var b_col: int = block_to_place["color"]
	
	# Placing on VOID -> creates a bridge!
	if tile == TileType.VOID:
		next.blocks[target_cell] = {
			"id": b_id,
			"color": b_col,
			"is_bridge": true
		}
		return {
			"success": true,
			"action": action,
			"source_cell": source_cell,
			"target_cell": target_cell,
			"block_id": b_id,
			"block_color": b_col,
			"is_bridge": true,
			"is_completed": false,
			"rejection_reason": &"",
			"event": &"bridge_created",
			"message": "Placed block as a bridge across void.",
			"next_state": next
		}
		
	# Placing on FLOOR -> creates an obstacle / may satisfy socket!
	elif tile == TileType.FLOOR:
		next.blocks[target_cell] = {
			"id": b_id,
			"color": b_col,
			"is_bridge": false
		}
		
		var event_name: StringName = &"block_placed"
		var msg: String = "Placed block on floor."
		
		if next.sockets.has(target_cell):
			if next.is_socket_satisfied(target_cell):
				event_name = &"socket_activated"
				msg = "Block matches socket! Socket activated!"
			else:
				event_name = &"socket_mismatch"
				msg = "Block placed on socket, but color does not match."
				
		return {
			"success": true,
			"action": action,
			"source_cell": source_cell,
			"target_cell": target_cell,
			"block_id": b_id,
			"block_color": b_col,
			"is_bridge": false,
			"is_completed": false,
			"rejection_reason": &"",
			"event": event_name,
			"message": msg,
			"next_state": next
		}
		
	return _make_failure_result(current_state, action, source_cell, target_cell, &"cannot_place", "Invalid target cell for block placement.")

static func _apply_steal(current_state: BoardState, action: int, source_cell: Vector2i, target_cell: Vector2i, dir: Vector2i) -> Dictionary:
	# Rule: Pip cannot steal block from under their own feet
	if target_cell == current_state.player_pos:
		return _make_failure_result(current_state, action, source_cell, target_cell, &"cannot_steal_under_self", "Cannot steal block beneath yourself.")

	# Rule: Check if target contains a movable block
	if not current_state.has_block_at(target_cell):
		return _make_failure_result(current_state, action, source_cell, target_cell, &"nothing_to_steal", "No block in target cell to pick up.")
		
	var target_block: Dictionary = current_state.blocks[target_cell]
	var was_bridge: bool = target_block.get("is_bridge", false)
	var b_id: int = target_block["id"]
	var b_col: int = target_block["color"]
	
	var next: BoardState = current_state.duplicate_state()
	next.player_facing = dir
	next.carried_block = {
		"id": b_id,
		"color": b_col
	}
	next.blocks.erase(target_cell)
	next.turn_count += 1
	
	var event_name: StringName = &"bridge_stolen" if was_bridge else &"block_stolen"
	var msg: String = "Stole bridge block from void." if was_bridge else "Stole block into Pixel Glove."
	
	return {
		"success": true,
		"action": action,
		"source_cell": source_cell,
		"target_cell": target_cell,
		"block_id": b_id,
		"block_color": b_col,
		"is_bridge": was_bridge,
		"is_completed": false,
		"rejection_reason": &"",
		"event": event_name,
		"message": msg,
		"next_state": next
	}

static func _make_failure_result(state: BoardState, action: int, src: Vector2i, dst: Vector2i, reason: StringName, msg: String) -> Dictionary:
	return {
		"success": false,
		"action": action,
		"source_cell": src,
		"target_cell": dst,
		"block_id": -1,
		"block_color": -1,
		"is_bridge": false,
		"is_completed": false,
		"rejection_reason": reason,
		"event": reason,
		"message": msg,
		"next_state": state # State remains completely unchanged
	}
