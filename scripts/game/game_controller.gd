class_name GameController extends Node

const HintService = preload("res://scripts/services/hint_service.gd")

## Orchestrates user input, BoardModel updates, BoardRenderer visuals, and AudioService feedback.

signal turn_updated(turns: int)
signal level_completed(turns: int)
signal hint_triggered(text: String)
signal menu_requested
signal state_updated(state: BoardState)
signal invalid_action_occurred(action: int, reason: StringName)

const BUFFER_WINDOW: float = 0.12 # 120ms input buffering window

@export var tile_size: int = 16
@export var reduced_motion: bool = false:
	set(val):
		reduced_motion = val
		if renderer:
			renderer.reduced_motion = val

var model: BoardModel
var renderer: BoardRenderer
var audio: AudioService
var current_level_dict: Dictionary = {}

var is_animating: bool = false
var _input_buffer: int = -1
var _buffer_timestamp: float = 0.0

func _init() -> void:
	_ensure_subsystems()

func _ready() -> void:
	_ensure_subsystems()

func _ensure_subsystems() -> void:
	if renderer == null:
		renderer = BoardRenderer.new()
		renderer.name = "BoardRenderer"
		renderer.tile_size = tile_size
		renderer.reduced_motion = reduced_motion
		renderer.player_move_completed.connect(_on_player_move_completed)
		renderer.portal_unlocked.connect(_on_portal_unlocked)
		add_child(renderer)
	
	if audio == null:
		audio = AudioService.new()
		audio.name = "AudioService"
		add_child(audio)

func _on_portal_unlocked() -> void:
	if audio:
		audio.play_exit_open()

func load_level_data(dict: Dictionary) -> void:
	_ensure_subsystems()
	current_level_dict = dict
	var initial_state := LevelData.from_dict(dict)
	
	_input_buffer = -1
	is_animating = false
	
	if model != null:
		if model.turn_advanced.is_connected(_on_turn_advanced):
			model.turn_advanced.disconnect(_on_turn_advanced)
		if model.state_changed.is_connected(_on_model_state_changed):
			model.state_changed.disconnect(_on_model_state_changed)
		if model.level_completed.is_connected(_on_model_level_completed):
			model.level_completed.disconnect(_on_model_level_completed)
		
	model = BoardModel.new(initial_state)
	model.turn_advanced.connect(_on_turn_advanced)
	model.state_changed.connect(_on_model_state_changed)
	model.level_completed.connect(_on_model_level_completed)
	
	var lvl_id: String = dict.get("id", "")
	var ch_num: int = 0
	if lvl_id.begins_with("ch"):
		ch_num = int(lvl_id.substr(2, 1))
	if renderer:
		renderer.apply_chapter_theme(ch_num)
		renderer.setup_board(initial_state)
	turn_updated.emit(initial_state.turn_count)
	state_updated.emit(initial_state)

func _unhandled_input(event: InputEvent) -> void:
	if model == null or model.is_completed():
		return
		
	var state: BoardState = model.get_state()
	var action: int = -1
	
	var is_shift: bool = Input.is_key_pressed(KEY_SHIFT)
	if event is InputEventWithModifiers and (event as InputEventWithModifiers).shift_pressed:
		is_shift = true

	# Undo / Restart / Hint / Pause
	if event.is_action_pressed(&"undo") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_Z or event.physical_keycode == KEY_Z)):
		handle_undo()
		return
	elif event.is_action_pressed(&"restart") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_R or event.physical_keycode == KEY_R)):
		handle_restart()
		return
	elif event.is_action_pressed(&"hint") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_H or event.physical_keycode == KEY_H)):
		handle_hint()
		return
	elif event.is_action_pressed(&"pause") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)):
		menu_requested.emit()
		return

	# Movement and Shift + Direction
	if event.is_action_pressed(&"move_up") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_W or event.keycode == KEY_UP or event.physical_keycode == KEY_W or event.physical_keycode == KEY_UP)):
		action = Constants.ActionType.INTERACT_NORTH if is_shift else Constants.ActionType.MOVE_NORTH
	elif event.is_action_pressed(&"move_right") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_D or event.keycode == KEY_RIGHT or event.physical_keycode == KEY_D or event.physical_keycode == KEY_RIGHT)):
		action = Constants.ActionType.INTERACT_EAST if is_shift else Constants.ActionType.MOVE_EAST
	elif event.is_action_pressed(&"move_down") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_S or event.keycode == KEY_DOWN or event.physical_keycode == KEY_S or event.physical_keycode == KEY_DOWN)):
		action = Constants.ActionType.INTERACT_SOUTH if is_shift else Constants.ActionType.MOVE_SOUTH
	elif event.is_action_pressed(&"move_left") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_A or event.keycode == KEY_LEFT or event.physical_keycode == KEY_A or event.physical_keycode == KEY_LEFT)):
		action = Constants.ActionType.INTERACT_WEST if is_shift else Constants.ActionType.MOVE_WEST
	elif event.is_action_pressed(&"interact") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.physical_keycode == KEY_E or event.physical_keycode == KEY_SPACE)):
		# Interact in current player_facing direction
		match state.player_facing:
			Constants.DIR_NORTH:
				action = Constants.ActionType.INTERACT_NORTH
			Constants.DIR_EAST:
				action = Constants.ActionType.INTERACT_EAST
			Constants.DIR_SOUTH:
				action = Constants.ActionType.INTERACT_SOUTH
			Constants.DIR_WEST:
				action = Constants.ActionType.INTERACT_WEST
			_:
				action = Constants.ActionType.INTERACT_SOUTH
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if renderer != null:
				var local_mouse_pos: Vector2 = renderer.get_local_mouse_position()
				var cell_x: int = int(floor(local_mouse_pos.x / float(tile_size)))
				var cell_y: int = int(floor(local_mouse_pos.y / float(tile_size)))
				var clicked_cell := Vector2i(cell_x, cell_y)
				var diff: Vector2i = clicked_cell - state.player_pos
				var manhattan: int = abs(diff.x) + abs(diff.y)
				if manhattan == 1:
					if diff == Constants.DIR_NORTH:
						action = Constants.ActionType.INTERACT_NORTH
					elif diff == Constants.DIR_EAST:
						action = Constants.ActionType.INTERACT_EAST
					elif diff == Constants.DIR_SOUTH:
						action = Constants.ActionType.INTERACT_SOUTH
					elif diff == Constants.DIR_WEST:
						action = Constants.ActionType.INTERACT_WEST
		
	if action != -1:
		request_action(action)

func request_action(action: int) -> void:
	if is_animating:
		_input_buffer = action
		_buffer_timestamp = Time.get_ticks_msec() / 1000.0
		return
	_execute_action(action)

func _execute_action(action: int) -> void:
	if model == null or model.is_completed():
		return
		
	var facing: Vector2i = Constants.action_to_direction(action)
	var res: Dictionary = model.try_action(action)
	
	if res["success"]:
		state_updated.emit(model.get_state())
	else:
		# Invalid action feedback
		if facing != Vector2i.ZERO and renderer:
			renderer.animate_invalid_bump(facing)
		if audio:
			audio.play_bump()
		invalid_action_occurred.emit(action, res.get("rejection_reason", &"unknown"))

func _on_player_move_completed() -> void:
	is_animating = false
	if _input_buffer != -1:
		var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _buffer_timestamp
		var next_action: int = _input_buffer
		_input_buffer = -1
		if elapsed <= BUFFER_WINDOW:
			_execute_action(next_action)

func _on_turn_advanced(turns: int) -> void:
	turn_updated.emit(turns)

func _on_model_state_changed(event: StringName, _message: String) -> void:
	var state: BoardState = model.get_state()
	
	match event:
		&"player_moved":
			is_animating = not (renderer and renderer.reduced_motion)
			if audio:
				audio.play_step()
			if renderer:
				renderer.animate_player_move(state.player_pos, state.player_facing)
		&"block_stolen", &"bridge_stolen":
			if audio:
				audio.play_steal()
			if renderer:
				renderer.update_view(state, false)
		&"block_placed", &"bridge_created":
			if audio:
				audio.play_place()
			if renderer:
				renderer.update_view(state, false)
		&"socket_activated":
			if audio:
				audio.play_socket()
			if renderer:
				renderer.update_view(state, false)
		&"undo_applied", &"restart_applied":
			if audio:
				audio.play_undo()
			if renderer:
				renderer.update_view(state, true)
		&"level_cleared":
			if audio:
				audio.play_win()
			if renderer:
				renderer.update_view(state, false)
			
	state_updated.emit(state)

func _on_model_level_completed(turns: int) -> void:
	if renderer:
		renderer.animate_victory()
	level_completed.emit(turns)

func handle_undo() -> void:
	_input_buffer = -1
	is_animating = false
	if renderer:
		renderer.kill_all_tweens()
	if model != null and model.can_undo():
		model.undo()
		if renderer and model:
			var s: BoardState = model.get_state()
			renderer.snap_player(s.player_pos, s.player_facing)
			state_updated.emit(s)

func handle_restart() -> void:
	_input_buffer = -1
	is_animating = false
	if renderer:
		renderer.kill_all_tweens()
	if model != null:
		model.restart()
		if renderer and model:
			var s: BoardState = model.get_state()
			renderer.snap_player(s.player_pos, s.player_facing)
			state_updated.emit(s)

func handle_hint() -> void:
	if current_level_dict.is_empty():
		return
	var hint_text: String = ""
	if model != null:
		var hint_info: Dictionary = HintService.generate_hint(model.get_state())
		hint_text = hint_info.get("hint_text", "")
	if hint_text.is_empty():
		hint_text = current_level_dict.get("hint", "Power all sockets and exit.")
	hint_triggered.emit(hint_text)
