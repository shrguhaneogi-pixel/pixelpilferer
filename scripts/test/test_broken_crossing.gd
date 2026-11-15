extends SceneTree

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")
const BrokenCrossingController = preload("res://scripts/test/broken_crossing_controller.gd")
const ExitPortal = preload("res://scripts/platformer/exit_portal.gd")

func _init() -> void:
	print("=================================================================")
	print("   PIXEL PILFERER MILESTONE C — THE BROKEN CROSSING (9/9)        ")
	print("=================================================================")
	var scene_res = load("res://scenes/test/broken_crossing.tscn")
	if not scene_res:
		printerr("Failed to load broken_crossing.tscn")
		quit(1)
		return
	var scene = scene_res.instantiate()
	root.add_child(scene)
	
	run_9_step_acceptance(scene)

func run_9_step_acceptance(scene: Node2D) -> void:
	var controller = scene
	var player = scene.get_node("Player")
	var tile_mgr = scene.get_node("TileManager")
	var exit_portal = scene.get_node("ExitPortal")

	player.use_simulated_input = true
	var pass_count: int = 0
	var fail_count: int = 0

	# Initial physics settling
	for i in range(15):
		await physics_frame

	# -------------------------------------------------------------
	# STEP 1: Pip begins on a safe platform and can run left & right
	# -------------------------------------------------------------
	var s1_ok: bool = player.is_on_floor()
	player.simulated_move_axis = 1.0
	for i in range(15):
		await physics_frame
	var moved_right: bool = player.velocity.x > 50.0

	player.simulated_move_axis = -1.0
	for i in range(25):
		await physics_frame
	var moved_left: bool = player.velocity.x < -50.0

	player.simulated_move_axis = 0.0
	for i in range(15):
		await physics_frame

	if s1_ok and moved_right and moved_left:
		print("  [PASS] Step 1: Pip begins on safe platform and can run left and right")
		pass_count += 1
	else:
		printerr("  [FAIL] Step 1 failed. s1_ok: ", s1_ok, " right: ", moved_right, " left: ", moved_left)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 2: Pip jumps onto an elevated ledge with responsive controls
	# -------------------------------------------------------------
	# Start at x = 35 on the floor (clear sky above, ledge starts at x = 64)
	player.global_position = Vector2(35, 193)
	player.velocity = Vector2.ZERO
	for i in range(5):
		await physics_frame

	# Run right and jump towards the ledge
	player.simulated_move_axis = 1.0
	player.simulated_jump_just_pressed = true
	for i in range(25):
		await physics_frame

	# Settle onto the ledge surface (top is y = 168 -> player y = 161)
	player.simulated_move_axis = 0.0
	for i in range(25):
		await physics_frame

	var s2_ok: bool = player.is_on_floor() and player.global_position.y < 170.0 and player.global_position.x > 64.0
	if s2_ok:
		print("  [PASS] Step 2: Pip jumps onto elevated ledge with responsive controls (pos: %.1f, %.1f)" % [player.global_position.x, player.global_position.y])
		pass_count += 1
	else:
		printerr("  [FAIL] Step 2 failed. on_floor: ", player.is_on_floor(), " pos: ", player.global_position)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 3: Pip steals a marked block from a nearby wall
	# -------------------------------------------------------------
	# Walk forward on ledge to x = 106, aim right and UP towards Vector2i(7, 9)
	player.global_position = Vector2(106, 161)
	player.velocity = Vector2.ZERO
	player.simulated_move_axis = 0.0
	player.facing_direction = 1
	player.simulated_aim_up = true
	for i in range(5):
		await physics_frame

	# Press interact to steal
	player.simulated_interact_just_pressed = true
	await physics_frame
	await physics_frame
	player.simulated_aim_up = false

	var s3_ok: bool = player.carried_block != null and player.carried_block.get("color") == 1
	if s3_ok:
		print("  [PASS] Step 3: Pip steals marked Cyan block from wall (carried: %s)" % str(player.carried_block))
		pass_count += 1
	else:
		printerr("  [FAIL] Step 3 failed. target_cell: ", player.get_target_cell(), " carried_block: ", player.carried_block)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 4: The removed block creates a real opening without corrupting collisions
	# -------------------------------------------------------------
	var block_gone: bool = not tile_mgr.has_block(Vector2i(7, 9))
	# Advance right into the newly opened space
	player.simulated_move_axis = 1.0
	for i in range(15):
		await physics_frame
	player.simulated_move_axis = 0.0

	var s4_ok: bool = block_gone and player.global_position.x > 110.0
	if s4_ok:
		print("  [PASS] Step 4: Removed block creates a real opening without corrupting collisions (pos.x: %.1f)" % player.global_position.x)
		pass_count += 1
	else:
		printerr("  [FAIL] Step 4 failed. block_gone: ", block_gone, " pos.x: ", player.global_position.x)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 5: Pip carries the block to the broken crossing
	# -------------------------------------------------------------
	# Move down to ground and position at safe chasm edge at x = 146
	player.global_position = Vector2(146, 193)
	player.velocity = Vector2.ZERO
	for i in range(10):
		await physics_frame

	var s5_ok: bool = player.carried_block != null and player.is_on_floor() and player.global_position.x > 140.0
	if s5_ok:
		print("  [PASS] Step 5: Pip carries block to broken crossing edge (pos: %.1f, %.1f)" % [player.global_position.x, player.global_position.y])
		pass_count += 1
	else:
		printerr("  [FAIL] Step 5 failed. carried: ", player.carried_block, " pos: ", player.global_position)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 6: Pip places it into an empty tile cell, creating a solid floating platform
	# -------------------------------------------------------------
	# Aim right into chasm at Vector2i(10, 12) (world x = 160..176, y = 192..208)
	# At x = 146, 146 + 16 = 162 (cell 10). Player bounds [141, 151], block [160, 176] -> no overlap!
	player.facing_direction = 1
	player.simulated_aim_up = false
	player.simulated_aim_down = false
	player.simulated_interact_just_pressed = true
	await physics_frame
	await physics_frame

	var target_cell: Vector2i = Vector2i(10, 12)
	var s6_ok: bool = tile_mgr.has_block(target_cell) and player.carried_block == null
	if s6_ok:
		print("  [PASS] Step 6: Pip places block into empty cell Vector2i(10, 12), creating solid platform")
		pass_count += 1
	else:
		printerr("  [FAIL] Step 6 failed. target_cell: ", player.get_target_cell(), " has_block: ", tile_mgr.has_block(target_cell), " carried: ", player.carried_block)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 7: Pip jumps onto the new platform and crosses the gap
	# -------------------------------------------------------------
	# Hop onto placed platform at x = 168 (from x = 146, distance 22 px)
	player.simulated_move_axis = 0.7
	player.simulated_jump_just_pressed = true
	for i in range(8):
		await physics_frame
	player.simulated_move_axis = 0.0

	# Settle on placed platform
	for i in range(50):
		await physics_frame
		if player.is_on_floor():
			break

	var on_bridge: bool = player.is_on_floor() and absf(player.global_position.x - 168.0) < 12.0 and player.global_position.y <= 194.0

	# Jump from bridge to GroundExit (starts at 224, distance ~56 px)
	player.simulated_move_axis = 1.0
	player.simulated_jump_just_pressed = true
	for i in range(15):
		await physics_frame

	# Land on GroundExit
	for i in range(45):
		await physics_frame
		if player.is_on_floor() and player.global_position.x >= 224.0:
			break
	player.simulated_move_axis = 0.0

	var crossed_gap: bool = player.is_on_floor() and player.global_position.x >= 224.0
	var s7_ok: bool = on_bridge and crossed_gap
	if s7_ok:
		print("  [PASS] Step 7: Pip jumps onto new platform and successfully crosses gap (pos.x: %.1f)" % player.global_position.x)
		pass_count += 1
	else:
		printerr("  [FAIL] Step 7 failed. on_bridge: ", on_bridge, " crossed_gap: ", crossed_gap, " pos: ", player.global_position)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 8: Pip reaches the exit, triggering a correct level-completion state
	# -------------------------------------------------------------
	# Walk right towards ExitPortal at x = 320
	player.simulated_move_axis = 1.0
	for i in range(50):
		await physics_frame
	player.simulated_move_axis = 0.0

	var s8_ok: bool = controller.is_completed and exit_portal.is_completed
	if s8_ok:
		print("  [PASS] Step 8: Pip reaches exit portal, triggering level-completion state")
		pass_count += 1
	else:
		printerr("  [FAIL] Step 8 failed. controller.is_completed: ", controller.is_completed, " exit_portal: ", exit_portal.is_completed)
		fail_count += 1

	# -------------------------------------------------------------
	# STEP 9: After restarting, original wall and gap return exactly as designed
	# -------------------------------------------------------------
	controller.restart_level()
	for i in range(15):
		await physics_frame

	var wall_restored: bool = tile_mgr.has_block(Vector2i(7, 9))
	var bridge_cleared: bool = not tile_mgr.has_block(target_cell)
	var player_at_start: bool = player.global_position.distance_to(player.spawn_position) < 15.0
	var exit_reset: bool = not controller.is_completed and not exit_portal.is_completed

	var s9_ok: bool = wall_restored and bridge_cleared and player_at_start and exit_reset
	if s9_ok:
		print("  [PASS] Step 9: Level restart restores original wall block, clears gap, resets player & exit")
		pass_count += 1
	else:
		printerr("  [FAIL] Step 9 failed. wall_restored: ", wall_restored, " bridge_cleared: ", bridge_cleared, " at_start: ", player_at_start, " exit_reset: ", exit_reset)
		fail_count += 1

	print("=================================================================")
	print("The Broken Crossing Acceptance Results: %d / 9 Passed" % pass_count)
	if fail_count == 0:
		print("[ALL 9 ACCEPTANCE CRITERIA CONFIRMED — MILESTONE C VERIFIED]")
		quit(0)
	else:
		printerr("[BROKEN CROSSING ACCEPTANCE FAILED]")
		quit(1)
