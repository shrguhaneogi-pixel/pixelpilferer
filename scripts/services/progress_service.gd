class_name ProgressService extends RefCounted

## Manages persistence for campaign progress, high scores, and user preferences.

const SAVE_PATH = "user://pixel_save.json"

static var _cached_data: Dictionary = {}

static func _get_default_data() -> Dictionary:
	return {
		"unlocked_level": "ch1_01",
		"completed_levels": {},
		"settings": {
			"sfx_volume": 1.0,
			"sfx_enabled": true,
			"reduced_motion": false
		}
	}

static func reset_progress() -> void:
	_cached_data = _get_default_data()
	save_progress(_cached_data)

static func load_progress() -> Dictionary:
	if not _cached_data.is_empty():
		return _cached_data
		
	var default_data := _get_default_data()
	
	if not FileAccess.file_exists(SAVE_PATH):
		_cached_data = default_data.duplicate(true)
		return _cached_data
		
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_cached_data = default_data.duplicate(true)
		return _cached_data
		
	var text := file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(text)
	if err == OK and json.data is Dictionary:
		_cached_data = json.data
		return _cached_data
		
	_cached_data = default_data.duplicate(true)
	return _cached_data

static func save_progress(data: Dictionary) -> void:
	_cached_data = data.duplicate(true)
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

static func is_level_completed(level_id: String) -> bool:
	var data := load_progress()
	return data.get("completed_levels", {}).has(level_id)

static func is_chapter_completed(chapter_num: int) -> bool:
	var data := load_progress()
	var completed: Dictionary = data.get("completed_levels", {})
	if chapter_num == 0:
		return completed.has("demo_01") and completed.has("demo_02") and completed.has("demo_03")
	elif chapter_num >= 1 and chapter_num <= 4:
		for i in range(1, 6):
			var lid := "ch%d_0%d" % [chapter_num, i]
			if not completed.has(lid):
				return false
		return true
	return false

static func is_campaign_completed() -> bool:
	return is_level_completed("ch4_05")

static func is_level_unlocked(chapter_num: int, level_idx: int) -> bool:
	# First levels are always unlocked
	if chapter_num == 0 and level_idx == 0:
		return true
	if chapter_num == 1 and level_idx == 0:
		return true
		
	var data := load_progress()
	var completed: Dictionary = data.get("completed_levels", {})
	var current_unlocked: String = data.get("unlocked_level", "ch1_01")
	
	# Determine target level ID
	var target_id := ""
	if chapter_num == 0:
		target_id = "demo_0%d" % (level_idx + 1)
	else:
		target_id = "ch%d_0%d" % [chapter_num, level_idx + 1]
		
	if completed.has(target_id) or current_unlocked == target_id:
		return true
		
	# Check prior level completion
	if level_idx > 0:
		var prev_id := ""
		if chapter_num == 0:
			prev_id = "demo_0%d" % level_idx
		else:
			prev_id = "ch%d_0%d" % [chapter_num, level_idx]
		return completed.has(prev_id)
	else:
		# First level of a chapter requires prior chapter completed
		return is_chapter_completed(chapter_num - 1)

static func get_chapter_restoration_text(chapter_num: int) -> String:
	match chapter_num:
		1: return "Sector 1 Restored: The Neon Grid Hums to Life."
		2: return "Sector 2 Restored: The Skyway Bridges Solidify."
		3: return "Sector 3 Restored: Obsidian Conduits Radiate Amber."
		4: return "THE PIXEL CORE IS RESTORED! Full Spectrum Reawakening."
		_: return "Training Sector Complete: Glove Synchronization Verified."

static func get_total_moves() -> int:
	var data := load_progress()
	var completed: Dictionary = data.get("completed_levels", {})
	var total := 0
	for lid in completed:
		total += int(completed[lid])
	return total

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
