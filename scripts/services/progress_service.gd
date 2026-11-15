class_name ProgressService extends RefCounted

## Manages persistence for campaign progress, high scores, and user preferences.
## Includes schema versioning (v1), corrupted save recovery, performance medals, and tutorials.

const SAVE_PATH = "user://pixel_save.json"
const BACKUP_PATH = "user://pixel_save.bak"
const SCHEMA_VERSION = 1

## Authoritative minimal optimal move targets verified by BFS/A* solver
const OPTIMAL_MOVES: Dictionary = {
	"demo_01": 5,
	"demo_02": 8,
	"demo_03": 10,
	"ch1_01": 5,
	"ch1_02": 8,
	"ch1_03": 10,
	"ch1_04": 14,
	"ch1_05": 15,
	"ch2_01": 6,
	"ch2_02": 9,
	"ch2_03": 12,
	"ch2_04": 16,
	"ch2_05": 20,
	"ch3_01": 8,
	"ch3_02": 13,
	"ch3_03": 16,
	"ch3_04": 19,
	"ch3_05": 22,
	"ch4_01": 12,
	"ch4_02": 16,
	"ch4_03": 20,
	"ch4_04": 25,
	"ch4_05": 30
}

## Contextual tutorial hints displayed non-intrusively on key pedagogical levels
const TUTORIAL_TEXTS: Dictionary = {
	"demo_01": "WASD / Arrows to Move. Walk directly into a block to Steal it.",
	"demo_02": "E or Space to Place carried block. Clear obstacles to reach the Exit.",
	"demo_03": "Z to Undo any move. R to Restart. Reach the glowing cyan Exit!",
	"ch1_01": "The Stolen Street: Shift+Direction interacts without stepping.",
	"ch2_01": "The Broken Bridges: Placing blocks into Void creates walkable Bridges.",
	"ch2_04": "Cross your bridge, turn around, and Steal it back to leapfrog chasms!",
	"ch3_01": "The Forgotten Vault: Place blocks into Sockets to energize the Exit Portal.",
	"ch4_01": "The Chromatic Core: Colored Sockets require matching color fragments."
}

static var _cached_data: Dictionary = {}

static func _get_default_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unlocked_level": "ch1_01",
		"completed_levels": {},
		"settings": {
			"master_volume": 1.0,
			"sfx_volume": 1.0,
			"music_volume": 0.8,
			"sfx_enabled": true,
			"music_enabled": true,
			"reduced_motion": false,
			"screen_shake": true,
			"high_contrast": false
		},
		"tutorial_seen": {}
	}

static func reset_progress() -> void:
	_cached_data = _get_default_data()
	save_progress(_cached_data)

static func has_saved_game() -> bool:
	var data := load_progress()
	var completed: Dictionary = data.get("completed_levels", {})
	if not completed.is_empty():
		return true
	var unlocked: String = data.get("unlocked_level", "ch1_01")
	return unlocked != "ch1_01" and unlocked != ""

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
		var d: Dictionary = json.data
		# Validate schema integrity
		if _validate_save_dict(d):
			_cached_data = d
			return _cached_data
			
	# File is corrupted or invalid: create backup and restore defaults
	_backup_corrupted_save(text)
	_cached_data = default_data.duplicate(true)
	save_progress(_cached_data)
	return _cached_data

static func _validate_save_dict(d: Dictionary) -> bool:
	if not d.has("schema_version") or not (d["schema_version"] is int or d["schema_version"] is float):
		return false
	if not d.has("completed_levels") or not (d["completed_levels"] is Dictionary):
		return false
	if not d.has("settings") or not (d["settings"] is Dictionary):
		return false
	return true

static func _backup_corrupted_save(raw_content: String) -> void:
	var backup_file := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if backup_file != null:
		backup_file.store_string(raw_content)
		backup_file.close()

static func save_progress(data: Dictionary) -> void:
	if not data.has("schema_version"):
		data["schema_version"] = SCHEMA_VERSION
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

static func get_level_best_turns(level_id: String) -> int:
	var data := load_progress()
	return data.get("completed_levels", {}).get(level_id, -1)

static func get_optimal_moves(level_id: String) -> int:
	return OPTIMAL_MOVES.get(level_id, 10)

static func get_level_medal(level_id: String, turns: int) -> String:
	if turns <= 0:
		return ""
	var opt: int = get_optimal_moves(level_id)
	if turns <= opt:
		return "Gold"
	elif turns <= opt + 3:
		return "Silver"
	else:
		return "Bronze"

static func get_medal_symbol(medal: String) -> String:
	match medal:
		"Gold": return "★"
		"Silver": return "◈"
		"Bronze": return "•"
		_: return "-"

static func is_tutorial_seen(level_id: String) -> bool:
	var data := load_progress()
	var seen: Dictionary = data.get("tutorial_seen", {})
	return seen.get(level_id, false)

static func mark_tutorial_seen(level_id: String) -> void:
	var data := load_progress()
	if not data.has("tutorial_seen"):
		data["tutorial_seen"] = {}
	data["tutorial_seen"][level_id] = true
	save_progress(data)

static func get_tutorial_text(level_id: String) -> String:
	return TUTORIAL_TEXTS.get(level_id, "")

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

static func get_chapter_completed_count(chapter_num: int) -> int:
	var data := load_progress()
	var completed: Dictionary = data.get("completed_levels", {})
	var count := 0
	if chapter_num == 0:
		for i in range(1, 4):
			if completed.has("demo_0%d" % i):
				count += 1
	elif chapter_num >= 1 and chapter_num <= 4:
		for i in range(1, 6):
			if completed.has("ch%d_0%d" % [chapter_num, i]):
				count += 1
	return count

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

static func get_continue_target() -> Dictionary:
	var data := load_progress()
	var current_unlocked: String = data.get("unlocked_level", "ch1_01")
	
	if current_unlocked.begins_with("demo_"):
		var idx := int(current_unlocked.substr(5)) - 1
		return {"chapter": 0, "level_idx": max(0, idx), "level_id": current_unlocked}
	elif current_unlocked.begins_with("ch"):
		var ch := int(current_unlocked.substr(2, 1))
		var idx := int(current_unlocked.substr(5, 2)) - 1
		return {"chapter": ch, "level_idx": max(0, idx), "level_id": current_unlocked}
	return {"chapter": 1, "level_idx": 0, "level_id": "ch1_01"}

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

