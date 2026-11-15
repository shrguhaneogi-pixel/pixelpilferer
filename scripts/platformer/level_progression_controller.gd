class_name LevelProgressionController extends Node

const PlatformerLevel = preload("res://scripts/platformer/platformer_level.gd")
const ProgressService = preload("res://scripts/services/progress_service.gd")

signal level_started(level_id: String, level_index: int)
signal level_finished(level_id: String, stats: Dictionary)
signal all_levels_completed()

@export var level_scenes: Array[PackedScene] = []
var current_level_index: int = 0
var current_level_node: PlatformerLevel = null

func _ready() -> void:
	if level_scenes.size() > 0 and current_level_node == null:
		load_level(0)

func load_level(index: int) -> bool:
	if index < 0 or index >= level_scenes.size():
		return false

	if is_instance_valid(current_level_node):
		current_level_node.queue_free()
		current_level_node = null

	current_level_index = index
	var scene: PackedScene = level_scenes[index]
	if scene == null:
		return false

	var instance = scene.instantiate()
	if not (instance is PlatformerLevel):
		instance.queue_free()
		return false

	current_level_node = instance as PlatformerLevel
	add_child(current_level_node)
	current_level_node.level_completed.connect(_on_level_completed)

	level_started.emit(current_level_node.level_id, current_level_index)
	return true

func _on_level_completed(level_id: String, stats: Dictionary) -> void:
	# Persist progression into ProgressService
	ProgressService.record_level_completion(level_id, stats.get("shards_collected", 1))

	level_finished.emit(level_id, stats)

func advance_to_next_level() -> bool:
	var next_idx: int = current_level_index + 1
	if next_idx < level_scenes.size():
		return load_level(next_idx)
	else:
		all_levels_completed.emit()
		return false
