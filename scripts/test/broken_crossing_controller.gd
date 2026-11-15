class_name BrokenCrossingController extends Node2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")
const ExitPortal = preload("res://scripts/platformer/exit_portal.gd")

@export var player: PlayerPlatformer = null
@export var tile_manager: PlatformTileManager = null
@export var exit_portal: ExitPortal = null

var is_completed: bool = false
var start_snapshot_blocks: Array = []

func _ready() -> void:
	if exit_portal:
		exit_portal.level_completed.connect(_on_level_completed)
	
	# Register the initial stealable block at Vector2i(7, 9)
	var stealable_block: StaticBody2D = get_node_or_null("TileManager/WallBlock") as StaticBody2D
	if stealable_block and tile_manager:
		tile_manager.register_existing_block(Vector2i(7, 9), stealable_block, 1) # Cyan block
		tile_manager.capture_initial_snapshot()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()

func _on_level_completed() -> void:
	is_completed = true
	print(">>> [BROKEN CROSSING] LEVEL COMPLETED! <<<")

func restart_level() -> void:
	is_completed = false
	if exit_portal:
		exit_portal.is_completed = false
	if player:
		player.carried_block = null
		player.velocity = Vector2.ZERO
		player.global_position = player.spawn_position
	if tile_manager:
		tile_manager.reset_to_snapshot()
	print(">>> [BROKEN CROSSING] LEVEL RESTARTED TO INITIAL STATE <<<")
