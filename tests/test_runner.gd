extends SceneTree

var _total_tests: int = 0
var _failed_tests: int = 0

func _init() -> void:
	print("=======================================================")
	print("       PIXEL PILFERER GODOT HEADLESS TEST RUNNER       ")
	print("=======================================================\n")
	
	_run_domain_tests()
	_run_solver_tests()
	
	print("\n-------------------------------------------")
	print("Total tests executed: %d | Failed: %d" % [_total_tests, _failed_tests])
	
	if _failed_tests > 0:
		printerr("FAILED: Test suite finished with errors.")
		quit(1)
	else:
		print("SUCCESS: All tests passed cleanly!")
		quit(0)

func _assert_true(condition: bool, test_name: String) -> void:
	_total_tests += 1
	if not condition:
		_failed_tests += 1
		printerr("  [FAIL] " + test_name)
	else:
		print("  [PASS] " + test_name)

func _assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	_total_tests += 1
	if actual != expected:
		_failed_tests += 1
		printerr("  [FAIL] %s (Expected: %s, Got: %s)" % [test_name, str(expected), str(actual)])
	else:
		print("  [PASS] " + test_name)

func _run_domain_tests() -> void:
	print("=== Running GDScript Domain Invariant Tests ===")
	
	var s := BoardState.new()
	s.grid_size = Vector2i(5, 5)
	for x in 5:
		for y in 5:
			s.tiles[Vector2i(x, y)] = Constants.TileType.FLOOR
	s.player_pos = Vector2i(1, 1)
	
	# 1. Floor movement
	var res1: Dictionary = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(res1["success"], "Move East on empty floor succeeds")
	_assert_eq(res1["next_state"].player_pos, Vector2i(2, 1), "Player position is (2,1)")
	
	# 2. Wall collision
	var s1: BoardState = res1["next_state"]
	s1.tiles[Vector2i(3, 1)] = Constants.TileType.WALL
	var res2: Dictionary = GameRules.apply_action(s1, Constants.ActionType.MOVE_EAST)
	_assert_true(not res2["success"], "Cannot move into immutable wall")
	_assert_eq(res2["event"], &"blocked_wall", "Event is blocked_wall")
	
	# 3. Block on floor collision (obstacle)
	s1.blocks[Vector2i(2, 2)] = { "id": 1, "color": Constants.BlockColor.NEUTRAL, "is_bridge": false }
	var res3: Dictionary = GameRules.apply_action(s1, Constants.ActionType.MOVE_SOUTH)
	_assert_true(not res3["success"], "Cannot move into block on floor")
	
	# 4. Stealing block
	var res_steal: Dictionary = GameRules.apply_action(s1, Constants.ActionType.INTERACT_SOUTH)
	_assert_true(res_steal["success"], "Steal block south succeeds")
	_assert_true(res_steal["next_state"].is_carrying(), "Player carries stolen block")
	
	# 5. Placing block on void creates bridge
	var s_steal: BoardState = res_steal["next_state"]
	s_steal.tiles[Vector2i(2, 0)] = Constants.TileType.VOID
	var res_bridge: Dictionary = GameRules.apply_action(s_steal, Constants.ActionType.INTERACT_NORTH)
	_assert_true(res_bridge["success"], "Place block on void succeeds")
	_assert_eq(res_bridge["event"], &"bridge_created", "Event is bridge_created")
	_assert_true(res_bridge["next_state"].is_bridge_at(Vector2i(2, 0)), "Cell (2,0) is bridge")
	
	# 6. Sockets and exit condition
	var s_sock := BoardState.new()
	s_sock.grid_size = Vector2i(4, 4)
	for x in 4:
		for y in 4:
			s_sock.tiles[Vector2i(x, y)] = Constants.TileType.FLOOR
	s_sock.player_pos = Vector2i(1, 1)
	s_sock.exit_cell = Vector2i(3, 1)
	s_sock.sockets[Vector2i(1, 2)] = Constants.BlockColor.CYAN
	s_sock.carried_block = { "id": 99, "color": Constants.BlockColor.CYAN }
	
	var res_place: Dictionary = GameRules.apply_action(s_sock, Constants.ActionType.INTERACT_SOUTH)
	_assert_true(res_place["success"], "Place Cyan block on Cyan socket succeeds")
	_assert_eq(res_place["event"], &"socket_activated", "Cyan socket activated")
	_assert_true(res_place["next_state"].is_all_sockets_satisfied(), "All sockets satisfied")
	
	var res_step1: Dictionary = GameRules.apply_action(res_place["next_state"], Constants.ActionType.MOVE_EAST)
	var res_win: Dictionary = GameRules.apply_action(res_step1["next_state"], Constants.ActionType.MOVE_EAST)
	_assert_true(res_win["success"], "Reached exit portal")
	_assert_true(res_win["next_state"].is_completed, "Level completed!")
	_assert_eq(res_win["event"], &"level_cleared", "Event is level_cleared")
	
	# 7. Undo / Restart integrity
	var hist := HistoryManager.new()
	hist.initialize(s)
	hist.record_state(res1["next_state"])
	_assert_eq(hist.get_current_state().player_pos, Vector2i(2, 1), "History current is (2,1)")
	var restored := hist.undo()
	_assert_eq(restored.player_pos, Vector2i(1, 1), "Undo restored (1,1)")

func _run_solver_tests() -> void:
	print("\n=== Running GDScript Puzzle Solver Verification ===")
	var s := BoardState.new()
	s.grid_size = Vector2i(7, 5)
	for x in 7:
		for y in 5:
			s.tiles[Vector2i(x, y)] = Constants.TileType.WALL
	for x in range(1, 6):
		for y in range(1, 4):
			s.tiles[Vector2i(x, y)] = Constants.TileType.FLOOR
	s.player_pos = Vector2i(1, 2)
	s.exit_cell = Vector2i(5, 2)
	s.sockets[Vector2i(3, 2)] = Constants.BlockColor.NEUTRAL
	s.blocks[Vector2i(3, 1)] = { "id": 1, "color": Constants.BlockColor.NEUTRAL, "is_bridge": false }
	
	var res: Dictionary = PuzzleSolver.solve(s)
	_assert_true(res["solved"], "Level 1-1 solved by GDScript PuzzleSolver")
	_assert_true(res["steps"] > 0, "Solution steps > 0 (%d steps)" % res["steps"])
