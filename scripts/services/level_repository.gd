class_name LevelRepository extends RefCounted

## Loads and validates level definitions from data/levels JSON resources.

static func get_chapter_path(chapter_num: int) -> String:
	if chapter_num == 0:
		return "res://data/levels/demo_levels.json"
	return "res://data/levels/ch%d_levels.json" % chapter_num

static func load_chapter(chapter_num: int) -> Dictionary:
	var path := get_chapter_path(chapter_num)
	if not FileAccess.file_exists(path):
		printerr("LevelRepository: Chapter file not found: %s" % path)
		return {}
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("LevelRepository: Failed to open chapter file: %s" % path)
		return {}
		
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	
	if err != OK or not (json.data is Dictionary):
		printerr("LevelRepository: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
		
	return json.data

static func load_level(chapter_num: int, level_index: int) -> Dictionary:
	var ch_data := load_chapter(chapter_num)
	if ch_data.is_empty():
		return {}
		
	var levels: Array = ch_data.get("levels", [])
	if level_index < 0 or level_index >= levels.size():
		printerr("LevelRepository: Invalid level index %d for chapter %d (total: %d)" % [level_index, chapter_num, levels.size()])
		return {}
		
	var lvl_dict: Dictionary = levels[level_index]
	var val_res := validate_level_dict(lvl_dict)
	if not val_res["valid"]:
		printerr("LevelRepository: Invalid level data in %s: %s" % [lvl_dict.get("id", "unknown"), val_res["error"]])
		return {}
		
	return lvl_dict

static func load_demo_level(index: int) -> Dictionary:
	return load_level(0, index)

static func validate_level_dict(d: Dictionary) -> Dictionary:
	if not d.has("id") or str(d["id"]).is_empty():
		return { "valid": false, "error": "Missing or empty 'id' field." }
		
	if not d.has("name") or str(d["name"]).is_empty():
		return { "valid": false, "error": "Missing or empty 'name' field." }
		
	var w: int = d.get("width", 0)
	var h: int = d.get("height", 0)
	if w <= 0 or h <= 0:
		return { "valid": false, "error": "Dimensions width and height must be positive integers." }
		
	var layout: Array = d.get("layout", [])
	if layout.size() != h:
		return { "valid": false, "error": "Layout row count (%d) does not match height (%d)." % [layout.size(), h] }
		
	var has_player: bool = d.has("player_start")
	var has_exit: bool = d.has("exit_pos")
	
	for y: int in layout.size():
		var row: String = layout[y]
		if row.length() != w:
			return { "valid": false, "error": "Row %d length (%d) does not match width (%d)." % [y, row.length(), w] }
		if "P" in row:
			has_player = true
		if "E" in row:
			has_exit = true
			
	if not has_player:
		return { "valid": false, "error": "Level must specify player start position ('P' in layout or 'player_start')." }
	if not has_exit:
		return { "valid": false, "error": "Level must specify exit portal position ('E' in layout or 'exit_pos')." }
		
	return { "valid": true, "error": "" }
