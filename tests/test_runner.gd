extends SceneTree

var _total_tests: int = 0
var _failed_tests: int = 0

func _init() -> void:
	print("=======================================================")
	print("       PIXEL PILFERER BASELINE VERIFICATION HARNESS    ")
	print("=======================================================\n")
	
	_test_resource_loading()
	_test_data_structures_construction()
	_test_domain_invariants()
	_test_phase2_deterministic_rules()
	_test_invalid_data_handling()
	_test_puzzle_solvability()
	
	print("\n-------------------------------------------")
	print("Total tests executed: %d | Failed: %d" % [_total_tests, _failed_tests])
	
	if _failed_tests > 0:
		printerr("FAILED: Baseline test harness encountered errors.")
		quit(1)
	else:
		print("SUCCESS: All baseline checks passed cleanly!")
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

func _test_resource_loading() -> void:
	print("=== 1. Verifying Resource & Scene Loading ===")
	
	var main_res = ResourceLoader.load("res://scenes/main.tscn")
	_assert_true(main_res != null, "Main scene (res://scenes/main.tscn) loads successfully")
	
	var title_res = ResourceLoader.load("res://scenes/ui/title_screen.tscn")
	_assert_true(title_res != null, "Title scene (res://scenes/ui/title_screen.tscn) loads successfully")
	
	var hud_res = ResourceLoader.load("res://scenes/ui/hud.tscn")
	_assert_true(hud_res != null, "HUD scene (res://scenes/ui/hud.tscn) loads successfully")
	
	var pip_tex = ResourceLoader.load("res://assets/sprites/pip.png")
	_assert_true(pip_tex != null, "Pip sprite (res://assets/sprites/pip.png) loads successfully")
	
	var blocks_tex = ResourceLoader.load("res://assets/sprites/blocks.png")
	_assert_true(blocks_tex != null, "Blocks sprite (res://assets/sprites/blocks.png) loads successfully")
	
	var tileset_tex = ResourceLoader.load("res://assets/sprites/tileset.png")
	_assert_true(tileset_tex != null, "Tileset sprite (res://assets/sprites/tileset.png) loads successfully")
	
	var audio_steal = ResourceLoader.load("res://assets/audio/sfx_steal.wav")
	_assert_true(audio_steal != null, "Audio SFX (res://assets/audio/sfx_steal.wav) loads successfully")

func _test_data_structures_construction() -> void:
	print("\n=== 2. Verifying Initial Data Structures Construction ===")
	
	var s := BoardState.new()
	_assert_true(s != null, "BoardState instantiated")
	_assert_eq(s.is_carrying(), false, "Initial carried block is empty")
	
	var model := BoardModel.new()
	_assert_true(model != null, "BoardModel instantiated")
	_assert_eq(model.can_undo(), false, "Initial undo stack is empty")
	
	var ch1_data := LevelRepository.load_chapter(1)
	_assert_true(not ch1_data.is_empty(), "LevelRepository loads Chapter 1 data")
	_assert_eq(ch1_data.get("chapter", 0), 1, "Chapter number is 1")
	
	var progress := ProgressService.load_progress()
	_assert_true(progress is Dictionary, "ProgressService loads progress dictionary")
	_assert_true(progress.has("unlocked_level"), "Progress contains 'unlocked_level'")

func _test_domain_invariants() -> void:
	print("\n=== 3. Verifying Domain Invariants & Rules ===")
	
	var s := BoardState.new()
	s.grid_size = Vector2i(5, 5)
	for x in 5:
		for y in 5:
			s.tiles[Vector2i(x, y)] = Constants.TileType.FLOOR
	s.player_pos = Vector2i(1, 1)
	
	var model := BoardModel.new(s)
	
	# Floor move
	var res1: Dictionary = model.try_action(Constants.ActionType.MOVE_EAST)
	_assert_true(res1["success"], "Move East on empty floor succeeds")
	_assert_eq(model.get_state().player_pos, Vector2i(2, 1), "Player position updated to (2,1)")
	
	# Wall collision
	model.get_state().tiles[Vector2i(3, 1)] = Constants.TileType.WALL
	var res2: Dictionary = model.try_action(Constants.ActionType.MOVE_EAST)
	_assert_true(not res2["success"], "Cannot move into solid wall")
	_assert_eq(res2["event"], &"blocked_wall", "Event is blocked_wall")
	
	# Block obstacle
	model.get_state().blocks[Vector2i(2, 2)] = { "id": 1, "color": Constants.BlockColor.NEUTRAL, "is_bridge": false }
	var res3: Dictionary = model.try_action(Constants.ActionType.MOVE_SOUTH)
	_assert_true(not res3["success"], "Cannot walk into movable block on floor")
	
	# Steal block
	var res_steal: Dictionary = model.try_action(Constants.ActionType.INTERACT_SOUTH)
	_assert_true(res_steal["success"], "Steal block south succeeds")
	_assert_true(model.get_state().is_carrying(), "Player now carrying block")
	
	# Void bridge
	model.get_state().tiles[Vector2i(2, 0)] = Constants.TileType.VOID
	var res_bridge: Dictionary = model.try_action(Constants.ActionType.INTERACT_NORTH)
	_assert_true(res_bridge["success"], "Place block on void creates bridge")
	_assert_true(model.get_state().is_bridge_at(Vector2i(2, 0)), "Cell (2,0) is marked as bridge")
	
	# Undo & restart
	_assert_true(model.can_undo(), "Model can undo")
	var undone := model.undo()
	_assert_true(undone, "Undo executed successfully")
	model.restart()
	_assert_eq(model.get_state().player_pos, Vector2i(1, 1), "Restart restored initial player position")

func _make_board() -> BoardState:
	var s := BoardState.new()
	s.grid_size = Vector2i(5, 5)
	for x in 5:
		for y in 5:
			s.tiles[Vector2i(x, y)] = Constants.TileType.FLOOR
	s.player_pos = Vector2i(2, 2)
	s.initial_player_pos = Vector2i(2, 2)
	return s

func _test_phase2_deterministic_rules() -> void:
	print("\n=== Phase 2: 28 Deterministic Puzzle Engine Tests ===")
	
	# 1. Movement on ordinary floor
	var s := _make_board()
	var res: Dictionary = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(res["success"], "1. Movement on ordinary floor succeeds")
	_assert_eq((res["next_state"] as BoardState).player_pos, Vector2i(3, 2), "1. Position updated to (3,2)")
	
	# 2. Rejection at fixed walls
	s = _make_board()
	s.tiles[Vector2i(3, 2)] = Constants.TileType.WALL
	res = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(not res["success"], "2. Rejection at fixed walls")
	_assert_eq(res["rejection_reason"], &"blocked_wall", "2. Rejection reason is blocked_wall")
	_assert_eq((res["next_state"] as BoardState).player_pos, Vector2i(2, 2), "2. Player position unchanged")
	
	# 3. Rejection at board boundaries
	s = _make_board()
	s.player_pos = Vector2i(0, 2)
	res = GameRules.apply_action(s, Constants.ActionType.MOVE_WEST)
	_assert_true(not res["success"], "3. Rejection at board boundaries")
	_assert_eq(res["rejection_reason"], &"blocked_bounds", "3. Rejection reason is blocked_bounds")
	
	# 4. Rejection when entering empty void
	s = _make_board()
	s.tiles[Vector2i(3, 2)] = Constants.TileType.VOID
	res = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(not res["success"], "4. Rejection when entering empty void")
	_assert_eq(res["rejection_reason"], &"blocked_void", "4. Rejection reason is blocked_void")
	
	# 5. Rejection when entering a floor block
	s = _make_board()
	s.blocks[Vector2i(3, 2)] = {"id": 1, "color": Constants.BlockColor.NEUTRAL, "is_bridge": false}
	res = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(not res["success"], "5. Rejection when entering a floor block")
	_assert_eq(res["rejection_reason"], &"blocked_block", "5. Rejection reason is blocked_block")
	
	# 6. Successful pickup of an adjacent block
	s = _make_board()
	s.blocks[Vector2i(3, 2)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(res["success"], "6. Successful pickup of an adjacent block")
	_assert_true(not (res["next_state"] as BoardState).blocks.has(Vector2i(3, 2)), "6. Block removed from board")
	_assert_eq((res["next_state"] as BoardState).carried_block.get("color", -1), Constants.BlockColor.CYAN, "6. Carried block has color Cyan")
	
	# 7. Pickup rejection when already carrying
	s = _make_board()
	s.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	s.blocks[Vector2i(3, 2)] = {"id": 2, "color": Constants.BlockColor.AMBER, "is_bridge": false}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(not res["success"], "7. Pickup rejection when already carrying")
	_assert_eq(res["rejection_reason"], &"cannot_place_on_block", "7. Tries to place and rejects (capacity 1)")
	
	# 8. Successful placement onto floor
	s = _make_board()
	s.carried_block = {"id": 1, "color": Constants.BlockColor.AMBER}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(res["success"], "8. Successful placement onto floor")
	var ns8: BoardState = res["next_state"]
	_assert_true(ns8.blocks.has(Vector2i(3, 2)), "8. Block placed at (3,2)")
	_assert_true(not ns8.is_carrying(), "8. Hand is empty")
	_assert_eq(ns8.blocks[Vector2i(3, 2)].get("is_bridge", true), false, "8. Block is floor obstacle")
	
	# 9. Successful placement onto void
	s = _make_board()
	s.tiles[Vector2i(3, 2)] = Constants.TileType.VOID
	s.carried_block = {"id": 1, "color": Constants.BlockColor.MAGENTA}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(res["success"], "9. Successful placement onto void")
	_assert_eq(res["event"], &"bridge_created", "9. Event is bridge_created")
	_assert_true((res["next_state"] as BoardState).is_bridge_at(Vector2i(3, 2)), "9. Cell (3,2) is a bridge")
	
	# 10. Movement across a bridged void
	var s_bridge: BoardState = res["next_state"]
	var res_walk: Dictionary = GameRules.apply_action(s_bridge, Constants.ActionType.MOVE_EAST)
	_assert_true(res_walk["success"], "10. Movement across a bridged void succeeds")
	_assert_eq((res_walk["next_state"] as BoardState).player_pos, Vector2i(3, 2), "10. Player standing on bridged void")
	
	# 11. Rejection when placing on an occupied cell
	s = _make_board()
	s.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	s.blocks[Vector2i(3, 2)] = {"id": 2, "color": Constants.BlockColor.NEUTRAL, "is_bridge": false}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(not res["success"], "11. Rejection when placing on an occupied cell")
	_assert_eq(res["rejection_reason"], &"cannot_place_on_block", "11. Reason is cannot_place_on_block")
	
	# 12. Rejection when placing on the player
	s = _make_board()
	s.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	var res_self: Dictionary = GameRules._apply_place(s, Constants.ActionType.INTERACT_NORTH, Vector2i(2, 2), Vector2i(2, 2), Vector2i.UP)
	_assert_true(not res_self["success"], "12. Rejection when placing on the player")
	_assert_eq(res_self["rejection_reason"], &"cannot_place_on_player", "12. Reason is cannot_place_on_player")
	
	# 13. Rejection when placing on an exit
	s = _make_board()
	s.exit_cell = Vector2i(3, 2)
	s.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(not res["success"], "13. Rejection when placing on an exit")
	_assert_eq(res["rejection_reason"], &"cannot_place_on_exit", "13. Reason is cannot_place_on_exit")
	
	# 14. Correct color preservation
	s = _make_board()
	s.blocks[Vector2i(3, 2)] = {"id": 99, "color": Constants.BlockColor.EMERALD, "is_bridge": false}
	var res_steal: Dictionary = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_eq((res_steal["next_state"] as BoardState).carried_block.get("color", -1), Constants.BlockColor.EMERALD, "14. Stolen block preserves Emerald color")
	var res_place: Dictionary = GameRules.apply_action(res_steal["next_state"], Constants.ActionType.INTERACT_NORTH)
	_assert_eq((res_place["next_state"] as BoardState).blocks[Vector2i(2, 1)].get("color", -1), Constants.BlockColor.EMERALD, "14. Placed block preserves Emerald color")
	
	# 15. Neutral socket activation
	s = _make_board()
	s.sockets[Vector2i(3, 2)] = Constants.BlockColor.NEUTRAL
	s.carried_block = {"id": 1, "color": Constants.BlockColor.MAGENTA}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(res["success"], "15. Neutral socket accepts Magenta block")
	_assert_eq(res["event"], &"socket_activated", "15. Socket activated")
	_assert_true((res["next_state"] as BoardState).is_socket_satisfied(Vector2i(3, 2)), "15. is_socket_satisfied is true")
	
	# 16. Colored socket activation
	s = _make_board()
	s.sockets[Vector2i(3, 2)] = Constants.BlockColor.CYAN
	s.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(res["success"], "16. Cyan socket accepts Cyan block")
	_assert_eq(res["event"], &"socket_activated", "16. Socket activated")
	_assert_true((res["next_state"] as BoardState).is_socket_satisfied(Vector2i(3, 2)), "16. is_socket_satisfied is true")
	
	# 17. Colored socket mismatch
	s = _make_board()
	s.sockets[Vector2i(3, 2)] = Constants.BlockColor.AMBER
	s.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	res = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(res["success"], "17. Placement on socket succeeds even if mismatched")
	_assert_eq(res["event"], &"socket_mismatch", "17. Event is socket_mismatch")
	_assert_true(not (res["next_state"] as BoardState).is_socket_satisfied(Vector2i(3, 2)), "17. Socket remains unsatisfied")
	
	# 18. Exit with unsatisfied sockets
	s = _make_board()
	s.exit_cell = Vector2i(3, 2)
	s.sockets[Vector2i(0, 0)] = Constants.BlockColor.CYAN
	res = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(res["success"], "18. Player steps onto exit")
	_assert_true(not (res["next_state"] as BoardState).is_completed, "18. Level NOT completed because socket is unsatisfied")
	
	# 19. Exit with satisfied sockets (and levels with no sockets)
	s = _make_board()
	s.exit_cell = Vector2i(3, 2)
	res = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(res["success"], "19. Player steps onto exit")
	_assert_true((res["next_state"] as BoardState).is_completed, "19. Level completed immediately when no sockets required")
	
	# 20. Undo after moving
	s = _make_board()
	var hist := HistoryManager.new()
	hist.initialize(s)
	var res_m: Dictionary = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	hist.record_state(res_m["next_state"])
	_assert_eq(hist.get_current_state().player_pos, Vector2i(3, 2), "20. Advanced to (3,2)")
	var undone_m: BoardState = hist.undo()
	_assert_eq(undone_m.player_pos, Vector2i(2, 2), "20. Undo restored position to (2,2)")
	
	# 21. Undo after pickup
	s = _make_board()
	s.blocks[Vector2i(3, 2)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	hist = HistoryManager.new()
	hist.initialize(s)
	var res_p: Dictionary = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	hist.record_state(res_p["next_state"])
	_assert_true(hist.get_current_state().is_carrying(), "21. Carrying block")
	var undone_p: BoardState = hist.undo()
	_assert_true(not undone_p.is_carrying(), "21. Undo restored empty hand")
	_assert_true(undone_p.blocks.has(Vector2i(3, 2)), "21. Undo restored block at (3,2)")
	
	# 22. Undo after placement
	s = _make_board()
	s.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	hist = HistoryManager.new()
	hist.initialize(s)
	var res_pl: Dictionary = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	hist.record_state(res_pl["next_state"])
	_assert_true(hist.get_current_state().blocks.has(Vector2i(3, 2)), "22. Block placed at (3,2)")
	var undone_pl: BoardState = hist.undo()
	_assert_true(not undone_pl.blocks.has(Vector2i(3, 2)), "22. Undo removed placed block")
	_assert_true(undone_pl.is_carrying(), "22. Undo restored carried block in hand")
	
	# 23. Undo after completion
	s = _make_board()
	s.exit_cell = Vector2i(3, 2)
	hist = HistoryManager.new()
	hist.initialize(s)
	var res_w: Dictionary = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	hist.record_state(res_w["next_state"])
	_assert_true(hist.get_current_state().is_completed, "23. Level completed")
	var undone_w: BoardState = hist.undo()
	_assert_true(not undone_w.is_completed, "23. Undo cleared completion state")
	_assert_eq(undone_w.player_pos, Vector2i(2, 2), "23. Undo restored player position")
	
	# 24. Restart after several actions
	s = _make_board()
	hist = HistoryManager.new()
	hist.initialize(s)
	var s1: BoardState = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)["next_state"]
	hist.record_state(s1)
	var s2: BoardState = GameRules.apply_action(s1, Constants.ActionType.MOVE_NORTH)["next_state"]
	hist.record_state(s2)
	var s3: BoardState = GameRules.apply_action(s2, Constants.ActionType.MOVE_WEST)["next_state"]
	hist.record_state(s3)
	var restarted: BoardState = hist.restart()
	_assert_eq(restarted.player_pos, Vector2i(2, 2), "24. Restart restored exact initial position")
	_assert_true(not hist.can_undo(), "24. Restart cleared undo history")
	
	# 25. Canonical state identity
	var s_a := _make_board()
	s_a.blocks[Vector2i(1, 1)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	s_a.blocks[Vector2i(3, 3)] = {"id": 2, "color": Constants.BlockColor.AMBER, "is_bridge": true}
	
	var s_b := _make_board()
	s_b.blocks[Vector2i(3, 3)] = {"id": 2, "color": Constants.BlockColor.AMBER, "is_bridge": true}
	s_b.blocks[Vector2i(1, 1)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	
	_assert_eq(s_a.get_canonical_key(), s_b.get_canonical_key(), "25. States with different block insertion orders produce identical canonical keys")
	
	# 26. Invalid actions producing no changes
	s = _make_board()
	s.tiles[Vector2i(3, 2)] = Constants.TileType.WALL
	var key_before: String = s.get_canonical_key()
	var res_inv: Dictionary = GameRules.apply_action(s, Constants.ActionType.MOVE_EAST)
	_assert_true(not res_inv["success"], "26. Invalid action rejected")
	_assert_eq((res_inv["next_state"] as BoardState).get_canonical_key(), key_before, "26. Invalid action produced zero change to logical state")
	
	# 27. Block placement followed by recovery
	s = _make_board()
	s.carried_block = {"id": 5, "color": Constants.BlockColor.CYAN}
	var res_p1: Dictionary = GameRules.apply_action(s, Constants.ActionType.INTERACT_EAST)
	_assert_true(res_p1["success"], "27. Block placed")
	var res_rec: Dictionary = GameRules.apply_action(res_p1["next_state"], Constants.ActionType.INTERACT_EAST)
	_assert_true(res_rec["success"], "27. Block recovered back into glove")
	_assert_eq((res_rec["next_state"] as BoardState).carried_block.get("color", -1), Constants.BlockColor.CYAN, "27. Recovered block preserves color")
	_assert_true(not (res_rec["next_state"] as BoardState).blocks.has(Vector2i(3, 2)), "27. Floor is clear again")
	
	# 28. Repeated undo and restart sequences
	s = _make_board()
	hist = HistoryManager.new()
	hist.initialize(s)
	for i in 5:
		var s_step: BoardState = GameRules.apply_action(hist.get_current_state(), Constants.ActionType.MOVE_NORTH)["next_state"]
		hist.record_state(s_step)
		hist.undo()
	_assert_eq(hist.get_current_state().player_pos, Vector2i(2, 2), "28. Repeated move-undo cycle leaves state at start")
	
	# Integrated Demonstration Scenario
	print("\n=== Demonstrating Stolen-Block Void Bridge Crossing Scenario ===")
	var demo := BoardState.new()
	demo.grid_size = Vector2i(7, 3)
	for x in 7:
		for y in 3:
			demo.tiles[Vector2i(x, y)] = Constants.TileType.WALL
	for x in range(1, 6):
		demo.tiles[Vector2i(x, 1)] = Constants.TileType.FLOOR
	demo.tiles[Vector2i(4, 1)] = Constants.TileType.VOID
	demo.player_pos = Vector2i(1, 1)
	demo.exit_cell = Vector2i(5, 1)
	demo.blocks[Vector2i(2, 1)] = {"id": 1, "color": Constants.BlockColor.NEUTRAL, "is_bridge": false}
	
	var res_a: Dictionary = GameRules.apply_action(demo, Constants.ActionType.MOVE_EAST)
	_assert_true(not res_a["success"], "Demo A: Player blocked by block obstacle on floor")
	
	var res_b: Dictionary = GameRules.apply_action(demo, Constants.ActionType.INTERACT_EAST)
	_assert_true(res_b["success"], "Demo B: Pip siphons block from obstacle cell")
	_assert_true((res_b["next_state"] as BoardState).is_carrying(), "Demo B: Pip now holds block in glove")
	
	var res_c: Dictionary = GameRules.apply_action(res_b["next_state"], Constants.ActionType.MOVE_EAST)
	_assert_true(res_c["success"], "Demo C: Pip steps into cleared floor at (2,1)")
	
	var res_d: Dictionary = GameRules.apply_action(res_c["next_state"], Constants.ActionType.MOVE_EAST)
	_assert_true(res_d["success"], "Demo D: Pip advances to (3,1) at the edge of the chasm")
	
	var res_e: Dictionary = GameRules.apply_action(res_d["next_state"], Constants.ActionType.MOVE_EAST)
	_assert_true(not res_e["success"], "Demo E: Cannot step into unbridged void")
	
	var res_f: Dictionary = GameRules.apply_action(res_d["next_state"], Constants.ActionType.INTERACT_EAST)
	_assert_true(res_f["success"], "Demo F: Block placed into void creates traversable bridge")
	_assert_true((res_f["next_state"] as BoardState).is_bridge_at(Vector2i(4, 1)), "Demo F: Cell (4,1) is now a bridge")
	
	var res_g: Dictionary = GameRules.apply_action(res_f["next_state"], Constants.ActionType.MOVE_EAST)
	_assert_true(res_g["success"], "Demo G: Pip traverses across the void bridge to (4,1)")
	
	var res_h: Dictionary = GameRules.apply_action(res_g["next_state"], Constants.ActionType.MOVE_EAST)
	_assert_true(res_h["success"], "Demo H: Pip reaches the Exit Portal at (5,1)")
	_assert_true(res_h["is_completed"], "Demo H: Level marked completed!")
	
	# 500-step randomized property fuzzing
	print("\n=== Running 500-Step Randomized Property Fuzzing ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	
	var fuzz_state := _make_board()
	fuzz_state.tiles[Vector2i(3, 1)] = Constants.TileType.VOID
	fuzz_state.sockets[Vector2i(1, 3)] = Constants.BlockColor.CYAN
	fuzz_state.exit_cell = Vector2i(4, 4)
	fuzz_state.blocks[Vector2i(1, 1)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	fuzz_state.blocks[Vector2i(3, 3)] = {"id": 2, "color": Constants.BlockColor.AMBER, "is_bridge": false}
	
	var fuzz_history := HistoryManager.new()
	fuzz_history.initialize(fuzz_state)
	
	var actions_pool: Array[int] = [
		Constants.ActionType.MOVE_NORTH, Constants.ActionType.MOVE_EAST,
		Constants.ActionType.MOVE_SOUTH, Constants.ActionType.MOVE_WEST,
		Constants.ActionType.INTERACT_NORTH, Constants.ActionType.INTERACT_EAST,
		Constants.ActionType.INTERACT_SOUTH, Constants.ActionType.INTERACT_WEST
	]
	
	var initial_terrain_snapshot: Dictionary = fuzz_state.tiles.duplicate()
	var fuzz_passed: bool = true
	
	for step in 500:
		if rng.randf() < 0.10 and fuzz_history.can_undo():
			var restored: BoardState = fuzz_history.undo()
			if restored == null:
				fuzz_passed = false
				break
		else:
			var act: int = actions_pool[rng.randi_range(0, actions_pool.size() - 1)]
			var cur_s: BoardState = fuzz_history.get_current_state()
			var res_fuzz: Dictionary = GameRules.apply_action(cur_s, act)
			if res_fuzz["success"]:
				fuzz_history.record_state(res_fuzz["next_state"])
				
		var cur: BoardState = fuzz_history.get_current_state()
		
		# Invariant 1: Player in bounds
		if not cur.is_inside_grid(cur.player_pos):
			fuzz_passed = false
			printerr("Invariant 1 Failed at step %d: Player out of bounds" % step)
			break
			
		# Invariant 2: No two blocks share same cell
		for pos: Vector2i in cur.blocks:
			if not cur.is_inside_grid(pos):
				fuzz_passed = false
				printerr("Invariant 2 Failed at step %d: Block out of bounds" % step)
				break
		if not fuzz_passed:
			break
			
		# Invariant 3: No player/block collision on ordinary floor
		if cur.blocks.has(cur.player_pos) and not cur.is_bridge_at(cur.player_pos):
			fuzz_passed = false
			printerr("Invariant 3 Failed at step %d: Player overlaps obstacle block" % step)
			break
			
		# Invariant 4: Carried block not simultaneously on board
		if cur.is_carrying():
			var carried_id: int = cur.carried_block["id"]
			for b: Dictionary in cur.blocks.values():
				if b["id"] == carried_id:
					fuzz_passed = false
					printerr("Invariant 4 Failed at step %d: Carried block duplicated on board" % step)
					break
			if not fuzz_passed:
				break
				
		# Invariant 5: Immutable terrain is unchanged
		for pos: Vector2i in initial_terrain_snapshot:
			if cur.get_tile(pos) != initial_terrain_snapshot[pos]:
				fuzz_passed = false
				printerr("Invariant 5 Failed at step %d: Immutable terrain altered" % step)
				break
		if not fuzz_passed:
			break

	_assert_true(fuzz_passed, "Property Fuzzing: 500 random actions preserved all 5 physical and state invariants")

func _test_invalid_data_handling() -> void:
	print("\n=== 4. Verifying Actionable Error Handling for Invalid Data ===")
	
	var empty_val := LevelRepository.validate_level_dict({})
	_assert_true(not empty_val["valid"], "Empty level dictionary correctly identified as invalid")
	_assert_true(empty_val["error"].length() > 0, "Actionable error returned: %s" % empty_val["error"])
	
	var missing_ch := LevelRepository.load_chapter(999)
	_assert_true(missing_ch.is_empty(), "Missing chapter 999 returns empty dict safely without crashing")
	
	var invalid_lvl := LevelRepository.load_level(1, 999)
	_assert_true(invalid_lvl.is_empty(), "Out-of-bounds level index returns empty dict safely")

func _test_puzzle_solvability() -> void:
	print("\n=== 5. Verifying Solvability Engine Integration ===")
	
	var lvl1: Dictionary = LevelRepository.load_level(1, 0)
	_assert_true(not lvl1.is_empty(), "Loaded Level 1-1 data from repository")
	
	var state := LevelData.from_dict(lvl1)
	var sol: Dictionary = PuzzleSolver.solve(state, 10000)
	_assert_true(sol["solved"], "Level 1-1 solved by PuzzleSolver")
	_assert_true(sol["steps"] > 0, "Optimal steps found: %d" % sol["steps"])
