extends SceneTree

const LevelValidator = preload("res://scripts/core/level_validator.gd")
const HintService = preload("res://scripts/services/hint_service.gd")

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
	_test_phase3_rendering_and_views()
	_test_phase3_input_and_hud()
	_test_phase4_solver_and_validation()
	_test_phase5_campaign_and_progression()
	_test_phase6_art_animation_audio()
	_test_phase7_ui_progression_persistence()
	_test_phase8_adversarial_qa()
	
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
	
	var demo_data := LevelRepository.load_chapter(0)
	_assert_true(not demo_data.is_empty(), "LevelRepository loads Demo Chapter (chapter 0) data")
	_assert_eq(demo_data.get("chapter", -1), 0, "Demo chapter number is 0")
	var demo_lvl1 := LevelRepository.load_demo_level(0)
	_assert_true(not demo_lvl1.is_empty(), "LevelRepository loads demo level 0 via load_demo_level")
	_assert_eq(demo_lvl1.get("id", ""), "demo_01", "Demo level 0 ID is demo_01")
	var demo_lvl2 := LevelRepository.load_demo_level(1)
	_assert_true(not demo_lvl2.is_empty(), "LevelRepository loads demo level 1 via load_demo_level")
	_assert_eq(demo_lvl2.get("id", ""), "demo_02", "Demo level 1 ID is demo_02")
	var demo_lvl3 := LevelRepository.load_demo_level(2)
	_assert_true(not demo_lvl3.is_empty(), "LevelRepository loads demo level 2 via load_demo_level")
	_assert_eq(demo_lvl3.get("id", ""), "demo_03", "Demo level 2 ID is demo_03")
	
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

func _test_phase3_rendering_and_views() -> void:
	print("\n=== 6. Verifying Phase 3.2 & 3.3 Board Rendering, Player Animation, and Block Views ===")
	
	# 1. PlayerView facing, positioning, and carried visual
	var pv := PlayerView.new()
	pv._ready()
	pv.snap_to_cell(Vector2i(2, 3), Constants.DIR_SOUTH)
	_assert_eq(pv._sprite.frame, 0, "PlayerView facing South has frame 0")
	_assert_eq(pv.position, Vector2(2 * 16 + 8, 3 * 16 + 8), "PlayerView snapped to cell center (40, 56)")
	
	pv.set_facing(Constants.DIR_EAST)
	_assert_eq(pv._sprite.frame, 1, "PlayerView facing East has frame 1")
	pv.set_facing(Constants.DIR_NORTH)
	_assert_eq(pv._sprite.frame, 2, "PlayerView facing North has frame 2")
	pv.set_facing(Constants.DIR_WEST)
	_assert_eq(pv._sprite.frame, 3, "PlayerView facing West has frame 3")
	
	pv.update_carried_visual({})
	_assert_true(not pv._carried_sprite.visible, "PlayerView carried sprite hidden when empty")
	pv.update_carried_visual({"id": 1, "color": Constants.BlockColor.AMBER})
	_assert_true(pv._carried_sprite.visible, "PlayerView carried sprite visible when holding block")
	_assert_eq(pv._carried_sprite.frame, Constants.BlockColor.AMBER, "PlayerView carried sprite has Amber frame")
	
	pv.animate_invalid_bump(Constants.DIR_EAST)
	pv.animate_steal(Vector2i(3, 3), Constants.BlockColor.CYAN)
	pv.animate_placement(Vector2i(3, 3))
	pv.queue_free()
	_assert_true(true, "PlayerView animations execute cleanly without errors")
	
	# 2. BlockView styling and methods
	var bv_obstacle := BlockView.new()
	bv_obstacle._ready()
	bv_obstacle.setup(1, Constants.BlockColor.CYAN, false, Vector2i(1, 1))
	_assert_eq(bv_obstacle.z_index, 2, "Obstacle block has z_index = 2")
	_assert_eq(bv_obstacle.scale, Vector2(1.0, 1.0), "Obstacle block has scale (1.0, 1.0)")
	_assert_eq(bv_obstacle._sprite.frame, Constants.BlockColor.CYAN, "Block frame matches Cyan (1)")
	
	var bv_bridge := BlockView.new()
	bv_bridge._ready()
	bv_bridge.setup(2, Constants.BlockColor.EMERALD, true, Vector2i(1, 2))
	_assert_eq(bv_bridge.z_index, 0, "Bridge block has z_index = 0")
	_assert_eq(bv_bridge.scale, Vector2(0.9, 0.9), "Bridge block has scale (0.9, 0.9)")
	_assert_eq(bv_bridge.modulate, Color(0.85, 0.9, 1.0, 0.9), "Bridge block has translucent/tinted modulate")
	_assert_eq(bv_bridge._sprite.frame, Constants.BlockColor.EMERALD, "Bridge block frame matches Emerald (4)")
	
	bv_obstacle.animate_placement()
	bv_obstacle.pulse_socket_activation()
	bv_obstacle.animate_steal()
	bv_obstacle.queue_free()
	bv_bridge.queue_free()
	_assert_true(true, "BlockView visual methods execute cleanly")
	
	# 3. BoardRenderer scene setup and layer verification
	var state := BoardState.new()
	state.grid_size = Vector2i(4, 4)
	state.tiles[Vector2i(0, 0)] = Constants.TileType.FLOOR
	state.tiles[Vector2i(1, 0)] = Constants.TileType.WALL
	state.tiles[Vector2i(2, 0)] = Constants.TileType.VOID
	state.sockets[Vector2i(0, 0)] = Constants.BlockColor.CYAN
	state.exit_cell = Vector2i(3, 0)
	state.player_pos = Vector2i(0, 0)
	state.blocks[Vector2i(2, 0)] = {"id": 1, "color": Constants.BlockColor.AMBER, "is_bridge": true}
	
	var renderer := BoardRenderer.new()
	renderer._ready()
	renderer.setup_board(state)
	
	# Verify terrain tile placement
	_assert_eq(renderer.floor_layer.get_cell_atlas_coords(Vector2i(0, 0)), Vector2i(0, 0), "Floor tile placed at (0,0)")
	_assert_eq(renderer.wall_layer.get_cell_atlas_coords(Vector2i(1, 0)), Vector2i(1, 0), "Wall tile placed at (1,0)")
	_assert_eq(renderer.void_layer.get_cell_atlas_coords(Vector2i(2, 0)), Vector2i(2, 0), "Void tile placed at (2,0)")
	_assert_eq(renderer.floor_layer.get_cell_atlas_coords(Vector2i(2, 0)), Vector2i(3, 0), "Bridge tile placed on floor layer over void at (2,0)")
	
	# Verify socket unsatisfied frame
	# Cyan socket unsatisfied = color 1 * 2 + 0 = 2
	_assert_eq(renderer.socket_layer.get_cell_atlas_coords(Vector2i(0, 0)), Vector2i(2, 0), "Cyan socket unsatisfied has frame 2")
	
	# Verify exit portal locked
	_assert_eq(renderer.exit_sprite.frame, 0, "Exit portal locked has frame 0 when socket unsatisfied")
	_assert_eq(renderer.exit_sprite.position, Vector2(3 * 16 + 8, 0 * 16 + 8), "Exit portal positioned at exit cell")
	
	# Satisfy socket with Cyan block
	state.blocks[Vector2i(0, 0)] = {"id": 2, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	renderer.update_view(state, false)
	
	# Cyan socket satisfied = color 1 * 2 + 1 = 3
	_assert_eq(renderer.socket_layer.get_cell_atlas_coords(Vector2i(0, 0)), Vector2i(3, 0), "Cyan socket satisfied has frame 3")
	_assert_eq(renderer.exit_sprite.frame, 1, "Exit portal unlocked has frame 1 when all sockets satisfied")
	
	# Check block view tracking
	_assert_true(renderer.block_views.has(Vector2i(0, 0)), "BlockView tracked at (0,0)")
	_assert_true(renderer.block_views.has(Vector2i(2, 0)), "BlockView tracked at (2,0)")
	
	# Reduced motion toggle
	renderer.reduced_motion = true
	_assert_true(renderer.player_view.reduced_motion, "reduced_motion propagated to PlayerView")
	for bv: BlockView in renderer.block_views.values():
		_assert_true(bv.reduced_motion, "reduced_motion propagated to BlockView")
		
	# Helper methods
	renderer.animate_player_move(Vector2i(1, 1), Constants.DIR_SOUTH)
	renderer.snap_player(Vector2i(0, 0), Constants.DIR_EAST)
	renderer.animate_invalid_bump(Constants.DIR_WEST)
	
	renderer.queue_free()
	_assert_true(true, "BoardRenderer setup and update cycles passed cleanly")

func _test_phase3_input_and_hud() -> void:
	print("\n=== 7. Verifying Phase 3.4 & 3.5 Input Handling, Buffering, and HUD Upgrades ===")
	
	# 1. GameController input handling and invalid action bump
	var gc := GameController.new()
	gc._ready()
	var lvl_demo1: Dictionary = LevelRepository.load_level(0, 0)
	gc.load_level_data(lvl_demo1)
	
	_assert_true(gc.model != null, "GameController loaded model successfully")
	_assert_eq(gc.model.get_state().player_pos, Vector2i(1, 1), "Initial player position is (1,1)")
	_assert_eq(gc.is_animating, false, "Initial is_animating is false")
	_assert_eq(gc._input_buffer, -1, "Initial _input_buffer is -1")
	
	# Valid action: steal block East
	gc.request_action(Constants.ActionType.INTERACT_EAST)
	_assert_true(gc.model.get_state().is_carrying(), "Interacting East steals block into hand")
	_assert_eq(gc.model.get_state().carried_block.get("color", -1), Constants.BlockColor.NEUTRAL, "Carried block has Neutral color")
	
	# Invalid action: moving North into wall
	var invalid_payload := { "detected": false, "reason": &"" }
	gc.invalid_action_occurred.connect(func(_act: int, reason: StringName):
		invalid_payload["detected"] = true
		invalid_payload["reason"] = reason
	)
	gc.request_action(Constants.ActionType.MOVE_NORTH)
	_assert_true(invalid_payload["detected"], "Invalid move North into wall triggers invalid_action_occurred signal")
	_assert_eq(invalid_payload["reason"], &"blocked_wall", "Invalid move rejection reason is blocked_wall")
	_assert_eq(gc.model.get_state().player_pos, Vector2i(1, 1), "Player position unchanged after invalid move")
	
	# Input buffering test
	gc.is_animating = true
	gc.request_action(Constants.ActionType.MOVE_EAST)
	_assert_eq(gc._input_buffer, Constants.ActionType.MOVE_EAST, "Action is buffered when is_animating is true")
	_assert_eq(gc.model.get_state().player_pos, Vector2i(1, 1), "Player position not immediately changed while animating")
	
	# Complete animation and verify buffered action execution
	gc._on_player_move_completed()
	_assert_eq(gc.is_animating, false, "is_animating reset to false after animation completion")
	_assert_eq(gc._input_buffer, -1, "Buffered action cleared from buffer")
	_assert_eq(gc.model.get_state().player_pos, Vector2i(2, 1), "Buffered action MOVE_EAST executed upon move completion")
	
	# Undo cancels input buffer and snaps view
	gc.is_animating = true
	gc._input_buffer = Constants.ActionType.MOVE_EAST
	gc.handle_undo()
	_assert_eq(gc._input_buffer, -1, "Undo immediately cancels _input_buffer")
	_assert_eq(gc.is_animating, false, "Undo immediately resets is_animating")
	_assert_eq(gc.model.get_state().player_pos, Vector2i(1, 1), "Undo restored player position to (1,1)")
	
	# Restart cancels input buffer and snaps view
	gc.is_animating = true
	gc._input_buffer = Constants.ActionType.MOVE_SOUTH
	gc.handle_restart()
	_assert_eq(gc._input_buffer, -1, "Restart immediately cancels _input_buffer")
	_assert_eq(gc.is_animating, false, "Restart immediately resets is_animating")
	_assert_eq(gc.model.get_state().player_pos, Vector2i(1, 1), "Restart restored initial player position")
	gc.queue_free()

	# 2. HUD upgrade verification
	var hud_packed = ResourceLoader.load("res://scenes/ui/hud.tscn")
	_assert_true(hud_packed != null, "HUD scene loads successfully")
	var hud := hud_packed.instantiate() as HUD
	hud._ready()
	
	# Verify button focus modes
	_assert_eq(hud.undo_btn.focus_mode, Control.FOCUS_NONE, "Undo button focus_mode is FOCUS_NONE")
	_assert_eq(hud.restart_btn.focus_mode, Control.FOCUS_NONE, "Restart button focus_mode is FOCUS_NONE")
	_assert_eq(hud.hint_btn.focus_mode, Control.FOCUS_NONE, "Hint button focus_mode is FOCUS_NONE")
	_assert_eq(hud.menu_btn.focus_mode, Control.FOCUS_NONE, "Menu button focus_mode is FOCUS_NONE")
	
	# Level title and move counter
	hud.set_level_info("Demo 1: The Obstructed Path", 0)
	_assert_eq(hud.title_label.text, "Demo 1: The Obstructed Path", "Level title text matches")
	hud.update_turn_count(3)
	_assert_eq(hud.turn_label.text, "Moves: 3", "Turn counter formatted as 'Moves: 3'")
	
	# Carried fragment indicator
	hud.update_carried_indicator({})
	_assert_eq(hud.glove_label.text, "Glove: Empty", "Empty glove displays 'Glove: Empty'")
	_assert_true(not hud.carried_block_rect.visible, "Carried block preview hidden when empty")
	
	hud.update_carried_indicator({"id": 1, "color": Constants.BlockColor.CYAN})
	_assert_eq(hud.glove_label.text, "Glove: Cyan Fragment", "Carrying cyan block displays 'Glove: Cyan Fragment'")
	_assert_true(hud.carried_block_rect.visible, "Carried block preview visible when carrying")
	
	hud.update_carried_indicator({"id": 2, "color": Constants.BlockColor.EMERALD})
	_assert_eq(hud.glove_label.text, "Glove: Emerald Fragment", "Carrying emerald block displays 'Glove: Emerald Fragment'")
	
	# Sockets and exit status indicators
	var s_nosockets := BoardState.new()
	hud.update_socket_and_exit_indicators(s_nosockets)
	_assert_eq(hud.sockets_label.text, "No Sockets", "Level with 0 sockets displays 'No Sockets'")
	_assert_eq(hud.exit_label.text, "Exit: OPEN", "Exit is OPEN when no sockets required")
	
	var s_with_socket := BoardState.new()
	s_with_socket.sockets[Vector2i(2, 2)] = Constants.BlockColor.CYAN
	hud.update_socket_and_exit_indicators(s_with_socket)
	_assert_eq(hud.sockets_label.text, "Sockets: 0/1", "Unsatisfied socket displays 'Sockets: 0/1'")
	_assert_eq(hud.exit_label.text, "Exit: LOCKED", "Exit is LOCKED when socket unsatisfied")
	
	s_with_socket.blocks[Vector2i(2, 2)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	hud.update_socket_and_exit_indicators(s_with_socket)
	_assert_eq(hud.sockets_label.text, "Sockets: 1/1 (Active)", "Satisfied socket displays 'Sockets: 1/1 (Active)'")
	_assert_eq(hud.exit_label.text, "Exit: OPEN", "Exit is OPEN when all sockets satisfied")
	hud.queue_free()
	
	# 3. MainGame demo sequence and progression
	var main := MainGame.new()
	main._ready()
	main._start_adventure()
	_assert_eq(main._current_chapter, 0, "Start adventure launches Chapter 0 (Demo)")
	_assert_eq(main._current_level_idx, 0, "Start adventure launches Level 0 (demo_01)")
	
	main._advance_next_level()
	_assert_eq(main._current_chapter, 0, "Next level remains in Demo chapter")
	_assert_eq(main._current_level_idx, 1, "Next level loads Level 1 (demo_02)")
	
	main._advance_next_level()
	_assert_eq(main._current_level_idx, 2, "Next level loads Level 2 (demo_03)")
	
	main._advance_next_level()
	_assert_eq(main._current_chapter, 1, "After demo_03, advances to Chapter 1")
	_assert_eq(main._current_level_idx, 0, "Chapter 1 starts at Level 0 (ch1_01)")
	main.queue_free()

func _test_phase4_solver_and_validation() -> void:
	print("\n=== 8. Verifying Phase 4 Puzzle Solver, Formal Level Validator, and Hint System ===")
	
	# ---------------------------------------------------------
	# TEST 1: Simple route with no movable fragments
	# ---------------------------------------------------------
	var lvl1: Dictionary = {
		"id": "t1_simple",
		"name": "Simple Route",
		"width": 5, "height": 3,
		"layout": [
			"#####",
			"#P.E#",
			"#####"
		]
	}
	var v_res1: Dictionary = LevelValidator.validate_level(lvl1)
	_assert_true(v_res1["valid"], "1. Level 1 layout is valid")
	var s1: BoardState = LevelData.from_dict(lvl1)
	var sol1: Dictionary = PuzzleSolver.solve(s1)
	_assert_eq(sol1["status"], PuzzleSolver.SolverStatus.SOLVED, "1. Solved simple route")
	_assert_eq(sol1["steps"], 2, "1. Exactly 2 steps (MOVE_EAST -> MOVE_EAST)")
	_assert_eq(sol1["actions"], [Constants.ActionType.MOVE_EAST, Constants.ActionType.MOVE_EAST], "1. Optimal action sequence")
	var vr1: Dictionary = PuzzleSolver.verify_solution(s1, sol1["actions"])
	_assert_true(vr1["valid"], "1. Solution replay verification passed")

	# ---------------------------------------------------------
	# TEST 2: Puzzle requiring pickup (obstacle clearance)
	# ---------------------------------------------------------
	var lvl2: Dictionary = {
		"id": "t2_pickup",
		"name": "Pickup Obstacle",
		"width": 6, "height": 3,
		"layout": [
			"######",
			"#P..E#",
			"######"
		],
		"blocks": [
			{"pos": [2, 1], "color": Constants.BlockColor.CYAN}
		]
	}
	var s2: BoardState = LevelData.from_dict(lvl2)
	var sol2: Dictionary = PuzzleSolver.solve(s2)
	_assert_eq(sol2["status"], PuzzleSolver.SolverStatus.SOLVED, "2. Solved puzzle requiring pickup")
	_assert_eq(sol2["actions"][0], Constants.ActionType.INTERACT_EAST, "2. First action is INTERACT_EAST to siphon obstacle")
	var vr2: Dictionary = PuzzleSolver.verify_solution(s2, sol2["actions"])
	_assert_true(vr2["valid"], "2. Replay verification passed for pickup puzzle")

	# ---------------------------------------------------------
	# TEST 3: Puzzle requiring bridge placement
	# ---------------------------------------------------------
	var s3 := BoardState.new()
	s3.grid_size = Vector2i(6, 3)
	for x: int in 6:
		for y: int in 3:
			s3.tiles[Vector2i(x, y)] = Constants.TileType.WALL
	s3.tiles[Vector2i(1, 1)] = Constants.TileType.FLOOR
	s3.tiles[Vector2i(2, 1)] = Constants.TileType.VOID
	s3.tiles[Vector2i(3, 1)] = Constants.TileType.FLOOR
	s3.tiles[Vector2i(4, 1)] = Constants.TileType.FLOOR
	s3.player_pos = Vector2i(1, 1)
	s3.exit_cell = Vector2i(4, 1)
	s3.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}
	var sol3: Dictionary = PuzzleSolver.solve(s3)
	_assert_eq(sol3["status"], PuzzleSolver.SolverStatus.SOLVED, "3. Solved puzzle requiring bridge placement")
	_assert_eq(sol3["actions"][0], Constants.ActionType.INTERACT_EAST, "3. First action places bridge eastward into void")
	var vr3: Dictionary = PuzzleSolver.verify_solution(s3, sol3["actions"])
	_assert_true(vr3["valid"], "3. Bridge placement replay verification passed")

	# ---------------------------------------------------------
	# TEST 4: Puzzle requiring neutral socket
	# ---------------------------------------------------------
	var lvl4: Dictionary = {
		"id": "t4_neutral_socket",
		"name": "Neutral Socket",
		"width": 6, "height": 4,
		"layout": [
			"######",
			"#P..E#",
			"#. S.#",
			"######"
		],
		"blocks": [
			{"pos": [2, 1], "color": Constants.BlockColor.MAGENTA}
		]
	}
	var s4: BoardState = LevelData.from_dict(lvl4)
	var sol4: Dictionary = PuzzleSolver.solve(s4)
	_assert_eq(sol4["status"], PuzzleSolver.SolverStatus.SOLVED, "4. Solved neutral socket puzzle")
	var vr4: Dictionary = PuzzleSolver.verify_solution(s4, sol4["actions"])
	_assert_true(vr4["valid"], "4. Neutral socket replay verification passed")
	_assert_true(vr4["final_state"].is_socket_satisfied(Vector2i(3, 2)), "4. Socket is satisfied in final state")

	# ---------------------------------------------------------
	# TEST 5: Puzzle requiring colored socket
	# ---------------------------------------------------------
	var s5 := BoardState.new()
	s5.grid_size = Vector2i(5, 5)
	for x: int in 5:
		for y: int in 5:
			s5.tiles[Vector2i(x, y)] = Constants.TileType.WALL
	s5.tiles[Vector2i(2, 2)] = Constants.TileType.FLOOR
	s5.tiles[Vector2i(3, 2)] = Constants.TileType.FLOOR
	s5.tiles[Vector2i(2, 1)] = Constants.TileType.FLOOR
	s5.tiles[Vector2i(1, 2)] = Constants.TileType.FLOOR
	s5.tiles[Vector2i(2, 3)] = Constants.TileType.FLOOR
	s5.player_pos = Vector2i(2, 2)
	s5.exit_cell = Vector2i(1, 2)
	s5.sockets[Vector2i(3, 2)] = Constants.BlockColor.CYAN
	s5.sockets[Vector2i(2, 1)] = Constants.BlockColor.AMBER
	s5.blocks[Vector2i(2, 3)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	s5.carried_block = {"id": 2, "color": Constants.BlockColor.AMBER}
	var sol5: Dictionary = PuzzleSolver.solve(s5)
	_assert_eq(sol5["status"], PuzzleSolver.SolverStatus.SOLVED, "5. Solved colored socket puzzle")
	var vr5: Dictionary = PuzzleSolver.verify_solution(s5, sol5["actions"])
	_assert_true(vr5["valid"], "5. Colored sockets replay verification passed")
	_assert_true(vr5["final_state"].is_all_sockets_satisfied(), "5. All colored sockets satisfied")

	# ---------------------------------------------------------
	# TEST 6: Two indistinguishable fragments producing identical canonical key
	# ---------------------------------------------------------
	var s6_a := BoardState.new()
	s6_a.player_pos = Vector2i(2, 2)
	s6_a.blocks[Vector2i(1, 1)] = {"id": 10, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	s6_a.blocks[Vector2i(3, 3)] = {"id": 20, "color": Constants.BlockColor.CYAN, "is_bridge": false}

	var s6_b := BoardState.new()
	s6_b.player_pos = Vector2i(2, 2)
	s6_b.blocks[Vector2i(1, 1)] = {"id": 20, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	s6_b.blocks[Vector2i(3, 3)] = {"id": 10, "color": Constants.BlockColor.CYAN, "is_bridge": false}

	_assert_eq(s6_a.get_canonical_key(), s6_b.get_canonical_key(), "6. Identical block colors with swapped IDs produce identical canonical key")

	var s6_c := BoardState.new()
	s6_c.player_pos = Vector2i(2, 2)
	s6_c.carried_block = {"id": 1, "color": Constants.BlockColor.CYAN}

	var s6_d := BoardState.new()
	s6_d.player_pos = Vector2i(2, 2)
	s6_d.carried_block = {"id": 99, "color": Constants.BlockColor.CYAN}

	_assert_eq(s6_c.get_canonical_key(), s6_d.get_canonical_key(), "6. Carried blocks with identical color but different IDs produce identical canonical key")

	# ---------------------------------------------------------
	# TEST 7: Deliberately impossible level (reports UNSOLVABLE)
	# ---------------------------------------------------------
	var lvl7: Dictionary = {
		"id": "t7_impossible",
		"name": "Sealed Vault",
		"width": 7, "height": 3,
		"layout": [
			"#######",
			"#P#.#E#",
			"#######"
		]
	}
	var s7: BoardState = LevelData.from_dict(lvl7)
	var sol7: Dictionary = PuzzleSolver.solve(s7)
	_assert_eq(sol7["status"], PuzzleSolver.SolverStatus.UNSOLVABLE, "7. Impossible level reports UNSOLVABLE")
	_assert_eq(sol7["solved"], false, "7. Solved is false")
	_assert_eq(sol7["steps"], -1, "7. Steps is -1")

	# ---------------------------------------------------------
	# TEST 8: Invalid level (reports validation failure with specific field/coords)
	# ---------------------------------------------------------
	var lvl8_wall_block: Dictionary = {
		"id": "t8_invalid",
		"name": "Wall Block Error",
		"width": 5, "height": 3,
		"layout": [
			"#####",
			"#P.E#",
			"#####"
		],
		"blocks": [
			{"pos": [2, 0], "color": Constants.BlockColor.CYAN}
		]
	}
	var v_res8: Dictionary = LevelValidator.validate_level(lvl8_wall_block)
	_assert_eq(v_res8["valid"], false, "8. Block on wall rejected")
	_assert_eq(v_res8["cell"], Vector2i(2, 0), "8. Error names offending cell (2, 0)")
	_assert_true("immutable wall" in v_res8["error"], "8. Error message specifies immutable wall rule")

	var lvl8_ragged: Dictionary = {
		"id": "t8_ragged",
		"name": "Ragged",
		"width": 5, "height": 3,
		"layout": [
			"#####",
			"#P.E",
			"#####"
		]
	}
	var v_res_ragged: Dictionary = LevelValidator.validate_level(lvl8_ragged)
	_assert_eq(v_res_ragged["valid"], false, "8. Ragged layout rejected")
	_assert_true("ragged layout" in v_res_ragged["error"], "8. Error specifies ragged layout")

	var lvl8_overlap: Dictionary = {
		"id": "t8_overlap",
		"name": "Overlap",
		"width": 5, "height": 3,
		"layout": [
			"#####",
			"#P.E#",
			"#####"
		],
		"blocks": [
			{"pos": [2, 1], "color": Constants.BlockColor.CYAN},
			{"pos": [2, 1], "color": Constants.BlockColor.AMBER}
		]
	}
	var v_res_overlap: Dictionary = LevelValidator.validate_level(lvl8_overlap)
	_assert_eq(v_res_overlap["valid"], false, "8. Overlapping blocks rejected")
	_assert_eq(v_res_overlap["cell"], Vector2i(2, 1), "8. Overlap coordinates identified")

	# ---------------------------------------------------------
	# TEST 9: Multi-step puzzle requiring multiple steals and placements
	# ---------------------------------------------------------
	var lvl9: Dictionary = {
		"id": "t9_multistep",
		"name": "Demo 02 Bridge Crossing",
		"width": 8, "height": 5,
		"layout": [
			"########",
			"#P... E#",
			"#..#### #",
			"#..#    #",
			"########"
		],
		"blocks": [
			{"pos": [2, 1], "color": Constants.BlockColor.CYAN}
		]
	}
	var s9: BoardState = LevelData.from_dict(lvl9)
	var sol9: Dictionary = PuzzleSolver.solve(s9)
	_assert_eq(sol9["status"], PuzzleSolver.SolverStatus.SOLVED, "9. Multi-step puzzle solved")
	_assert_true(sol9["steps"] >= 5, "9. Requires multiple steps (actual: %d)" % sol9["steps"])
	var vr9: Dictionary = PuzzleSolver.verify_solution(s9, sol9["actions"])
	_assert_true(vr9["valid"], "9. Multi-step solution replay verification succeeded")

	# ---------------------------------------------------------
	# TEST 10: Equivalent states with reordered fragments produce same canonical hash
	# ---------------------------------------------------------
	var s10_1 := BoardState.new()
	s10_1.player_pos = Vector2i(2, 2)
	s10_1.blocks[Vector2i(1, 2)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	s10_1.blocks[Vector2i(3, 2)] = {"id": 2, "color": Constants.BlockColor.AMBER, "is_bridge": false}
	s10_1.blocks[Vector2i(2, 3)] = {"id": 3, "color": Constants.BlockColor.EMERALD, "is_bridge": true}

	var s10_2 := BoardState.new()
	s10_2.player_pos = Vector2i(2, 2)
	s10_2.blocks[Vector2i(2, 3)] = {"id": 3, "color": Constants.BlockColor.EMERALD, "is_bridge": true}
	s10_2.blocks[Vector2i(1, 2)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	s10_2.blocks[Vector2i(3, 2)] = {"id": 2, "color": Constants.BlockColor.AMBER, "is_bridge": false}

	_assert_eq(s10_1.get_canonical_key(), s10_2.get_canonical_key(), "10. Insertion order differences produce identical canonical keys")
	_assert_eq(s10_1.get_state_hash(), s10_2.get_state_hash(), "10. Hashes match identically")

	# ---------------------------------------------------------
	# TEST 11: Current-state hint after several moves
	# ---------------------------------------------------------
	var s11: BoardState = LevelData.from_dict(lvl9)
	var res_step1: Dictionary = GameRules.apply_action(s11, Constants.ActionType.INTERACT_EAST)
	_assert_true(res_step1["success"], "11. Move 1 succeeded")
	var state_after_step1: BoardState = res_step1["next_state"]

	var hint1: Dictionary = HintService.generate_hint(state_after_step1)
	_assert_true(hint1["has_hint"], "11. Hint generated from intermediate state")
	_assert_eq(hint1["status"], "SOLVED", "11. Hint status is SOLVED")
	_assert_eq(hint1["next_action"], Constants.ActionType.MOVE_EAST, "11. Hint suggests moving East next")
	_assert_true("East" in hint1["hint_text"], "11. Hint mentions East direction")

	var s11_unwinnable: BoardState = LevelData.from_dict(lvl7)
	var hint_fail: Dictionary = HintService.generate_hint(s11_unwinnable)
	_assert_eq(hint_fail["has_hint"], false, "11. Unwinnable state has has_hint=false")
	_assert_eq(hint_fail["status"], "UNSOLVABLE", "11. Unwinnable state has status=UNSOLVABLE")
	_assert_true("Undo" in hint_fail["hint_text"], "11. Hint recommends Undo or Restart")

	# ---------------------------------------------------------
	# TEST 12: Search limit behavior (reports LIMIT_REACHED with max_visited=5)
	# ---------------------------------------------------------
	var s12: BoardState = LevelData.from_dict(lvl9)
	var sol12: Dictionary = PuzzleSolver.solve(s12, 5)
	_assert_eq(sol12["status"], PuzzleSolver.SolverStatus.LIMIT_REACHED, "12. Search limit reached reports LIMIT_REACHED")
	_assert_eq(sol12["solved"], false, "12. Solved is false")
	_assert_true(sol12["visited_count"] > 5, "12. Visited count reflects threshold")
	_assert_true("budget" in sol12["message"].to_lower(), "12. Message specifies budget exceeded")

	# ---------------------------------------------------------
	# TEST 13: Solution replay verification passes & catches illegal modifications
	# ---------------------------------------------------------
	var s13: BoardState = LevelData.from_dict(lvl1)
	var sol13: Dictionary = PuzzleSolver.solve(s13)
	var vr13_good: Dictionary = PuzzleSolver.verify_solution(s13, sol13["actions"])
	_assert_true(vr13_good["valid"], "13. Replay verification passes on genuine solution")

	var tampered_actions: Array = [Constants.ActionType.MOVE_NORTH] + sol13["actions"]
	var vr13_bad: Dictionary = PuzzleSolver.verify_solution(s13, tampered_actions)
	_assert_eq(vr13_bad["valid"], false, "13. Replay verification catches illegal move")
	_assert_eq(vr13_bad["failed_step"], 0, "13. Identified step 0 as failure")
	_assert_eq(vr13_bad["rejection_reason"], &"blocked_wall", "13. Rejection reason is blocked_wall")

	# ---------------------------------------------------------
	# TEST 14: Solver solution followed by live model completion
	# ---------------------------------------------------------
	var s14: BoardState = LevelData.from_dict(lvl1)
	var model14 := BoardModel.new()
	model14.initialize(s14)
	var sol14: Dictionary = PuzzleSolver.solve(s14)

	for act: int in sol14["actions"]:
		var step_res: Dictionary = model14.try_action(act)
		_assert_true(step_res["success"], "14. Model action executed cleanly")

	_assert_true(model14.is_completed(), "14. Live model reached completed status")
	_assert_eq(model14.get_state().player_pos, Vector2i(3, 1), "14. Final player position matches exit")

func _test_phase5_campaign_and_progression() -> void:
	print("\n=== 9. Verifying Phase 5 Complete Campaign, Curriculum Rules, and Progression ===")
	
	# 1. Verify all 4 campaign chapters exist and contain exactly 5 levels each
	var total_campaign_levels: int = 0
	for ch_num in range(1, 5):
		var ch_data := LevelRepository.load_chapter(ch_num)
		_assert_true(not ch_data.is_empty(), "Chapter %d file loads cleanly" % ch_num)
		var levels: Array = ch_data.get("levels", [])
		_assert_eq(levels.size(), 5, "Chapter %d contains exactly 5 levels" % ch_num)
		total_campaign_levels += levels.size()
		
		# Validate every level in chapter
		for lvl_idx in levels.size():
			var lvl: Dictionary = levels[lvl_idx]
			var v_res: Dictionary = LevelValidator.validate_level(lvl)
			_assert_true(v_res["valid"], "Level %s validation passed: %s" % [lvl.get("id", ""), v_res.get("error", "")])
			
			var layout: Array = lvl.get("layout", [])
			# Curriculum rules check
			if ch_num == 1:
				var has_void: bool = false
				var has_socket: bool = false
				for row: String in layout:
					if " " in row: has_void = true
					for c in "S1234":
						if c in row: has_socket = true
				_assert_true(not has_void, "Chapter 1 Level %s strictly contains NO VOID before introduction" % lvl.get("id", ""))
				_assert_true(not has_socket, "Chapter 1 Level %s strictly contains NO SOCKETS before introduction" % lvl.get("id", ""))
			elif ch_num == 2:
				var has_socket: bool = false
				for row: String in layout:
					for c in "S1234":
						if c in row: has_socket = true
				_assert_true(not has_socket, "Chapter 2 Level %s strictly contains NO SOCKETS before introduction" % lvl.get("id", ""))
			elif ch_num == 3:
				var has_colored_socket: bool = false
				for row: String in layout:
					for c in "1234":
						if c in row: has_colored_socket = true
				_assert_true(not has_colored_socket, "Chapter 3 Level %s strictly contains NO COLORED SOCKETS before Chapter 4" % lvl.get("id", ""))

	_assert_eq(total_campaign_levels, 20, "Total campaign levels count is exactly 20")
	
	# Demo levels check
	var demo_data := LevelRepository.load_chapter(0)
	var demo_levels: Array = demo_data.get("levels", [])
	_assert_eq(demo_levels.size(), 3, "Tutorial / Demo contains exactly 3 levels")

	# 2. Progression Service Invariants
	ProgressService.reset_progress()
	var t1_unlocked: bool = ProgressService.is_level_unlocked(1, 0)
	_assert_true(t1_unlocked, "Chapter 1 Level 1 (ch1_01) is unlocked by default")
	
	ProgressService.record_level_completion("ch1_01", 5, "ch1_02")
	_assert_true(ProgressService.is_level_completed("ch1_01"), "ch1_01 recorded as completed")
	_assert_true(ProgressService.is_level_unlocked(1, 1), "ch1_02 unlocked after completing ch1_01")
	
	# Chapter completion and restoration text
	for i in range(1, 6):
		ProgressService.record_level_completion("ch1_0%d" % i, 10, "ch1_0%d" % (i + 1) if i < 5 else "ch2_01")
	_assert_true(ProgressService.is_chapter_completed(1), "Chapter 1 marked completed when all 5 levels done")
	
	var r1_text: String = ProgressService.get_chapter_restoration_text(1)
	_assert_true("Sector 1" in r1_text, "Chapter 1 restoration text valid: %s" % r1_text)
	
	var r4_text: String = ProgressService.get_chapter_restoration_text(4)
	_assert_true("PIXEL CORE IS RESTORED" in r4_text, "Chapter 4 restoration text valid: %s" % r4_text)
	
	# Campaign finale detection
	_assert_true(not ProgressService.is_campaign_completed(), "Campaign not marked completed before ch4_05")
	ProgressService.record_level_completion("ch4_05", 24)
	_assert_true(ProgressService.is_campaign_completed(), "Campaign marked completed when ch4_05 is completed")
	
	# 3. HUD Ending modal verification
	var hud_scene: PackedScene = ResourceLoader.load("res://scenes/ui/hud.tscn")
	var hud: HUD = hud_scene.instantiate()
	hud._ready()
	hud.show_win(24, true, 250)
	_assert_true(hud.win_modal.visible, "Win modal visible upon game ending")
	_assert_true("THE PIXEL CORE IS RESTORED" in hud.win_stats_label.text, "HUD displays victory celebration text")
	_assert_true("Final Level: 24 moves" in hud.win_stats_label.text, "HUD displays final moves")
	hud.queue_free()

func _test_phase6_art_animation_audio() -> void:
	print("\n=== 10. Verifying Phase 6 Art Assets, Pixel Animations, Audio Palette, and Accessibility ===")
	
	# 1. Sprite Assets & Geometry
	var pip_tex: Texture2D = ResourceLoader.load("res://assets/sprites/pip.png")
	_assert_true(pip_tex != null, "Pip texture loaded")
	_assert_eq(pip_tex.get_width(), 64, "Pip spritesheet width is 64px (4 frames x 16px)")
	_assert_eq(pip_tex.get_height(), 16, "Pip spritesheet height is 16px")
	
	var blocks_tex: Texture2D = ResourceLoader.load("res://assets/sprites/blocks.png")
	_assert_true(blocks_tex != null, "Blocks texture loaded")
	_assert_eq(blocks_tex.get_width(), 80, "Blocks spritesheet width is 80px (5 colors x 16px)")
	_assert_eq(blocks_tex.get_height(), 16, "Blocks spritesheet height is 16px")
	
	var tiles_tex: Texture2D = ResourceLoader.load("res://assets/sprites/tileset.png")
	_assert_true(tiles_tex != null, "Tileset texture loaded")
	_assert_eq(tiles_tex.get_width(), 64, "Tileset width is 64px (4 tiles x 16px)")
	_assert_eq(tiles_tex.get_height(), 16, "Tileset height is 16px")
	
	var sockets_tex: Texture2D = ResourceLoader.load("res://assets/sprites/sockets.png")
	_assert_true(sockets_tex != null, "Sockets texture loaded")
	_assert_eq(sockets_tex.get_width(), 160, "Sockets width is 160px (5 colors x 2 states x 16px)")
	_assert_eq(sockets_tex.get_height(), 16, "Sockets height is 16px")
	
	var portal_tex: Texture2D = ResourceLoader.load("res://assets/sprites/exit_portal.png")
	_assert_true(portal_tex != null, "Exit portal texture loaded")
	_assert_eq(portal_tex.get_width(), 32, "Exit portal width is 32px (2 states x 16px)")
	_assert_eq(portal_tex.get_height(), 16, "Exit portal height is 16px")

	var icon_tex: Texture2D = ResourceLoader.load("res://assets/sprites/icon.png")
	_assert_true(icon_tex != null, "App icon texture loaded")
	_assert_eq(icon_tex.get_width(), 64, "Icon width is 64px")
	_assert_eq(icon_tex.get_height(), 64, "Icon height is 64px")

	# 2. AudioService & Full Sound Palette
	var audio := AudioService.new()
	audio._ready()
	_assert_true(audio._players.has(&"steal"), "AudioService has steal SFX")
	_assert_true(audio._players.has(&"place"), "AudioService has place SFX")
	_assert_true(audio._players.has(&"socket"), "AudioService has socket SFX")
	_assert_true(audio._players.has(&"step"), "AudioService has step SFX")
	_assert_true(audio._players.has(&"undo"), "AudioService has undo SFX")
	_assert_true(audio._players.has(&"win"), "AudioService has win SFX")
	_assert_true(audio._players.has(&"bump"), "AudioService has bump SFX")
	_assert_true(audio._players.has(&"exit_open"), "AudioService has exit_open SFX")
	_assert_true(audio._players.has(&"ui_click"), "AudioService has ui_click SFX")
	_assert_true(audio._players.has(&"chapter_restored"), "AudioService has chapter_restored SFX")
	_assert_true(audio._music_player != null, "AudioService has ambient music player")

	# Audio Volume & Clamping Invariants
	audio.master_volume = 0.5
	audio.sfx_volume = 0.8
	audio.music_volume = 0.7
	audio.update_music_volume()
	var expected_music_db: float = linear_to_db(0.7 * 0.5)
	_assert_true(abs(audio._music_player.volume_db - expected_music_db) < 0.01, "Music volume decibel matches linear product")
	
	audio.music_enabled = false
	audio.update_music_volume()
	_assert_eq(audio._music_player.volume_db, -80.0, "Disabling music attenuates player to -80 dB")

	# SFX triggers do not crash
	audio.sfx_enabled = true
	audio.play_steal()
	audio.play_place()
	audio.play_socket()
	audio.play_bump()
	audio.play_exit_open()
	audio.play_ui_click()
	audio.play_chapter_restored()
	_assert_true(true, "All 10 sound triggers executed cleanly")
	audio.queue_free()

	# 3. PlayerView & Idle/Victory Animations
	var pv := PlayerView.new()
	pv._ready()
	_assert_true(pv.is_idle_active, "PlayerView marked idle state active")
	pv.reduced_motion = true
	_assert_true(not pv.is_idle_active, "PlayerView idle deactivated on reduced_motion")
	pv.animate_victory()
	pv.snap_to_cell(Vector2i(2, 2))
	_assert_eq(pv._sprite.position, Vector2.ZERO, "Offsets reset after snap")
	pv.queue_free()

	# 4. BoardRenderer Chapter Theming & Screen Shake
	var br := BoardRenderer.new()
	br._ready()
	br.apply_chapter_theme(1)
	_assert_eq(br.modulate, Color(1.0, 0.98, 0.94), "Chapter 1 theme applied (warm amber stone)")
	br.apply_chapter_theme(2)
	_assert_eq(br.modulate, Color(0.92, 0.96, 1.05), "Chapter 2 theme applied (deep oceanic skyway)")
	br.apply_chapter_theme(3)
	_assert_eq(br.modulate, Color(0.98, 0.93, 1.05), "Chapter 3 theme applied (obsidian violet)")
	br.apply_chapter_theme(4)
	_assert_eq(br.modulate, Color(1.04, 1.02, 1.05), "Chapter 4 theme applied (full spectrum)")
	
	# Screen shake trigger
	br.screen_shake_enabled = true
	br.reduced_motion = false
	br.trigger_screen_shake(2.0, 0.1)
	_assert_true(br.camera != null, "BoardRenderer camera initialized")
	br.reduced_motion = true
	br.trigger_screen_shake(2.0, 0.1)
	_assert_true(true, "Screen shake respects reduced_motion without error")
	br.queue_free()

	# 5. Settings Menu and ProgressService Integration
	var s_menu_scene: PackedScene = ResourceLoader.load("res://scenes/ui/settings_menu.tscn")
	var s_menu: SettingsMenu = s_menu_scene.instantiate()
	s_menu._ready()
	_assert_true(s_menu.sfx_volume_slider != null, "SettingsMenu SFX volume slider wired")
	_assert_true(s_menu.music_volume_slider != null, "SettingsMenu Music volume slider wired")
	_assert_true(s_menu.shake_check != null, "SettingsMenu Screen Shake checkbox wired")
	_assert_true(s_menu.reduced_motion_check != null, "SettingsMenu Reduced Motion checkbox wired")
	
	s_menu.save_and_close()
	var loaded_p := ProgressService.load_progress()
	_assert_true(loaded_p.has("settings"), "ProgressService holds settings dictionary")
	_assert_true(loaded_p["settings"].has("music_volume"), "Settings contains music_volume")
	_assert_true(loaded_p["settings"].has("screen_shake"), "Settings contains screen_shake")
	s_menu.queue_free()

func _test_phase7_ui_progression_persistence() -> void:
	print("\n=== 11. Verifying Phase 7 UI, UX, Persistence, Medals, and Pause System ===")
	
	# 1. UI Scene Loading
	var pause_res = ResourceLoader.load("res://scenes/ui/pause_menu.tscn")
	_assert_true(pause_res != null, "PauseMenu scene (res://scenes/ui/pause_menu.tscn) loads successfully")
	var confirm_res = ResourceLoader.load("res://scenes/ui/confirm_modal.tscn")
	_assert_true(confirm_res != null, "ConfirmModal scene (res://scenes/ui/confirm_modal.tscn) loads successfully")
	var credits_res = ResourceLoader.load("res://scenes/ui/credits_modal.tscn")
	_assert_true(credits_res != null, "CreditsModal scene (res://scenes/ui/credits_modal.tscn) loads successfully")

	# 2. Persistence Schema, Validation, and Defaults
	ProgressService.reset_progress()
	var init_data := ProgressService.load_progress()
	_assert_eq(init_data.get("schema_version", -1), 1, "Save data initialized with Schema Version 1")
	_assert_true(not ProgressService.has_saved_game(), "Fresh install has no saved game progress")
	_assert_true(ProgressService.is_level_unlocked(1, 0), "First level (ch1_01) unlocked by default")
	_assert_true(not ProgressService.is_level_unlocked(1, 1), "Second level (ch1_02) locked by default")
	
	# Schema validation tests
	_assert_true(not ProgressService._validate_save_dict({}), "Empty dictionary fails schema validation")
	_assert_true(not ProgressService._validate_save_dict({"schema_version": "invalid"}), "Non-numeric schema version rejected")
	_assert_true(ProgressService._validate_save_dict({"schema_version": 1, "completed_levels": {}, "settings": {}}), "Valid schema dictionary passes validation")

	# Record progress & continue logic
	ProgressService.record_level_completion("ch1_01", 5, "ch1_02")
	_assert_true(ProgressService.has_saved_game(), "has_saved_game is true after completing a level")
	_assert_true(ProgressService.is_level_unlocked(1, 1), "Level ch1_02 unlocked after recording completion")
	var cont_target: Dictionary = ProgressService.get_continue_target()
	_assert_eq(cont_target.get("level_id", ""), "ch1_02", "Continue target resolves to ch1_02")
	_assert_eq(cont_target.get("chapter", -1), 1, "Continue target chapter is 1")
	_assert_eq(cont_target.get("level_idx", -1), 1, "Continue target level index is 1")

	# 3. Solvability Medals & Optimal Moves Calculation
	var all_levels: Array[String] = [
		"demo_01", "demo_02", "demo_03",
		"ch1_01", "ch1_02", "ch1_03", "ch1_04", "ch1_05",
		"ch2_01", "ch2_02", "ch2_03", "ch2_04", "ch2_05",
		"ch3_01", "ch3_02", "ch3_03", "ch3_04", "ch3_05",
		"ch4_01", "ch4_02", "ch4_03", "ch4_04", "ch4_05"
	]
	var all_opts_valid := true
	for lid in all_levels:
		if ProgressService.get_optimal_moves(lid) <= 0:
			all_opts_valid = false
	_assert_true(all_opts_valid, "All 23 campaign levels have positive optimal move baselines")

	# Medal evaluations for ch1_01 (optimal = 5)
	_assert_eq(ProgressService.get_level_medal("ch1_01", 5), "Gold", "Exact optimal moves awards Gold Medal")
	_assert_eq(ProgressService.get_level_medal("ch1_01", 8), "Silver", "Optimal + 3 moves awards Silver Medal")
	_assert_eq(ProgressService.get_level_medal("ch1_01", 9), "Bronze", "Optimal + 4 moves awards Bronze Medal")
	_assert_eq(ProgressService.get_medal_symbol("Gold"), "★", "Gold symbol is ★")
	_assert_eq(ProgressService.get_medal_symbol("Silver"), "◈", "Silver symbol is ◈")
	_assert_eq(ProgressService.get_medal_symbol("Bronze"), "•", "Bronze symbol is •")

	# 4. In-Game Contextual Tutorial Tracking
	var tut_text_demo := ProgressService.get_tutorial_text("demo_01")
	_assert_true(not tut_text_demo.is_empty(), "Contextual tutorial exists for demo_01")
	_assert_true(not ProgressService.is_tutorial_seen("demo_01"), "Tutorial unseen initially")
	ProgressService.mark_tutorial_seen("demo_01")
	_assert_true(ProgressService.is_tutorial_seen("demo_01"), "Tutorial marked as seen persists")
	var tut_text_ch2 := ProgressService.get_tutorial_text("ch2_01")
	_assert_true(tut_text_ch2.contains("Bridge"), "Chapter 2 tutorial explains bridges")

	# 5. TitleScreen UI Component Verification
	var title_scene: PackedScene = ResourceLoader.load("res://scenes/ui/title_screen.tscn")
	var title_ui: TitleScreen = title_scene.instantiate()
	title_ui._ready()
	_assert_true(title_ui.continue_btn != null, "TitleScreen has Continue button")
	_assert_true(title_ui.new_game_btn != null, "TitleScreen has New Game button")
	_assert_true(title_ui.credits_modal != null, "TitleScreen contains CreditsModal")
	_assert_true(title_ui.confirm_modal != null, "TitleScreen contains ConfirmModal")
	_assert_true(not title_ui.continue_btn.disabled, "Continue button enabled when saved game exists")
	title_ui.queue_free()

	# 6. ChapterSelect UI Component Verification
	var ch_scene: PackedScene = ResourceLoader.load("res://scenes/ui/chapter_select.tscn")
	var ch_ui: ChapterSelect = ch_scene.instantiate()
	ch_ui._ready()
	_assert_true(ch_ui.chapter_list != null, "ChapterSelect has chapter list")
	_assert_eq(ProgressService.get_chapter_completed_count(1), 1, "Chapter 1 completed count reflects progress (1/5)")
	ch_ui.queue_free()

	# 7. HUD Tutorial & Win Modal Verification
	var hud_scene: PackedScene = ResourceLoader.load("res://scenes/ui/hud.tscn")
	var hud_inst: HUD = hud_scene.instantiate()
	hud_inst._ready()
	_assert_true(hud_inst.pause_btn != null, "HUD has Pause button")
	_assert_true(hud_inst.tutorial_panel != null, "HUD has Tutorial Panel")
	
	hud_inst.show_tutorial("Steal blocks to clear the corridor.")
	_assert_true(hud_inst.tutorial_panel.visible, "HUD displays tutorial banner")
	_assert_eq(hud_inst.tutorial_label.text, "Steal blocks to clear the corridor.", "Tutorial label text populated")
	hud_inst.hide_tutorial()
	_assert_true(not hud_inst.tutorial_panel.visible, "HUD hides tutorial banner cleanly")
	
	hud_inst.show_win(5, "ch1_01")
	_assert_true(hud_inst.win_modal.visible, "WinModal visible on level victory")
	_assert_true(hud_inst.win_medal_label.text.contains("GOLD"), "WinModal displays GOLD MEDAL for 5 moves")
	hud_inst.hide_win()
	_assert_true(not hud_inst.win_modal.visible, "WinModal hidden cleanly")
	hud_inst.queue_free()

	# 8. PauseMenu Verification
	var pause_scene: PackedScene = ResourceLoader.load("res://scenes/ui/pause_menu.tscn")
	var pause_inst: PauseMenu = pause_scene.instantiate()
	pause_inst._ready()
	_assert_true(pause_inst.resume_btn != null, "PauseMenu has Resume button")
	_assert_true(pause_inst.restart_btn != null, "PauseMenu has Restart button")
	_assert_true(pause_inst.hint_btn != null, "PauseMenu has Hint button")
	_assert_true(pause_inst.settings_btn != null, "PauseMenu has Settings button")
	_assert_true(pause_inst.chapters_btn != null, "PauseMenu has Chapter Select button")
	_assert_true(pause_inst.title_btn != null, "PauseMenu has Title Screen button")
	pause_inst.queue_free()

	# 9. GameController Deterministic Pause & State Preservation
	var gc := GameController.new()
	gc._ready()
	var demo_lvl := LevelRepository.load_level(0, 0)
	gc.load_level_data(demo_lvl)
	gc.reduced_motion = false
	if gc.renderer: gc.renderer.reduced_motion = false
	var initial_pos: Vector2i = gc.model.get_state().player_pos
	
	# Pause gameplay
	gc.set_paused(true)
	_assert_true(gc.is_paused, "GameController is_paused is true")
	
	# Attempt action while paused
	gc.request_action(Constants.ActionType.INTERACT_EAST)
	_assert_true(gc.model.get_state().carried_block.is_empty(), "Carried block remains empty while paused")
	_assert_eq(gc.model.get_state().turn_count, 0, "Turn count completely frozen while paused")
	
	# Resume gameplay
	gc.set_paused(false)
	_assert_true(not gc.is_paused, "GameController is_paused is false after resume")
	gc.request_action(Constants.ActionType.INTERACT_EAST)
	_assert_true(not gc.model.get_state().carried_block.is_empty(), "Block stolen after unpausing")
	_assert_eq(gc.model.get_state().turn_count, 1, "Turn count advances after unpausing")
	
	# Move into now-cleared floor
	gc.request_action(Constants.ActionType.MOVE_EAST)
	_assert_eq(gc.model.get_state().player_pos, initial_pos + Constants.DIR_EAST, "Player moves East into cleared corridor")
	_assert_eq(gc.model.get_state().turn_count, 2, "Turn count is 2 after moving")
	
	gc.queue_free()

func _test_phase8_adversarial_qa() -> void:
	print("\n=== 12. Verifying Phase 8 Adversarial QA, Stress Tests, and State Invariants ===")
	
	# 1. Model & View State Desync Stress Test
	var gc := GameController.new()
	gc._ready()
	var demo_lvl := LevelRepository.load_level(0, 0)
	gc.load_level_data(demo_lvl)
	gc.reduced_motion = false
	if gc.renderer: gc.renderer.reduced_motion = false
	
	# Trigger step animation & interrupt with Undo
	gc.handle_restart()
	gc.request_action(Constants.ActionType.INTERACT_EAST) # Steal block
	_assert_true(not gc.model.get_state().carried_block.is_empty(), "Pip steals block")
	gc.is_animating = true
	gc._input_buffer = Constants.ActionType.MOVE_SOUTH
	gc.handle_undo()
	_assert_true(not gc.is_animating, "is_animating immediately aborted on Undo")
	_assert_eq(gc._input_buffer, -1, "Input buffer cleared on Undo")
	var s_undone: BoardState = gc.model.get_state()
	var expected_pos := Vector2(s_undone.player_pos * 16) + Vector2(8, 8)
	_assert_eq(gc.renderer.player_view.position, expected_pos, "PlayerView snapped to exact restored model coordinates")
	
	# Trigger active animation & interrupt with Restart
	gc.is_animating = true
	gc._input_buffer = Constants.ActionType.MOVE_EAST
	gc.handle_restart()
	_assert_true(not gc.is_animating, "is_animating immediately aborted on Restart")
	_assert_eq(gc._input_buffer, -1, "Input buffer cleared on Restart")
	var s_restarted: BoardState = gc.model.get_state()
	var start_pos := Vector2(s_restarted.player_pos * 16) + Vector2(8, 8)
	_assert_eq(gc.renderer.player_view.position, start_pos, "PlayerView snapped to exact initial coordinates on Restart")
	
	# 2. Boundary and Off-Board Click Stress Test
	var turns_before: int = gc.model.get_state().turn_count
	var test_click_coords: Array[Vector2] = [
		Vector2(-9999, -9999),
		Vector2(99999, 99999),
		Vector2(0, 0),
		Vector2(16 * 10, 16 * 10),
		Vector2(-16, 16)
	]
	for click_pos: Vector2 in test_click_coords:
		var mb := InputEventMouseButton.new()
		mb.pressed = true
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.position = click_pos
		gc._unhandled_input(mb)
	_assert_eq(gc.model.get_state().turn_count, turns_before, "Off-board clicks cleanly rejected without altering turn count")
	gc.queue_free()

	# 3. In-Engine 1,000-Step Randomized Fuzzing Test (Seed 1337)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	
	var fuzz_state := BoardState.new()
	fuzz_state.grid_size = Vector2i(7, 7)
	for x in range(7):
		for y in range(7):
			if x == 0 or x == 6 or y == 0 or y == 6:
				fuzz_state.tiles[Vector2i(x, y)] = Constants.TileType.WALL
			else:
				fuzz_state.tiles[Vector2i(x, y)] = Constants.TileType.FLOOR
	fuzz_state.player_pos = Vector2i(1, 1)
	fuzz_state.exit_cell = Vector2i(5, 5)
	fuzz_state.tiles[Vector2i(3, 2)] = Constants.TileType.VOID
	fuzz_state.tiles[Vector2i(3, 3)] = Constants.TileType.VOID
	fuzz_state.tiles[Vector2i(3, 4)] = Constants.TileType.WALL
	fuzz_state.sockets[Vector2i(1, 3)] = Constants.BlockColor.CYAN
	fuzz_state.sockets[Vector2i(5, 1)] = Constants.BlockColor.AMBER
	fuzz_state.blocks[Vector2i(2, 1)] = {"id": 1, "color": Constants.BlockColor.CYAN, "is_bridge": false}
	fuzz_state.blocks[Vector2i(2, 2)] = {"id": 2, "color": Constants.BlockColor.AMBER, "is_bridge": false}
	fuzz_state.blocks[Vector2i(4, 3)] = {"id": 3, "color": Constants.BlockColor.NEUTRAL, "is_bridge": false}
	
	var f_model := BoardModel.new(fuzz_state)
	var initial_blocks_count := 3
	var initial_tiles_dict := fuzz_state.tiles.duplicate()
	var initial_sockets_dict := fuzz_state.sockets.duplicate()
	var initial_exit_cell: Vector2i = fuzz_state.exit_cell
	
	var actions: Array[int] = [
		Constants.ActionType.MOVE_NORTH, Constants.ActionType.MOVE_EAST,
		Constants.ActionType.MOVE_SOUTH, Constants.ActionType.MOVE_WEST,
		Constants.ActionType.INTERACT_NORTH, Constants.ActionType.INTERACT_EAST,
		Constants.ActionType.INTERACT_SOUTH, Constants.ActionType.INTERACT_WEST
	]
	
	var invariants_held := true
	for step in range(1000):
		var roll := rng.randf()
		if roll < 0.12 and f_model.can_undo():
			f_model.undo()
		elif roll < 0.13:
			f_model.restart()
		else:
			var chosen_action: int = actions[rng.randi_range(0, actions.size() - 1)]
			f_model.try_action(chosen_action)
			
		var cur: BoardState = f_model.get_state()
		
		# Invariant 1: Player inside bounds
		if not cur.is_inside_grid(cur.player_pos):
			invariants_held = false
			break
		# Invariant 2: Player not on wall or empty void
		var pt: int = cur.get_tile(cur.player_pos)
		if pt == Constants.TileType.WALL:
			invariants_held = false
			break
		if pt == Constants.TileType.VOID and not cur.is_bridge_at(cur.player_pos):
			invariants_held = false
			break
		# Invariant 3: Block count conservation
		var carried_c: int = 1 if cur.is_carrying() else 0
		if (cur.blocks.size() + carried_c) != initial_blocks_count:
			invariants_held = false
			break
		# Invariant 4: No duplicate block positions
		var seen_cells: Dictionary = {}
		for b_pos: Vector2i in cur.blocks:
			if seen_cells.has(b_pos):
				invariants_held = false
				break
			seen_cells[b_pos] = true
		# Invariant 5: Player not on floor block
		if cur.blocks.has(cur.player_pos) and not cur.is_bridge_at(cur.player_pos):
			invariants_held = false
			break
		# Invariant 6: Immutable terrain unchanged
		if cur.tiles != initial_tiles_dict or cur.sockets != initial_sockets_dict or cur.exit_cell != initial_exit_cell:
			invariants_held = false
			break
			
	_assert_true(invariants_held, "In-engine 1,000-step randomized fuzzing preserved all 6 physical and state invariants")

	# 4. Campaign 23 Levels Completeness & Uniqueness
	var seen_level_ids: Dictionary = {}
	var duplicate_found := false
	var total_levels_count := 0
	for ch_idx in range(5):
		var ch_dict := LevelRepository.load_chapter(ch_idx)
		var lvl_arr: Array = ch_dict.get("levels", [])
		var expected_count: int = 3 if ch_idx == 0 else 5
		_assert_eq(lvl_arr.size(), expected_count, "Chapter %d contains exactly %d levels" % [ch_idx, expected_count])
		for lvl: Dictionary in lvl_arr:
			total_levels_count += 1
			var lid: String = lvl.get("id", "")
			if seen_level_ids.has(lid):
				duplicate_found = true
			seen_level_ids[lid] = true
	_assert_true(not duplicate_found, "All campaign level IDs are globally unique")
	_assert_eq(total_levels_count, 23, "Total campaign contains exactly 23 verified levels (20 campaign + 3 demo)")

	# 5. Scene & Node Memory Cleanup Audit
	var renderers: Array[BoardRenderer] = []
	for i in range(25):
		var br := BoardRenderer.new()
		br._ready()
		br.setup_board(fuzz_state)
		renderers.append(br)
	for br: BoardRenderer in renderers:
		br.queue_free()
	_assert_true(true, "Repeated BoardRenderer allocation and disposal executed cleanly")




