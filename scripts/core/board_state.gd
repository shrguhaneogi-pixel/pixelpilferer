class_name BoardState extends RefCounted

## Pure, deterministic data representation of a puzzle board state.

const TileType = Constants.TileType
const BlockColor = Constants.BlockColor

var grid_size: Vector2i = Vector2i(10, 10)

# Immutable base terrain layer: Vector2i -> TileType (FLOOR, VOID, WALL)
var tiles: Dictionary = {}

# Sockets layer: Vector2i -> BlockColor
var sockets: Dictionary = {}

# Dynamic movable blocks layer: Vector2i -> { "id": int, "color": int, "is_bridge": bool }
var blocks: Dictionary = {}

# Goal and actor coordinates
var exit_cell: Vector2i = Vector2i(-1, -1)
var player_pos: Vector2i = Vector2i(0, 0)
var initial_player_pos: Vector2i = Vector2i(0, 0)
var player_facing: Vector2i = Constants.DIR_SOUTH

# Carried block: Dictionary with "id", "color" or empty if carrying nothing
var carried_block: Dictionary = {}

# Turn count and level completion
var turn_count: int = 0
var is_completed: bool = false

func duplicate_state() -> BoardState:
	var copy := BoardState.new()
	copy.grid_size = grid_size
	copy.tiles = tiles.duplicate(true)
	copy.sockets = sockets.duplicate(true)
	
	# Deep copy dynamic blocks
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
	copy.initial_player_pos = initial_player_pos
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
	
	# Wall or unmapped boundary is never walkable
	if tile == TileType.WALL or tile == TileType.EMPTY:
		return false
		
	# Void is ONLY walkable if bridged by a block
	if tile == TileType.VOID:
		return is_bridge_at(pos)
		
	# Floor is walkable ONLY if NOT occupied by an obstacle block
	if tile == TileType.FLOOR:
		if has_block_at(pos):
			return is_bridge_at(pos)
		return true
		
	return false

func is_socket_satisfied(pos: Vector2i) -> bool:
	if not sockets.has(pos):
		return true
	if not blocks.has(pos):
		return false
		
	var req_color: int = sockets[pos]
	var block_color: int = blocks[pos]["color"]
	
	# Neutral socket accepts any color
	if req_color == BlockColor.NEUTRAL:
		return true
		
	# Colored socket requires exact match
	return req_color == block_color

func is_all_sockets_satisfied() -> bool:
	# Levels with no sockets trivially satisfy this condition
	if sockets.is_empty():
		return true
	for pos: Vector2i in sockets:
		if not is_socket_satisfied(pos):
			return false
	return true

func is_carrying() -> bool:
	return not carried_block.is_empty()

## Canonical state identity key for solver visited-state tracking and regression checks.
## States containing identical block colors at identical positions produce identical keys
## regardless of internal insertion order. Excludes turn_count and undo history.
func get_canonical_key() -> String:
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

func get_state_hash() -> String:
	return get_canonical_key()
