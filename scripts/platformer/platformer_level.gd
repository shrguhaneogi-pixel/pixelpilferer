class_name PlatformerLevel extends Node2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")
const ExitPortal = preload("res://scripts/platformer/exit_portal.gd")
const PlatformerCamera = preload("res://scripts/platformer/platformer_camera.gd")
const Checkpoint = preload("res://scripts/platformer/checkpoint.gd")
const HazardZone = preload("res://scripts/platformer/hazard_zone.gd")
const CollectibleShard = preload("res://scripts/platformer/collectible_shard.gd")
const ChromaticSocket = preload("res://scripts/platformer/chromatic_socket.gd")
const LockedDoor = preload("res://scripts/platformer/locked_door.gd")

## Signals
signal level_completed(level_id: String, stats: Dictionary)
signal level_reset()
signal checkpoint_reached(checkpoint: Checkpoint)
signal player_died()
signal shard_collected(shard_id: String, total_count: int)

## Level Metadata
@export var level_id: String = "w1_01"
@export var level_name: String = "The Stolen Ledge"
@export var world_id: int = 1
@export var required_sockets_count: int = 0

## Core Node References
@export var player: PlayerPlatformer = null
@export var tile_manager: PlatformTileManager = null
@export var exit_portal: ExitPortal = null
@export var camera: PlatformerCamera = null

## Collections
var checkpoints: Array[Checkpoint] = []
var hazards: Array[HazardZone] = []
var collectibles: Array[CollectibleShard] = []
var sockets: Array[ChromaticSocket] = []
var doors: Array[LockedDoor] = []

## Runtime State
var active_checkpoint: Checkpoint = null
var initial_snapshot: Dictionary = {}
var checkpoint_snapshot: Dictionary = {}
var collected_shards: Array[String] = []
var is_completed: bool = false

func _ready() -> void:
	discover_nodes()
	setup_connections()
	capture_initial_state()
	update_sockets_and_doors()

func discover_nodes() -> void:
	if player == null:
		player = get_node_or_null("Player") as PlayerPlatformer
	if tile_manager == null:
		tile_manager = get_node_or_null("TileManager") as PlatformTileManager
	if exit_portal == null:
		exit_portal = get_node_or_null("ExitPortal") as ExitPortal
	if camera == null:
		camera = get_node_or_null("Camera2D") as PlatformerCamera

	# Collect all component children recursively
	checkpoints.clear()
	hazards.clear()
	collectibles.clear()
	sockets.clear()
	doors.clear()

	_find_typed_nodes(self)

func _find_typed_nodes(node: Node) -> void:
	for child in node.get_children():
		if child is Checkpoint:
			checkpoints.append(child)
		elif child is HazardZone:
			hazards.append(child)
		elif child is CollectibleShard:
			collectibles.append(child)
		elif child is ChromaticSocket:
			sockets.append(child)
		elif child is LockedDoor:
			doors.append(child)
		_find_typed_nodes(child)

func setup_connections() -> void:
	if player:
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		if not player.block_stolen.is_connected(_on_block_changed):
			player.block_stolen.connect(_on_block_changed)
		if not player.block_placed.is_connected(_on_block_placed_event):
			player.block_placed.connect(_on_block_placed_event)

	if exit_portal:
		if not exit_portal.level_completed.is_connected(_on_exit_reached):
			exit_portal.level_completed.connect(_on_exit_reached)

	for cp in checkpoints:
		if not cp.checkpoint_activated.is_connected(_on_checkpoint_activated):
			cp.checkpoint_activated.connect(_on_checkpoint_activated)

	for hz in hazards:
		if not hz.player_entered.is_connected(_on_hazard_entered):
			hz.player_entered.connect(_on_hazard_entered)

	for cs in collectibles:
		if not cs.collected.is_connected(_on_shard_collected):
			cs.collected.connect(_on_shard_collected)

	for sk in sockets:
		if not sk.satisfaction_changed.is_connected(_on_socket_satisfaction_changed):
			sk.satisfaction_changed.connect(_on_socket_satisfaction_changed)

func capture_initial_state() -> void:
	var player_pos: Vector2 = player.global_position if player else Vector2.ZERO
	var blocks_data: Array = tile_manager.capture_snapshot() if tile_manager else []

	initial_snapshot = {
		"player_pos": player_pos,
		"carried_block": null,
		"blocks": blocks_data,
		"shards": [],
		"sockets": []
	}
	checkpoint_snapshot = initial_snapshot.duplicate(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart_level()

func _on_checkpoint_activated(cp: Checkpoint) -> void:
	if active_checkpoint == cp:
		return
	active_checkpoint = cp

	if player:
		player.set_respawn_position(cp.global_position)

	var satisfied_socket_ids: Array = []
	for sk in sockets:
		if sk.is_satisfied:
			satisfied_socket_ids.append(sk.socket_id)

	checkpoint_snapshot = {
		"player_pos": cp.global_position,
		"carried_block": player.carried_block if player else null,
		"blocks": tile_manager.capture_snapshot() if tile_manager else [],
		"shards": collected_shards.duplicate(),
		"sockets": satisfied_socket_ids
	}
	checkpoint_reached.emit(cp)

func _on_hazard_entered(_hazard: HazardZone) -> void:
	restore_from_checkpoint()

func _on_player_died() -> void:
	restore_from_checkpoint()

func restore_from_checkpoint() -> void:
	if player:
		player.velocity = Vector2.ZERO
		player.global_position = checkpoint_snapshot.get("player_pos", player.spawn_position)
		player.carried_block = checkpoint_snapshot.get("carried_block", null)

	if tile_manager:
		tile_manager.restore_snapshot(checkpoint_snapshot.get("blocks", []))

	var checkpoint_shards: Array = checkpoint_snapshot.get("shards", [])
	for cs in collectibles:
		if not cs.shard_id in checkpoint_shards:
			cs.reset()
			collected_shards.erase(cs.shard_id)

	update_sockets_and_doors()
	player_died.emit()

func restart_level() -> void:
	is_completed = false
	if exit_portal:
		exit_portal.is_completed = false

	active_checkpoint = null
	for cp in checkpoints:
		cp.reset()

	if player:
		player.velocity = Vector2.ZERO
		player.global_position = initial_snapshot.get("player_pos", player.spawn_position)
		player.set_respawn_position(initial_snapshot.get("player_pos", player.spawn_position))
		player.carried_block = null

	if tile_manager:
		tile_manager.restore_snapshot(initial_snapshot.get("blocks", []))

	collected_shards.clear()
	for cs in collectibles:
		cs.reset()

	for door in doors:
		door.reset()

	checkpoint_snapshot = initial_snapshot.duplicate(true)
	update_sockets_and_doors()
	level_reset.emit()

func _on_shard_collected(shard: CollectibleShard) -> void:
	if not shard.shard_id in collected_shards:
		collected_shards.append(shard.shard_id)
		shard_collected.emit(shard.shard_id, collected_shards.size())

func _on_block_placed_event(_color: int, _cell: Vector2i) -> void:
	update_sockets_and_doors()

func _on_block_changed(_color: int = 0) -> void:
	update_sockets_and_doors()

func _on_socket_satisfaction_changed(_is_satisfied: bool) -> void:
	update_sockets_and_doors()

func update_sockets_and_doors() -> void:
	var satisfied_count: int = 0
	for sk in sockets:
		if tile_manager:
			sk.check_satisfaction(tile_manager)
		if sk.is_satisfied:
			satisfied_count += 1

	for door in doors:
		var should_open: bool = false
		for sk in sockets:
			if sk.socket_id == door.socket_id and sk.is_satisfied:
				should_open = true
				break
		door.set_open(should_open)

	if exit_portal:
		if required_sockets_count > 0:
			exit_portal.is_locked = (satisfied_count < required_sockets_count)
		else:
			exit_portal.is_locked = false

func _on_exit_reached() -> void:
	if is_completed:
		return
	is_completed = true
	var stats = {
		"level_id": level_id,
		"level_name": level_name,
		"world_id": world_id,
		"shards_collected": collected_shards.size(),
		"total_shards": collectibles.size()
	}
	level_completed.emit(level_id, stats)
