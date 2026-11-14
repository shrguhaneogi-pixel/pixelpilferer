class_name GameController extends Node2D

## Orchestrates user input, BoardModel updates, BoardRenderer visuals, and AudioService feedback.

signal turn_updated(turns: int)
signal level_completed(turns: int)
signal hint_triggered(text: String)
signal menu_requested

@export var tile_size: int = 16
@export var reduced_motion: bool = false

var model: BoardModel
var renderer: BoardRenderer
var audio: AudioService
var current_level_dict: Dictionary = {}

func _ready() -> void:
	renderer = BoardRenderer.new()
	renderer.name = "BoardRenderer"
	renderer.tile_size = tile_size
	renderer.reduced_motion = reduced_motion
	add_child(renderer)
	
	audio = AudioService.new()
	audio.name = "AudioService"
	add_child(audio)

func load_level_data(dict: Dictionary) -> void:
	current_level_dict = dict
	var initial_state := LevelData.from_dict(dict)
	
	if model != null:
		model.turn_advanced.disconnect(_on_turn_advanced)
		model.state_changed.disconnect(_on_model_state_changed)
		model.level_completed.disconnect(_on_model_level_completed)
		
	model = BoardModel.new(initial_state)
	model.turn_advanced.connect(_on_turn_advanced)
	model.state_changed.connect(_on_model_state_changed)
	model.level_completed.connect(_on_model_level_completed)
	
	renderer.setup_board(initial_state)
	turn_updated.emit(initial_state.turn_count)

func _unhandled_input(event: InputEvent) -> void:
	if model == null or model.is_completed():
		return
		
	var state: BoardState = model.get_state()
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
		if state.player_facing == Constants.DIR_NORTH:
			action = Constants.ActionType.INTERACT_NORTH
		elif state.player_facing == Constants.DIR_EAST:
			action = Constants.ActionType.INTERACT_EAST
		elif state.player_facing == Constants.DIR_SOUTH:
			action = Constants.ActionType.INTERACT_SOUTH
		elif state.player_facing == Constants.DIR_WEST:
			action = Constants.ActionType.INTERACT_WEST
	elif event.is_action_pressed(&"undo"):
		handle_undo()
		return
	elif event.is_action_pressed(&"restart"):
		handle_restart()
		return
	elif event.is_action_pressed(&"hint"):
		handle_hint()
		return
	elif event.is_action_pressed(&"pause"):
		menu_requested.emit()
		return
		
	if action != -1:
		model.try_action(action)

func _on_turn_advanced(turns: int) -> void:
	turn_updated.emit(turns)

func _on_model_state_changed(event: StringName, _message: String) -> void:
	var state: BoardState = model.get_state()
	
	match event:
		&"player_moved":
			audio.play_step()
			renderer.animate_player_move(state.player_pos, state.player_facing)
		&"block_stolen", &"bridge_stolen":
			audio.play_steal()
			renderer.update_view(state, false)
		&"block_placed", &"bridge_created":
			audio.play_place()
			renderer.update_view(state, false)
		&"socket_activated":
			audio.play_socket()
			renderer.update_view(state, false)
		&"undo_applied", &"restart_applied":
			audio.play_undo()
			renderer.update_view(state, true)
		&"level_cleared":
			audio.play_win()
			renderer.update_view(state, false)

func _on_model_level_completed(turns: int) -> void:
	level_completed.emit(turns)

func handle_undo() -> void:
	if model != null and model.can_undo():
		model.undo()

func handle_restart() -> void:
	if model != null:
		model.restart()

func handle_hint() -> void:
	if current_level_dict.is_empty():
		return
	var hint_text: String = current_level_dict.get("hint", "Power all sockets and exit.")
	if model != null:
		var sol: Dictionary = PuzzleSolver.solve(model.get_state(), 10000)
		if sol["solved"] and sol["actions"].size() > 0:
			var next_act: int = sol["actions"][0]
			hint_text += " (Suggested next move: %s)" % Constants.action_name(next_act)
	hint_triggered.emit(hint_text)
