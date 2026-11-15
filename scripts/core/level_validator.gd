class_name LevelValidator extends RefCounted

## Strict formal level validator for Pixel Pilferer.
## Validates level schema, layout geometry, entity placement, and campaign integrity.
## Rejects illegal configurations with actionable error messages specifying level ID, rule, and coordinates.

const TileType = Constants.TileType
const BlockColor = Constants.BlockColor

const VALID_LAYOUT_CHARS: String = "#. PSE1234"

## Validates a single level definition dictionary.
## Returns { "valid": bool, "error": String, "field": String, "cell": Vector2i }
static func validate_level(d: Dictionary, seen_ids: Array = []) -> Dictionary:
	# 1. Identity & Metadata
	if not d.has("id") or str(d["id"]).strip_edges().is_empty():
		return _fail("Missing or empty 'id' field.", &"id", Vector2i(-1, -1))
	var level_id: String = str(d["id"]).strip_edges()
	
	if seen_ids.has(level_id):
		return _fail("Duplicate level ID '%s' found in campaign." % level_id, &"id", Vector2i(-1, -1), level_id)
		
	if not d.has("name") or str(d["name"]).strip_edges().is_empty():
		return _fail("Level '%s' has missing or empty 'name' field." % level_id, &"name", Vector2i(-1, -1), level_id)
		
	# 2. Dimensions
	var w: int = d.get("width", 0)
	var h: int = d.get("height", 0)
	if w <= 0 or h <= 0:
		return _fail("Level '%s' dimensions width (%d) and height (%d) must be positive integers." % [level_id, w, h], &"dimensions", Vector2i(w, h), level_id)
		
	# 3. Layout checks (rectangularity, row count, character set)
	if not d.has("layout") or not (d["layout"] is Array):
		return _fail("Level '%s' is missing required 'layout' array." % level_id, &"layout", Vector2i(-1, -1), level_id)
		
	var layout: Array = d["layout"]
	if layout.size() != h:
		return _fail("Level '%s' layout row count (%d) does not match declared height (%d)." % [level_id, layout.size(), h], &"layout", Vector2i(0, layout.size()), level_id)
		
	var layout_p_cells: Array[Vector2i] = []
	var layout_e_cells: Array[Vector2i] = []
	var terrain_map: Dictionary = {} # Vector2i -> TileType
	var socket_map: Dictionary = {} # Vector2i -> BlockColor
	
	for y: int in layout.size():
		var row_val = layout[y]
		if not (row_val is String):
			return _fail("Level '%s' row %d is not a valid string." % [level_id, y], &"layout", Vector2i(0, y), level_id)
		var row: String = row_val
		if row.length() != w:
			return _fail("Level '%s' has ragged layout: Row %d length (%d) does not match declared width (%d)." % [level_id, y, row.length(), w], &"layout", Vector2i(row.length(), y), level_id)
			
		for x: int in row.length():
			var ch: String = row[x]
			var cell := Vector2i(x, y)
			
			if VALID_LAYOUT_CHARS.find(ch) == -1:
				return _fail("Level '%s' contains unknown character '%s' at cell (%d, %d)." % [level_id, ch, x, y], &"layout", cell, level_id)
				
			match ch:
				"#":
					terrain_map[cell] = TileType.WALL
				".":
					terrain_map[cell] = TileType.FLOOR
				" ":
					terrain_map[cell] = TileType.VOID
				"P":
					terrain_map[cell] = TileType.FLOOR
					layout_p_cells.append(cell)
				"E":
					terrain_map[cell] = TileType.FLOOR
					layout_e_cells.append(cell)
				"S":
					terrain_map[cell] = TileType.FLOOR
					socket_map[cell] = BlockColor.NEUTRAL
				"1":
					terrain_map[cell] = TileType.FLOOR
					socket_map[cell] = BlockColor.CYAN
				"2":
					terrain_map[cell] = TileType.FLOOR
					socket_map[cell] = BlockColor.AMBER
				"3":
					terrain_map[cell] = TileType.FLOOR
					socket_map[cell] = BlockColor.MAGENTA
				"4":
					terrain_map[cell] = TileType.FLOOR
					socket_map[cell] = BlockColor.EMERALD

	# 4. Player start validation
	if layout_p_cells.size() > 1:
		return _fail("Level '%s' has %d duplicate player start markers in layout (first at %s, second at %s)." % [level_id, layout_p_cells.size(), str(layout_p_cells[0]), str(layout_p_cells[1])], &"player_start", layout_p_cells[1], level_id)
		
	var player_start_pos := Vector2i(-1, -1)
	if d.has("player_start"):
		var p_raw = d["player_start"]
		if not (p_raw is Array) or p_raw.size() != 2:
			return _fail("Level '%s' player_start must be a 2-element array [x, y]." % level_id, &"player_start", Vector2i(-1, -1), level_id)
		var p_cand := Vector2i(int(p_raw[0]), int(p_raw[1]))
		if p_cand.x < 0 or p_cand.x >= w or p_cand.y < 0 or p_cand.y >= h:
			return _fail("Level '%s' player_start (%d, %d) is out of bounds [0..%d, 0..%d]." % [level_id, p_cand.x, p_cand.y, w - 1, h - 1], &"player_start", p_cand, level_id)
		if not layout_p_cells.is_empty() and layout_p_cells[0] != p_cand:
			return _fail("Level '%s' has conflicting player start in layout (%d, %d) and player_start (%d, %d)." % [level_id, layout_p_cells[0].x, layout_p_cells[0].y, p_cand.x, p_cand.y], &"player_start", p_cand, level_id)
		player_start_pos = p_cand
	elif not layout_p_cells.is_empty():
		player_start_pos = layout_p_cells[0]
	else:
		return _fail("Level '%s' is missing required player start position ('P' in layout or 'player_start')." % level_id, &"player_start", Vector2i(-1, -1), level_id)

	var p_tile: int = terrain_map.get(player_start_pos, TileType.EMPTY)
	if p_tile == TileType.WALL:
		return _fail("Level '%s' player start at (%d, %d) is inside an impassable wall." % [level_id, player_start_pos.x, player_start_pos.y], &"player_start", player_start_pos, level_id)
	elif p_tile == TileType.VOID:
		return _fail("Level '%s' player start at (%d, %d) is inside an impassable void." % [level_id, player_start_pos.x, player_start_pos.y], &"player_start", player_start_pos, level_id)

	# 5. Exit portal validation
	if layout_e_cells.size() > 1:
		return _fail("Level '%s' has %d duplicate exit portal markers in layout (first at %s, second at %s)." % [level_id, layout_e_cells.size(), str(layout_e_cells[0]), str(layout_e_cells[1])], &"exit", layout_e_cells[1], level_id)
		
	var exit_pos := Vector2i(-1, -1)
	if d.has("exit_pos"):
		var e_raw = d["exit_pos"]
		if not (e_raw is Array) or e_raw.size() != 2:
			return _fail("Level '%s' exit_pos must be a 2-element array [x, y]." % level_id, &"exit_pos", Vector2i(-1, -1), level_id)
		var e_cand := Vector2i(int(e_raw[0]), int(e_raw[1]))
		if e_cand.x < 0 or e_cand.x >= w or e_cand.y < 0 or e_cand.y >= h:
			return _fail("Level '%s' exit_pos (%d, %d) is out of bounds [0..%d, 0..%d]." % [level_id, e_cand.x, e_cand.y, w - 1, h - 1], &"exit_pos", e_cand, level_id)
		if not layout_e_cells.is_empty() and layout_e_cells[0] != e_cand:
			return _fail("Level '%s' has conflicting exit in layout (%d, %d) and exit_pos (%d, %d)." % [level_id, layout_e_cells[0].x, layout_e_cells[0].y, e_cand.x, e_cand.y], &"exit_pos", e_cand, level_id)
		exit_pos = e_cand
	elif not layout_e_cells.is_empty():
		exit_pos = layout_e_cells[0]
	else:
		return _fail("Level '%s' is missing required exit portal position ('E' in layout or 'exit_pos')." % level_id, &"exit", Vector2i(-1, -1), level_id)

	var e_tile: int = terrain_map.get(exit_pos, TileType.EMPTY)
	if e_tile == TileType.WALL:
		return _fail("Level '%s' exit portal at (%d, %d) is inside an impassable wall." % [level_id, exit_pos.x, exit_pos.y], &"exit", exit_pos, level_id)
	elif e_tile == TileType.VOID:
		return _fail("Level '%s' exit portal at (%d, %d) is inside an impassable void." % [level_id, exit_pos.x, exit_pos.y], &"exit", exit_pos, level_id)

	# 6. Explicit Sockets validation (if provided as array or dict)
	if d.has("sockets"):
		var s_data = d["sockets"]
		if s_data is Array:
			for s_item in s_data:
				if not (s_item is Dictionary) or not s_item.has("pos"):
					return _fail("Level '%s' socket item must be a dictionary with 'pos'." % level_id, &"sockets", Vector2i(-1, -1), level_id)
				var spos := Vector2i(int(s_item["pos"][0]), int(s_item["pos"][1]))
				if spos.x < 0 or spos.x >= w or spos.y < 0 or spos.y >= h:
					return _fail("Level '%s' socket coordinate (%d, %d) is out of bounds." % [level_id, spos.x, spos.y], &"sockets", spos, level_id)
				var st: int = terrain_map.get(spos, TileType.EMPTY)
				if st == TileType.WALL:
					return _fail("Level '%s' socket at (%d, %d) cannot be placed on solid wall." % [level_id, spos.x, spos.y], &"sockets", spos, level_id)
				elif st == TileType.VOID:
					return _fail("Level '%s' socket at (%d, %d) cannot be placed on void." % [level_id, spos.x, spos.y], &"sockets", spos, level_id)
				var scol: int = s_item.get("color", BlockColor.NEUTRAL)
				if scol < BlockColor.NEUTRAL or scol > BlockColor.EMERALD:
					return _fail("Level '%s' socket at (%d, %d) has invalid color %d." % [level_id, spos.x, spos.y, scol], &"sockets", spos, level_id)
				socket_map[spos] = scol

	# 7. Movable Blocks validation
	var block_cells: Dictionary = {} # Vector2i -> Dictionary
	if d.has("blocks"):
		var blocks_list = d["blocks"]
		if not (blocks_list is Array):
			return _fail("Level '%s' 'blocks' must be an array." % level_id, &"blocks", Vector2i(-1, -1), level_id)
			
		for b_idx: int in blocks_list.size():
			var b = blocks_list[b_idx]
			if not (b is Dictionary) or not b.has("pos"):
				return _fail("Level '%s' block at index %d must be a dictionary with 'pos'." % [level_id, b_idx], &"blocks", Vector2i(-1, -1), level_id)
			var b_pos_arr = b["pos"]
			if not (b_pos_arr is Array) or b_pos_arr.size() != 2:
				return _fail("Level '%s' block index %d pos must be [x, y]." % [level_id, b_idx], &"blocks", Vector2i(-1, -1), level_id)
			var b_pos := Vector2i(int(b_pos_arr[0]), int(b_pos_arr[1]))
			
			# Bounds check
			if b_pos.x < 0 or b_pos.x >= w or b_pos.y < 0 or b_pos.y >= h:
				return _fail("Level '%s' block at index %d has out-of-bounds coordinate (%d, %d)." % [level_id, b_idx, b_pos.x, b_pos.y], &"blocks", b_pos, level_id)
				
			# Color check
			var b_col: int = b.get("color", BlockColor.NEUTRAL)
			if b_col < BlockColor.NEUTRAL or b_col > BlockColor.EMERALD:
				return _fail("Level '%s' block at (%d, %d) has invalid fragment color %d (must be 0..4)." % [level_id, b_pos.x, b_pos.y, b_col], &"blocks", b_pos, level_id)
				
			# Overlapping blocks check
			if block_cells.has(b_pos):
				return _fail("Level '%s' has overlapping movable blocks at cell (%d, %d)." % [level_id, b_pos.x, b_pos.y], &"blocks", b_pos, level_id)
			block_cells[b_pos] = b
			
			# Terrain check
			var b_tile: int = terrain_map.get(b_pos, TileType.EMPTY)
			if b_tile == TileType.WALL:
				return _fail("Level '%s' movable block at (%d, %d) is placed on an immutable wall." % [level_id, b_pos.x, b_pos.y], &"blocks", b_pos, level_id)
				
			# Overlap with player start check
			if b_pos == player_start_pos:
				return _fail("Level '%s' movable block at (%d, %d) overlaps player start position." % [level_id, b_pos.x, b_pos.y], &"blocks", b_pos, level_id)
				
			# Overlap with exit portal check
			if b_pos == exit_pos:
				return _fail("Level '%s' movable block at (%d, %d) overlaps exit portal." % [level_id, b_pos.x, b_pos.y], &"blocks", b_pos, level_id)

	# 8. Start-completed check
	var allow_start_completed: bool = d.get("allow_start_completed", false)
	if not allow_start_completed:
		if player_start_pos == exit_pos:
			# Check if all sockets are initially satisfied
			var all_sockets_ok: bool = true
			for spos: Vector2i in socket_map:
				if not block_cells.has(spos):
					all_sockets_ok = false
					break
				var req_col: int = socket_map[spos]
				var cur_col: int = block_cells[spos].get("color", BlockColor.NEUTRAL)
				if req_col != BlockColor.NEUTRAL and req_col != cur_col:
					all_sockets_ok = false
					break
			if all_sockets_ok:
				return _fail("Level '%s' starts in an already completed state at (%d, %d) with all sockets satisfied. Set 'allow_start_completed': true if intentional." % [level_id, player_start_pos.x, player_start_pos.y], &"completion", player_start_pos, level_id)

	return {
		"valid": true,
		"error": "",
		"field": &"",
		"cell": Vector2i(-1, -1),
		"level_id": level_id
	}

## Validates an entire campaign array of level dictionaries.
## Ensures every level is valid and IDs are unique across the campaign.
static func validate_campaign(levels: Array) -> Dictionary:
	var seen_ids: Array[String] = []
	for idx: int in levels.size():
		var lvl = levels[idx]
		if not (lvl is Dictionary):
			return _fail("Campaign level at index %d is not a valid dictionary." % idx, &"campaign", Vector2i(-1, -1))
		var res: Dictionary = validate_level(lvl, seen_ids)
		if not res["valid"]:
			return res
		seen_ids.append(res["level_id"])
		
	return {
		"valid": true,
		"error": "",
		"field": &"",
		"cell": Vector2i(-1, -1),
		"level_id": ""
	}

static func _fail(msg: String, field: StringName, cell: Vector2i, level_id: String = "") -> Dictionary:
	return {
		"valid": false,
		"error": msg,
		"field": field,
		"cell": cell,
		"level_id": level_id
	}
