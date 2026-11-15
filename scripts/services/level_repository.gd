class_name LevelRepository extends RefCounted

const LevelValidator = preload("res://scripts/core/level_validator.gd")

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
	return LevelValidator.validate_level(d)
