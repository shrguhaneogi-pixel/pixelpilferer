class_name HistoryManager extends RefCounted

var _undo_stack: Array[BoardState] = []
var _initial_state: BoardState = null

func initialize(initial_state: BoardState) -> void:
	_undo_stack.clear()
	_initial_state = initial_state.duplicate_state()
	_undo_stack.append(_initial_state.duplicate_state())

func record_state(state: BoardState) -> void:
	_undo_stack.append(state.duplicate_state())

func can_undo() -> bool:
	return _undo_stack.size() > 1

func undo() -> BoardState:
	if not can_undo():
		return get_current_state()
	# Pop current state
	_undo_stack.pop_back()
	# Return restored previous state
	return _undo_stack.back().duplicate_state()

func restart() -> BoardState:
	if _initial_state == null:
		return null
	_undo_stack.clear()
	_undo_stack.append(_initial_state.duplicate_state())
	return _initial_state.duplicate_state()

func get_current_state() -> BoardState:
	if _undo_stack.is_empty():
		return null
	return _undo_stack.back()

func get_move_count() -> int:
	if _undo_stack.is_empty():
		return 0
	return _undo_stack.size() - 1
