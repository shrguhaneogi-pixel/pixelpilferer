extends SceneTree

const PlatformerLevel = preload("res://scripts/platformer/platformer_level.gd")
const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")
const MovableFragment2D = preload("res://scripts/platformer/movable_fragment_2d.gd")
const ExitPortal = preload("res://scripts/platformer/exit_portal.gd")

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("=================================================================")
	print("   PIXEL PILFERER: REBOUND — REALITY SNAPBACK ACCEPTANCE (11/11)  ")
	print("=================================================================")
	run_rebound_acceptance()

func run_rebound_acceptance() -> void:
	var scene_res = load("res://scenes/test/rebound_vertical_slice.tscn")
	if not scene_res:
		assert_test(false, "Scene res loaded successfully")
		quit(1)
		return

	var scene: PlatformerLevel = scene_res.instantiate() as PlatformerLevel
	root.add_child(scene)
	scene.player.use_simulated_input = true

	for i in range(15):
		await physics_frame

	var player: PlayerPlatformer = scene.player
	var tile_mgr: PlatformTileManager = scene.tile_manager
	var exit: ExitPortal = scene.exit_portal

	# Find the MovableFragment2D
	var frag: MovableFragment2D = null
	for child in tile_mgr.get_children():
		if child is MovableFragment2D:
			frag = child as MovableFragment2D
			break

	assert_test(frag != null, "Precondition: MovableFragment2D exists in level")
	assert_test(frag.state == MovableFragment2D.State.HOME, "Precondition: Initial fragment state is HOME")
	assert_test(frag.home_cell == Vector2i(7, 11), "Precondition: Fragment home_cell is Vector2i(7, 11)")

	# -------------------------------------------------------------
	# STEP 1: Pip begins on a safe platform and can run and jump
	# -------------------------------------------------------------
	var s1_floor: bool = player.is_on_floor()
	player.simulated_move_axis = 1.0
	for i in range(10):
		await physics_frame
	var moved_right: bool = player.velocity.x > 30.0

	player.simulated_move_axis = 0.0
	player.simulated_jump_just_pressed = true
	for i in range(10):
		await physics_frame
	var jumped_up: bool = player.velocity.y < -100.0

	for i in range(25):
		await physics_frame

	assert_test(s1_floor and moved_right and jumped_up, "Step 1: Pip begins on safe platform and can run and jump")

	# -------------------------------------------------------------
	# STEP 2: Pip steals marked fragment from wall
	# -------------------------------------------------------------
	# Approach wall pedestal
	player.global_position = Vector2(frag.home_cell.x * 16.0 - 10.0, frag.home_cell.y * 16.0 + 8.0)
	player.velocity = Vector2.ZERO
	player.aim_offset = Vector2i(1, 0)
	for i in range(5):
		await physics_frame

	var steal_ok: bool = player.glove.try_interact()
	assert_test(steal_ok, "Step 2: Pip steals marked fragment from wall into glove")
	assert_test(player.carried_block != null, "Step 2: Player carried_block is populated")
	assert_test(frag.state == MovableFragment2D.State.CARRIED, "Step 2: Fragment state transitioned to CARRIED")

	# -------------------------------------------------------------
	# STEP 3: Source location becomes empty with ghost frame visible
	# -------------------------------------------------------------
	var home_empty: bool = not tile_mgr.has_block(frag.home_cell)
	var ghost_visible: bool = frag.ghost_frame != null and frag.ghost_frame.visible
	assert_test(home_empty, "Step 3: Source location becomes empty air without residual collision")
	assert_test(ghost_visible, "Step 3: Identifiable GhostFrame outline is visible at home cell")

	# -------------------------------------------------------------
	# STEP 4: Pip carries fragment to gap
	# -------------------------------------------------------------
	player.global_position = Vector2(150.0, 201.0)
	player.velocity = Vector2.ZERO
	for i in range(5):
		await physics_frame
	assert_test(player.carried_block != null, "Step 4: Pip carries fragment safely to edge of gap")

	# -------------------------------------------------------------
	# STEP 5: Pip places it into a valid empty location
	# -------------------------------------------------------------
	var place_cell = Vector2i(11, 12) # x = 184, y = 200
	player.global_position = Vector2(place_cell.x * 16.0 - 10.0, place_cell.y * 16.0 + 8.0)
	player.aim_offset = Vector2i(1, 0)
	var place_ok: bool = player.glove.try_interact()
	assert_test(place_ok, "Step 5: Pip places fragment into empty cell Vector2i(11, 12)")
	assert_test(player.carried_block == null, "Step 5: Player carried_block reset to null (empty hand)")
	assert_test(frag.state == MovableFragment2D.State.PLACED, "Step 5: Fragment state transitioned to PLACED")

	# -------------------------------------------------------------
	# STEP 6: The placed block supports Pip as a solid platform
	# -------------------------------------------------------------
	for i in range(2):
		await physics_frame
	var is_solid_placed: bool = frag.state == MovableFragment2D.State.PLACED and not frag.collision_shape.disabled and tile_mgr.has_block(place_cell)
	assert_test(is_solid_placed, "Step 6: Placed block is solid and ready to support Pip as a platform")

	# -------------------------------------------------------------
	# STEP 7: Landing on block from above launches Pip upward (-370 px/s)
	# -------------------------------------------------------------
	# Pip jumps towards the placed spring from the edge of the gap
	player.global_position = Vector2(frag.position.x - 8.0, frag.position.y - 35.0)
	player.velocity = Vector2(60.0, 80.0) # Falling downward towards spring
	player.simulated_move_axis = 1.0

	var triggered_bounce: bool = false
	var peak_launch_vy: float = 0.0

	for i in range(25):
		await physics_frame
		if player.velocity.y < -250.0:
			triggered_bounce = true
			peak_launch_vy = player.velocity.y
			break

	assert_test(triggered_bounce, "Step 7: Landing on block triggers spring launch (peak vy = %.1f px/s)" % peak_launch_vy)
	assert_test(frag.state == MovableFragment2D.State.TRIGGERED or frag.state == MovableFragment2D.State.RETURNING, "Step 7: Fragment marked as TRIGGERED/RETURNING")

	# -------------------------------------------------------------
	# STEP 8: Pip uses rebound to reach higher platform (80px high)
	# -------------------------------------------------------------
	# Air control to the right towards CliffHigh (x = 240..400, y = 128)
	player.simulated_move_axis = 1.0
	for i in range(35):
		await physics_frame

	player.simulated_move_axis = 0.0
	# Allow gravity to settle Pip onto CliffHigh platform
	for i in range(40):
		await physics_frame

	var reached_high_cliff: bool = player.global_position.x > 230.0 and player.global_position.y <= 130.0 and player.is_on_floor()
	assert_test(reached_high_cliff, "Step 8: Rebound height allowed Pip to land atop the 80px high cliff (pos: %.1f, %.1f, on_floor: %s)" % [player.global_position.x, player.global_position.y, player.is_on_floor()])

	# -------------------------------------------------------------
	# STEP 9: Triggered block returns to home safely (Snapback)
	# -------------------------------------------------------------
	# Wait for snapback return tween to complete (~0.25s / 15-20 frames)
	for i in range(25):
		await physics_frame

	var returned_to_home: bool = (frag.state == MovableFragment2D.State.HOME)
	var at_home_pos: bool = frag.global_position.distance_to(Vector2(frag.home_cell.x * 16.0 + 8.0, frag.home_cell.y * 16.0 + 8.0)) < 2.0
	var old_cell_cleared: bool = not tile_mgr.has_block(place_cell)
	var home_solid: bool = tile_mgr.has_block(frag.home_cell) and not frag.collision_shape.disabled

	assert_test(returned_to_home and at_home_pos, "Step 9: Fragment safely returned to original home cell")
	assert_test(old_cell_cleared and home_solid, "Step 9: Temporary spring collision cleared; home collision restored")

	# -------------------------------------------------------------
	# STEP 10: Pip reaches exit and completes level
	# -------------------------------------------------------------
	player.global_position = exit.global_position
	for i in range(10):
		await physics_frame
	assert_test(scene.is_completed, "Step 10: Pip reaches exit portal, triggering level-completion state")

	# -------------------------------------------------------------
	# STEP 11: Level restart restores exact initial layout
	# -------------------------------------------------------------
	scene.restart_level()
	for i in range(10):
		await physics_frame

	var p_at_start: bool = player.global_position.distance_to(scene.initial_snapshot["player_pos"]) < 5.0
	var hand_empty: bool = player.carried_block == null
	var frag_at_home: bool = frag.state == MovableFragment2D.State.HOME and not frag.ghost_frame.visible
	var exit_reset: bool = not scene.is_completed and not exit.is_completed

	assert_test(p_at_start and hand_empty and frag_at_home and exit_reset, "Step 11: Level restart restores initial player, fragments, ghost frames & exit")

	# =============================================================
	# EDGE CASE 1: Side collision must NOT trigger bounce
	# =============================================================
	print("\n--- Edge Case 1: Rejection of Side-Triggered Bounces ---")
	# Steal again
	player.global_position = Vector2(frag.home_cell.x * 16.0 - 10.0, frag.home_cell.y * 16.0 + 8.0)
	player.aim_offset = Vector2i(1, 0)
	for i in range(5):
		await physics_frame
	player.glove.try_interact()

	# Place on low ground ahead of Pip
	var side_place_cell = Vector2i(6, 12)
	player.global_position = Vector2(side_place_cell.x * 16.0 - 10.0, side_place_cell.y * 16.0 + 8.0)
	player.aim_offset = Vector2i(1, 0)
	player.glove.try_interact()

	# Run horizontally directly into the side of the placed block
	player.global_position = Vector2(side_place_cell.x * 16.0 - 20.0, side_place_cell.y * 16.0 + 8.0)
	player.velocity = Vector2(120.0, 0.0) # Horizontal run into side
	player.simulated_move_axis = 1.0

	var side_bounced: bool = false
	for i in range(15):
		await physics_frame
		if player.velocity.y < -150.0:
			side_bounced = true

	player.simulated_move_axis = 0.0
	assert_test(not side_bounced, "Edge Case 1: Side collision did NOT trigger spring bounce (is_on_wall: %s)" % player.is_on_wall())
	assert_test(frag.state == MovableFragment2D.State.PLACED, "Edge Case 1: Fragment remains in PLACED state on side collision")

	# =============================================================
	# EDGE CASE 2: Safe Deferred Restoration When Home Cell is Obstructed
	# =============================================================
	print("\n--- Edge Case 2: Deferred Restoration When Home Cell is Obstructed ---")
	# Trigger bounce on the placed block
	player.global_position = Vector2(frag.position.x, frag.position.y - 30.0)
	player.velocity = Vector2(0.0, 100.0)
	for i in range(15):
		await physics_frame
		if frag.state == MovableFragment2D.State.TRIGGERED:
			break

	# While fragment is returning, immediately place Pip right inside frag.home_cell
	player.global_position = Vector2(frag.home_cell.x * 16.0 + 8.0, frag.home_cell.y * 16.0 + 8.0)
	player.velocity = Vector2.ZERO

	# Wait for snapback tween to reach home
	for i in range(25):
		await physics_frame

	# Collision must NOT be re-enabled while Pip is inside home_cell!
	assert_test(frag.is_restoration_deferred, "Edge Case 2: Restoration safely DEFERRED while Pip obstructs home cell")
	assert_test(frag.collision_shape.disabled, "Edge Case 2: Collision remains DISABLED; no solid block teleported into player")

	# Now Pip steps out of the home cell
	player.global_position = Vector2(frag.home_cell.x * 16.0 - 25.0, frag.home_cell.y * 16.0 + 8.0)
	for i in range(15):
		await physics_frame

	assert_test(not frag.is_restoration_deferred, "Edge Case 2: Restoration finalized once Pip moved away")
	assert_test(not frag.collision_shape.disabled, "Edge Case 2: Collision safely re-enabled after obstruction cleared")

	# =============================================================
	# EDGE CASE 3: Anchored Socket Behavior (No Bounce / No Snapback)
	# =============================================================
	print("\n--- Edge Case 3: Anchored Socket Behavior ---")
	# Re-steal fragment
	player.global_position = Vector2(frag.home_cell.x * 16.0 - 10.0, frag.home_cell.y * 16.0 + 8.0)
	player.aim_offset = Vector2i(1, 0)
	for i in range(5):
		await physics_frame
	var s3_steal = player.glove.try_interact()
	assert_test(s3_steal, "Edge Case 3: Re-stole restored fragment from home cell")

	# Register a socket cell at Vector2i(4, 12) on low ground
	var sock_cell = Vector2i(4, 12)
	tile_mgr.register_socket_cell(sock_cell)

	# Place fragment into socket cell
	player.global_position = Vector2(sock_cell.x * 16.0 - 10.0, sock_cell.y * 16.0 + 8.0)
	player.aim_offset = Vector2i(1, 0)
	var s3_place = player.glove.try_interact()
	assert_test(s3_place, "Edge Case 3: Placed fragment into socket cell")

	assert_test(frag.state == MovableFragment2D.State.ANCHORED, "Edge Case 3: Fragment in socket cell transitions to ANCHORED")

	# Hop on top of anchored socket fragment
	player.global_position = Vector2(frag.position.x, frag.position.y - 30.0)
	player.velocity = Vector2(0.0, 100.0)
	var anchored_bounced: bool = false
	for i in range(15):
		await physics_frame
		if player.velocity.y < -250.0:
			anchored_bounced = true

	assert_test(not anchored_bounced, "Edge Case 3: Anchored fragment does NOT bounce player")
	assert_test(frag.state == MovableFragment2D.State.ANCHORED, "Edge Case 3: Anchored fragment does NOT snap back")

	scene.queue_free()

	# Summary
	print("\n=================================================================")
	print("Reality Snapback Validation: %d Passed | %d Failed" % [pass_count, fail_count])
	if fail_count == 0:
		print("[ALL 11 STEPS & EDGE CASES VERIFIED — REBOUND ARCHITECTURE CONFIRMED]")
		quit(0)
	else:
		printerr("[VALIDATION FAILED WITH %d ERRORS]" % fail_count)
		quit(1)

func assert_test(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % description)
		fail_count += 1
