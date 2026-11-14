class_name LevelView extends Node2D

signal level_completed
signal turn_changed(turn: int)
signal hint_requested(hint_text: String)

@export var tile_size: int = 16
@export var reduced_motion: bool = false

var current_state: BoardState
var history: HistoryManager
var level_dict: Dictionary = {}

# Node references
var camera: PixelCamera
var player_view: PlayerView
var audio_mgr: AudioManager
var exit_sprite: Sprite2D
var block_views: Dictionary = {} # Vector2i -> BlockView

# Dedicated TileMapLayers (Godot 4.7 standard)
var floor_layer: TileMapLayer
var void_layer: TileMapLayer
var socket_layer: TileMapLayer
var wall_layer: TileMapLayer
var entity_container: Node2D

var _is_animating: bool = false
var _input_buffer: int = -1
var _buffer_timer: float = 0.0
const BUFFER_WINDOW: float = 0.12

func _ready() -> void:
	_setup_scene_structure()

func _setup_scene_structure() -> void:
	# 1. TileMapLayers
	void_layer = TileMapLayer.new()
	void_layer.name = "VoidLayer"
	void_layer.z_index = -3
	add_child(void_layer)
	
	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.z_index = -2
	add_child(floor_layer)
	
	socket_layer = TileMapLayer.new()
	socket_layer.name = "SocketLayer"
	socket_layer.z_index = -1
	add_child(socket_layer)
	
	wall_layer = TileMapLayer.new()
	wall_layer.name = "WallLayer"
	wall_layer.z_index = 3
	add_child(wall_layer)
	
	# 2. Entity Container (Y-Sorted)
	entity_container = Node2D.new()
	entity_container.name = "EntityContainer"
	entity_container.y_sort_enabled = true
	add_child(entity_container)
	
	# 3. Exit Portal
	exit_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/exit_portal.png"):
		exit_sprite.texture = load("res://assets/sprites/exit_portal.png")
	exit_sprite.hframes = 2
	exit_sprite.frame = 0
	exit_sprite.centered = true
	exit_sprite.z_index = 0
	entity_container.add_child(exit_sprite)
	
	# 4. Player View
	player_view = PlayerView.new()
	player_view.name = "PlayerView"
	player_view.z_index = 2
	entity_container.add_child(player_view)
	
	# 5. Audio Manager
	audio_mgr = AudioManager.new()
	audio_mgr.name = "AudioManager"
	add_child(audio_mgr)
	
	# 6. Pixel Camera
	camera = PixelCamera.new()
	camera.name = "PixelCamera"
	camera.target = player_view
	add_child(camera)
	camera.make_current()

func load_level(dict: Dictionary) -> void:
	level_dict = dict
	current_state = LevelData.from_dict(dict)
	history = HistoryManager.new()
	history.initialize(current_state)
	
	_render_grid_terrain()
	_resync_views_from_state(true)
	turn_changed.emit(current_state.turn_count)

func _render_grid_terrain() -> void:
	# Clear existing tiles and blocks
	void_layer.clear()
	floor_layer.clear()
	socket_layer.clear()
	wall_layer.clear()
	
	# Position exit portal
	if current_state.exit_cell != Vector2i(-1, -1):
		exit_sprite.position = Vector2(current_state.exit_cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)
		exit_sprite.visible = true
	else:
		exit_sprite.visible = false

func _resync_views_from_state(snap: bool = false) -> void:
	# Clear existing block views
	for pos: Vector2i in block_views:
		var bv: BlockView = block_views[pos]
		if is_instance_valid(bv):
			bv.queue_free()
	block_views.clear()
	
	# Spawn block views for all blocks in state
	for pos: Vector2i in current_state.blocks:
		var b_data: Dictionary = current_state.blocks[pos]
		var bv := BlockView.new()
		bv.reduced_motion = reduced_motion
		entity_container.add_child(bv)
		bv.setup(b_data["id"], b_data["color"], b_data["is_bridge"], pos)
		block_views[pos] = bv
		
	# Resync player
	if snap:
		player_view.snap_to_cell(current_state.player_pos, current_state.player_facing)
		camera.snap_to_target()
	else:
		player_view.animate_move(current_state.player_pos, current_state.player_facing)
		
	player_view.update_carried_visual(current_state.carried_block)
	
	# Update exit portal frame
	if current_state.is_all_sockets_satisfied():
		exit_sprite.frame = 1 # Open vortex
	else:
		exit_sprite.frame = 0 # Locked arch

func _process(delta: float) -> void:
	if _buffer_timer > 0.0:
		_buffer_timer -= delta
		if _buffer_timer <= 0.0:
			_input_buffer = -1

func _unhandled_input(event: InputEvent) -> void:
	if current_state == null or current_state.is_completed:
		return
		
	var action: int = -1
	
	if event.is_action_pressed(&"move_up"):
		action = Constants.ActionType.MOVE_NORTH
	elif event.is_action_pressed(&"move_right"):
		action = Constants.ActionType.MOVE_EAST
	elif event.is_action_pressed(&"move_down"):
		action = Constants.ActionType.MOVE_SOUTH
	elif event.is_action_pressed(&"move_left"):
		action = Constants.ActionType.MOVE_WEST
	elif event.is_action_pressed(&"interact"):
		# Contextual interaction towards current facing direction
		if current_state.player_facing == Constants.DIR_NORTH:
			action = Constants.ActionType.INTERACT_NORTH
		elif current_state.player_facing == Constants.DIR_EAST:
			action = Constants.ActionType.INTERACT_EAST
		elif current_state.player_facing == Constants.DIR_SOUTH:
			action = Constants.ActionType.INTERACT_SOUTH
		elif current_state.player_facing == Constants.DIR_WEST:
			action = Constants.ActionType.INTERACT_WEST
	elif event.is_action_pressed(&"undo"):
		_handle_undo()
		return
	elif event.is_action_pressed(&"restart"):
		_handle_restart()
		return
	elif event.is_action_pressed(&"hint"):
		_handle_hint()
		return
		
	if action != -1:
		_apply_player_action(action)

func _apply_player_action(action: int) -> void:
	var res: Dictionary = GameRules.apply_action(current_state, action)
	if not res["success"]:
		# Update facing even if blocked
		player_view.set_facing(res["next_state"].player_facing)
		current_state = res["next_state"]
		return
		
	current_state = res["next_state"]
	history.record_state(current_state)
	turn_changed.emit(current_state.turn_count)
	
	var ev: StringName = res["event"]
	
	if ev == &"player_moved":
		audio_mgr.play_step()
		player_view.animate_move(current_state.player_pos, current_state.player_facing)
	elif ev == &"block_stolen" or ev == &"bridge_stolen":
		audio_mgr.play_steal()
		_resync_views_from_state(false)
	elif ev == &"block_placed" or ev == &"bridge_created":
		audio_mgr.play_place()
		_resync_views_from_state(false)
	elif ev == &"socket_activated":
		audio_mgr.play_socket()
		_resync_views_from_state(false)
	elif ev == &"level_cleared":
		audio_mgr.play_win()
		player_view.animate_move(current_state.player_pos, current_state.player_facing)
		exit_sprite.frame = 1
		level_completed.emit()

func _handle_undo() -> void:
	if not history.can_undo():
		return
	audio_mgr.play_undo()
	current_state = history.undo()
	_resync_views_from_state(true)
	turn_changed.emit(current_state.turn_count)

func _handle_restart() -> void:
	audio_mgr.play_undo()
	current_state = history.restart()
	_resync_views_from_state(true)
	turn_changed.emit(current_state.turn_count)

func _handle_hint() -> void:
	var hint_text: String = level_dict.get("hint", "Power every socket and reach the exit.")
	# Optional: Query PuzzleSolver for immediate optimal next action!
	var sol: Dictionary = PuzzleSolver.solve(current_state, 10000)
	if sol["solved"] and sol["actions"].size() > 0:
		var next_act: int = sol["actions"][0]
		hint_text += " (Suggested next move: %s)" % Constants.action_name(next_act)
	hint_requested.emit(hint_text)
