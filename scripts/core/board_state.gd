class_name BoardState extends RefCounted

const TileType = Constants.TileType
const BlockColor = Constants.BlockColor

var grid_size: Vector2i = Vector2i(10, 10)
# Base tiles: Map from Vector2i to TileType
var tiles: Dictionary = {}
# Sockets: Map from Vector2i to BlockColor required
var sockets: Dictionary = {}
# Blocks: Map from Vector2i to { id: int, color: int, is_bridge: bool }
var blocks: Dictionary = {}
# Exit cell position
var exit_cell: Vector2i = Vector2i(-1, -1)
# Player state
var player_pos: Vector2i = Vector2i(0, 0)
var player_facing: Vector2i = Constants.DIR_SOUTH
# Carried block: Dictionary with keys "id", "color" or empty if none
var carried_block: Dictionary = {}
# Gameplay metrics
var turn_count: int = 0
var is_completed: bool = false

func duplicate_state() -> BoardState:
	var copy := BoardState.new()
	copy.grid_size = grid_size
	copy.tiles = tiles.duplicate(true)
	copy.sockets = sockets.duplicate(true)
	
	# Deep copy blocks
	copy.blocks = {}
	for pos: Vector2i in blocks:
		var b: Dictionary = blocks[pos]
		copy.blocks[pos] = {
			"id": b["id"],
			"color": b["color"],
			"is_bridge": b["is_bridge"]
		}
	
	copy.exit_cell = exit_cell
	copy.player_pos = player_pos
	copy.player_facing = player_facing
	
	if carried_block.is_empty():
		copy.carried_block = {}
	else:
		copy.carried_block = {
			"id": carried_block["id"],
			"color": carried_block["color"]
		}
		
	copy.turn_count = turn_count
	copy.is_completed = is_completed
	return copy

func is_inside_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < grid_size.x and pos.y < grid_size.y

func get_tile(pos: Vector2i) -> int:
	return tiles.get(pos, TileType.EMPTY)

func has_block_at(pos: Vector2i) -> bool:
	return blocks.has(pos)

func get_block_at(pos: Vector2i) -> Dictionary:
	return blocks.get(pos, {})

func is_bridge_at(pos: Vector2i) -> bool:
	if not blocks.has(pos):
		return false
	return blocks[pos].get("is_bridge", false)

func is_walkable(pos: Vector2i) -> bool:
	if not is_inside_grid(pos):
		return false
		
	var tile: int = get_tile(pos)
	
	# Immutable wall is never walkable
	if tile == TileType.WALL:
		return false
	if tile == TileType.EMPTY:
		return false
		
	# Void is only walkable if bridged by a block
	if tile == TileType.VOID:
		return is_bridge_at(pos)
		
	# Floor is walkable ONLY if NOT occupied by an obstacle block
	if tile == TileType.FLOOR:
		if has_block_at(pos):
			# If block is marked bridge (e.g. unexpected), or standard obstacle
			return blocks[pos].get("is_bridge", false)
		return true
		
	return false

func is_socket_satisfied(pos: Vector2i) -> bool:
	if not sockets.has(pos):
		return true
	if not blocks.has(pos):
		return false
		
	var req_color: int = sockets[pos]
	var block_color: int = blocks[pos]["color"]
	
	# Neutral socket accepts any block
	if req_color == BlockColor.NEUTRAL:
		return true
		
	# Colored socket requires exact match
	return req_color == block_color

func is_all_sockets_satisfied() -> bool:
	for pos: Vector2i in sockets:
		if not is_socket_satisfied(pos):
			return false
	return true

func is_carrying() -> bool:
	return not carried_block.is_empty()

func get_state_hash() -> String:
	# Format: P(x,y,face)|C(id,col)|B[(x,y,col,bridge)...]
	var parts: Array[String] = []
	parts.append("P(%d,%d,%d,%d)" % [player_pos.x, player_pos.y, player_facing.x, player_facing.y])
	
	if is_carrying():
		parts.append("C(%d,%d)" % [carried_block["id"], carried_block["color"]])
	else:
		parts.append("C(-)")
		
	var block_keys: Array = blocks.keys()
	block_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x: return a.x < b.x
		return a.y < b.y
	)
	
	var b_parts: Array[String] = []
	for k: Vector2i in block_keys:
		var b: Dictionary = blocks[k]
		b_parts.append("(%d,%d:%d,%d)" % [k.x, k.y, b["color"], 1 if b["is_bridge"] else 0])
	parts.append("B[" + ",".join(b_parts) + "]")
	
	return "|".join(parts)
