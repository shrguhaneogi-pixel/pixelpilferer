class_name ProgressService extends RefCounted

## Manages persistence for campaign progress, high scores, and user preferences.

const SAVE_PATH = "user://pixel_save.json"

static func load_progress() -> Dictionary:
	var default_data = {
		"unlocked_level": "ch1_01",
		"completed_levels": {},
		"settings": {
			"sfx_volume": 1.0,
			"sfx_enabled": true,
			"reduced_motion": false
		}
	}
	
	if not FileAccess.file_exists(SAVE_PATH):
		return default_data
		
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_data
		
	var text := file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(text)
	if err == OK and json.data is Dictionary:
		return json.data
	return default_data

static func save_progress(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func record_level_completion(level_id: String, turns: int, next_level_id: String = "") -> void:
	var data := load_progress()
	if not data.has("completed_levels"):
		data["completed_levels"] = {}
		
	var prev_best: int = data["completed_levels"].get(level_id, 999999)
	if turns < prev_best:
		data["completed_levels"][level_id] = turns
		
	if next_level_id != "" and not data.get("completed_levels", {}).has(next_level_id):
		data["unlocked_level"] = next_level_id
		
	save_progress(data)

static func get_setting(key: String, default_val: Variant) -> Variant:
	var data := load_progress()
	var s: Dictionary = data.get("settings", {})
	return s.get(key, default_val)

static func set_setting(key: String, val: Variant) -> void:
	var data := load_progress()
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"][key] = val
	save_progress(data)
