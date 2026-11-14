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
