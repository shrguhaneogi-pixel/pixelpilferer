class_name BoardModel extends RefCounted

## Owns authoritative logical state and valid actions for a puzzle board.

signal state_changed(event: StringName, message: String)
signal turn_advanced(turns: int)
signal level_completed(turns: int)

var _state: BoardState
var _history: HistoryManager

func _init(initial_state: BoardState = null) -> void:
	_history = HistoryManager.new()
	if initial_state != null:
		initialize(initial_state)

func initialize(initial_state: BoardState) -> void:
	_state = initial_state.duplicate_state()
	_history.initialize(_state)
	turn_advanced.emit(_state.turn_count)

func get_state() -> BoardState:
	return _state

func is_completed() -> bool:
	return _state != null and _state.is_completed

func try_action(action: int) -> Dictionary:
	if _state == null:
		return { "success": false, "event": &"uninitialized", "message": "Model not initialized." }
		
	var res: Dictionary = GameRules.apply_action(_state, action)
	_state = res["next_state"]
	
	if res["success"]:
		_history.record_state(_state)
		turn_advanced.emit(_state.turn_count)
		state_changed.emit(res["event"], res["message"])
		
		if _state.is_completed:
			level_completed.emit(_state.turn_count)
	else:
		state_changed.emit(res["event"], res["message"])
		
	return res

func can_undo() -> bool:
	return _history != null and _history.can_undo()

func undo() -> bool:
	if not can_undo():
		return false
	_state = _history.undo()
	turn_advanced.emit(_state.turn_count)
	state_changed.emit(&"undo_applied", "Turn undone.")
	return true

func restart() -> void:
	if _history == null:
		return
	_state = _history.restart()
	turn_advanced.emit(_state.turn_count)
	state_changed.emit(&"restart_applied", "Level restarted.")
