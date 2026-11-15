class_name SaveManager extends RefCounted

## Forwarding adapter to ProgressService for backwards compatibility.

static func load_progress() -> Dictionary:
	return ProgressService.load_progress()

static func save_progress(data: Dictionary) -> void:
	ProgressService.save_progress(data)

static func mark_level_completed(level_id: String, turns: int, next_level_id: String = "") -> void:
	ProgressService.record_level_completion(level_id, turns, next_level_id)
