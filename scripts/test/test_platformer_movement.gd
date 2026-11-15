extends SceneTree

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")

func _init() -> void:
	print("=======================================================")
	print("   PIXEL PILFERER MILESTONE B — MOVEMENT PROTOTYPE     ")
	print("=======================================================")
	var scene_res = load("res://scenes/test/platformer_prototype.tscn")
	if not scene_res:
		printerr("Failed to load platformer_prototype.tscn")
		quit(1)
		return
	var scene = scene_res.instantiate()
	root.add_child(scene)
	
	run_all_tests(scene)

func run_all_tests(scene: Node2D) -> void:
	var player: PlayerPlatformer = scene.get_node("Player") as PlayerPlatformer
	if not player:
		printerr("Player node not found")
		quit(1)
		return

	player.use_simulated_input = true
	var pass_count: int = 0
	var fail_count: int = 0

	# Let player settle on floor
	for i in range(15):
		await physics_frame

	# Assertion 1: Settles on floor
	if player.is_on_floor():
		print("  [PASS] 1. Player settles on floor (pos: %.1f, %.1f)" % [player.global_position.x, player.global_position.y])
		pass_count += 1
	else:
		printerr("  [FAIL] 1. Player not on floor, pos: ", player.global_position)
		fail_count += 1

	# Assertion 2: Acceleration to right
	player.simulated_move_axis = 1.0
	for i in range(30): # 0.5 seconds at 60 fps
		await physics_frame

	if is_equal_approx(player.velocity.x, PlayerPlatformer.RUN_SPEED):
		print("  [PASS] 2. Horizontal acceleration reaches max run speed (120 px/s)")
		pass_count += 1
	else:
		printerr("  [FAIL] 2. Velocity X expected 120, got: ", player.velocity.x)
		fail_count += 1

	# Assertion 3: Deceleration to stop
	player.simulated_move_axis = 0.0
	for i in range(25):
		await physics_frame

	if is_zero_approx(player.velocity.x):
		print("  [PASS] 3. Friction brings player to a complete stop (pos.x: %.1f)" % player.global_position.x)
		pass_count += 1
	else:
		printerr("  [FAIL] 3. Velocity X did not stop, got: ", player.velocity.x)
		fail_count += 1

	# Assertion 4: Jump height reaches peak
	var start_y: float = player.global_position.y
	player.simulated_jump_just_pressed = true
	var min_y: float = start_y

	# Track peak jump height
	for i in range(35):
		await physics_frame
		if player.global_position.y < min_y:
			min_y = player.global_position.y

	var jump_height: float = start_y - min_y
	# Target jump height is ~40.8 px (between 38 and 43 px)
	if jump_height >= 38.0 and jump_height <= 43.0:
		print("  [PASS] 4. Jump height reaches design peak: %.2f px (design: ~40.8 px)" % jump_height)
		pass_count += 1
	else:
		printerr("  [FAIL] 4. Jump height out of expected range: %.2f px" % jump_height)
		fail_count += 1

	# Let player land back on floor
	for i in range(30):
		await physics_frame

	if player.is_on_floor():
		print("  [PASS] 5. Player landed back on floor safely")
		pass_count += 1
	else:
		printerr("  [FAIL] 5. Player not on floor after jump, pos: ", player.global_position)
		fail_count += 1

	# Assertion 6: Variable jump cutoff (short hop)
	start_y = player.global_position.y
	player.simulated_jump_just_pressed = true
	await physics_frame
	await physics_frame
	# Early release
	player.simulated_jump_just_released = true
	min_y = start_y

	for i in range(30):
		await physics_frame
		if player.global_position.y < min_y:
			min_y = player.global_position.y

	var short_jump_height: float = start_y - min_y
	if short_jump_height < 25.0 and short_jump_height > 8.0:
		print("  [PASS] 6. Variable jump height cutoff confirmed: %.2f px (short hop < 25 px)" % short_jump_height)
		pass_count += 1
	else:
		printerr("  [FAIL] 6. Short jump height out of expected cutoff range: %.2f px" % short_jump_height)
		fail_count += 1

	# Settle back on floor
	for i in range(25):
		await physics_frame

	# Assertion 7: Wall collision stopping
	# Move towards Wall at x = 280
	player.simulated_move_axis = 1.0
	for i in range(120): # Run right towards wall
		await physics_frame

	# Player should be stopped by wall at x ≈ 267.0
	if player.global_position.x < 275.0 and player.global_position.x > 260.0 and player.is_on_wall():
		print("  [PASS] 7. Wall collision stops player without penetration (pos.x = %.2f, is_on_wall = true)" % player.global_position.x)
		pass_count += 1
	else:
		printerr("  [FAIL] 7. Wall collision failure, pos.x: ", player.global_position.x, " is_on_wall: ", player.is_on_wall())
		fail_count += 1

	# Assertion 8: Terminal velocity clamping
	player.global_position = Vector2(50, -500)
	player.velocity = Vector2.ZERO
	for i in range(60): # 1 second fall
		await physics_frame

	if player.velocity.y <= PlayerPlatformer.TERMINAL_VELOCITY + 0.1:
		print("  [PASS] 8. Terminal velocity clamped at: %.2f px/s (max: 340 px/s)" % player.velocity.y)
		pass_count += 1
	else:
		printerr("  [FAIL] 8. Terminal velocity exceeded: ", player.velocity.y)
		fail_count += 1

	# Assertion 9: Pit death and respawn
	# Drop player into abyss below y = 600
	player.global_position = Vector2(330, 580)
	player.velocity = Vector2(0, 200)
	for i in range(20):
		await physics_frame

	# Player should have triggered die() and respawned at spawn_position (40, 180)
	if player.global_position.distance_to(player.spawn_position) < 25.0:
		print("  [PASS] 9. Pit fall triggers death and respawn at spawn position (%.1f, %.1f)" % [player.global_position.x, player.global_position.y])
		pass_count += 1
	else:
		printerr("  [FAIL] 9. Respawn failure, pos: ", player.global_position, " expected: ", player.spawn_position)
		fail_count += 1

	# Assertion 10: Coyote Time verification
	# Place player near edge of ground at x = 296 (Ground ends at 300)
	player.global_position = Vector2(296, 193)
	player.velocity = Vector2.ZERO
	await physics_frame
	# Run off ledge until airborne
	player.simulated_move_axis = 1.0
	var was_air: bool = false
	for i in range(15):
		await physics_frame
		if not player.is_on_floor():
			was_air = true
			break

	var coyote_active: bool = player.coyote_timer > 0.0
	player.simulated_jump_just_pressed = true
	await physics_frame

	if was_air and coyote_active and player.velocity.y < -150.0:
		print("  [PASS] 10. Coyote time allows jumping immediately after walking off ledge (coyote: active, vel.y = %.1f)" % player.velocity.y)
		pass_count += 1
	else:
		printerr("  [FAIL] 10. Coyote time failed, was_air: ", was_air, " coyote_active: ", coyote_active, " vel.y: ", player.velocity.y)
		fail_count += 1

	print("-------------------------------------------")
	print("Milestone B Movement Tests Passed: %d | Failed: %d" % [pass_count, fail_count])
	if fail_count == 0:
		print("[ALL PLATFORMER MOVEMENT TESTS PASSED]")
		quit(0)
	else:
		printerr("[PLATFORMER MOVEMENT TESTS FAILED]")
		quit(1)
