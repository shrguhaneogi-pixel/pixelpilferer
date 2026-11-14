class_name LevelData extends RefCounted

const TileType = Constants.TileType
const BlockColor = Constants.BlockColor

static func from_dict(dict: Dictionary) -> BoardState:
	var state := BoardState.new()
	var w: int = dict.get("width", 10)
	var h: int = dict.get("height", 8)
	state.grid_size = Vector2i(w, h)
	
	# Parse tiles
	# Legend:
	# '#' = Wall
	# '.' = Floor
	# ' ' = Void
	# 'P' = Player start (on floor)
	# 'E' = Exit portal (on floor)
	# 'S' = Neutral Socket (on floor)
	# '1' = Cyan Socket (on floor)
	# '2' = Amber Socket (on floor)
	# '3' = Magenta Socket (on floor)
	# '4' = Emerald Socket (on floor)
	var layout: Array = dict.get("layout", [])
	var block_id_counter: int = 1
	
	for y: int in layout.size():
		var row: String = layout[y]
		for x: int in row.length():
			var char_code: String = row[x]
			var cell := Vector2i(x, y)
			
			match char_code:
				"#":
					state.tiles[cell] = TileType.WALL
				".":
					state.tiles[cell] = TileType.FLOOR
				" ":
					state.tiles[cell] = TileType.VOID
				"P":
					state.tiles[cell] = TileType.FLOOR
					state.player_pos = cell
				"E":
					state.tiles[cell] = TileType.FLOOR
					state.exit_cell = cell
				"S":
					state.tiles[cell] = TileType.FLOOR
					state.sockets[cell] = BlockColor.NEUTRAL
				"1":
					state.tiles[cell] = TileType.FLOOR
					state.sockets[cell] = BlockColor.CYAN
				"2":
					state.tiles[cell] = TileType.FLOOR
					state.sockets[cell] = BlockColor.AMBER
				"3":
					state.tiles[cell] = TileType.FLOOR
					state.sockets[cell] = BlockColor.MAGENTA
				"4":
					state.tiles[cell] = TileType.FLOOR
					state.sockets[cell] = BlockColor.EMERALD
				_:
					state.tiles[cell] = TileType.FLOOR

	# Explicit blocks definition: array of { "pos": [x, y], "color": int, "is_bridge": bool }
	if dict.has("blocks"):
		for b: Dictionary in dict["blocks"]:
			var b_pos := Vector2i(b["pos"][0], b["pos"][1])
			var b_col: int = b.get("color", BlockColor.NEUTRAL)
			var is_br: bool = b.get("is_bridge", false)
			state.blocks[b_pos] = {
				"id": block_id_counter,
				"color": b_col,
				"is_bridge": is_br
			}
			block_id_counter += 1

	if dict.has("player_start"):
		state.player_pos = Vector2i(dict["player_start"][0], dict["player_start"][1])
	if dict.has("exit_pos"):
		state.exit_cell = Vector2i(dict["exit_pos"][0], dict["exit_pos"][1])

	return state
