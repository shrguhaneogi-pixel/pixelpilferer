extends SceneTree

const PlatformerLevel = preload("res://scripts/platformer/platformer_level.gd")
const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")
const Checkpoint = preload("res://scripts/platformer/checkpoint.gd")
const HazardZone = preload("res://scripts/platformer/hazard_zone.gd")
const CollectibleShard = preload("res://scripts/platformer/collectible_shard.gd")
const ChromaticSocket = preload("res://scripts/platformer/chromatic_socket.gd")
const LockedDoor = preload("res://scripts/platformer/locked_door.gd")
const ExitPortal = preload("res://scripts/platformer/exit_portal.gd")
const LevelProgressionController = preload("res://scripts/platformer/level_progression_controller.gd")
const ProgressService = preload("res://scripts/services/progress_service.gd")

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("=================================================================")
	print("   PIXEL PILFERER MILESTONE D — REUSABLE LEVEL ARCHITECTURE      ")
	print("=================================================================")
	run_milestone_d_validation()

func run_milestone_d_validation() -> void:
	# -------------------------------------------------------------
	# TIER 1: Static Data Verification Across All 3 Levels
	# -------------------------------------------------------------
	print("\n--- TIER 1: Static Level Data Integrity ---")
	test_static_level_data("res://scenes/platformer/levels/level_01_stolen_ledge.tscn", "w1_01", 1, 0, 0, 0)
	test_static_level_data("res://scenes/platformer/levels/level_02_hazard_leap.tscn", "w1_02", 2, 1, 1, 0)
	test_static_level_data("res://scenes/platformer/levels/level_03_conduit_gate.tscn", "w1_03", 3, 0, 0, 1)

	# -------------------------------------------------------------
	# TIER 2: Discrete Mechanics, Checkpoints, Hazards & Sockets
	# -------------------------------------------------------------
	print("\n--- TIER 2: Discrete Mechanics & State Restoration ---")
	await test_tier_2_mechanics()

	# -------------------------------------------------------------
	# TIER 3: Physics-based Traversal & Multi-Level Progression
	# -------------------------------------------------------------
	print("\n--- TIER 3: Multi-Level Traversal Simulation & Progression ---")
	await test_tier_3_progression()

	# Summary
	print("\n=================================================================")
	print("Milestone D Validation Results: %d Passed | %d Failed" % [pass_count, fail_count])
	if fail_count == 0:
		print("[ALL MILESTONE D ACCEPTANCE CRITERIA VERIFIED]")
		quit(0)
	else:
		printerr("[VALIDATION FAILED WITH %d ERRORS]" % fail_count)
		quit(1)

func test_static_level_data(scene_path: String, expected_id: String, expected_shards: int, expected_cps: int, expected_hazards: int, expected_sockets: int) -> void:
	var scene_res = load(scene_path)
	if not scene_res:
		assert_test(false, "Static Data: Scene %s loaded successfully" % scene_path)
		return

	var lvl = scene_res.instantiate()
	root.add_child(lvl)
	if not (lvl is PlatformerLevel):
		assert_test(false, "Static Data: Root node of %s is PlatformerLevel" % scene_path)
		lvl.queue_free()
		return

	lvl.discover_nodes()

	assert_test(lvl.level_id == expected_id, "Static Data [%s]: Correct level_id (%s)" % [expected_id, lvl.level_id])
	assert_test(lvl.player != null, "Static Data [%s]: PlayerPlatformer instance found" % expected_id)
	assert_test(lvl.tile_manager != null, "Static Data [%s]: PlatformTileManager instance found" % expected_id)
	assert_test(lvl.exit_portal != null, "Static Data [%s]: ExitPortal instance found" % expected_id)
	assert_test(lvl.collectibles.size() == expected_shards, "Static Data [%s]: Collectible count %d == %d" % [expected_id, lvl.collectibles.size(), expected_shards])
	assert_test(lvl.checkpoints.size() == expected_cps, "Static Data [%s]: Checkpoint count %d == %d" % [expected_id, lvl.checkpoints.size(), expected_cps])
	assert_test(lvl.hazards.size() == expected_hazards, "Static Data [%s]: Hazard count %d == %d" % [expected_id, lvl.hazards.size(), expected_hazards])
	assert_test(lvl.sockets.size() == expected_sockets, "Static Data [%s]: Socket count %d == %d" % [expected_id, lvl.sockets.size(), expected_sockets])

	lvl.queue_free()

func test_tier_2_mechanics() -> void:
	# Test Level 2 Checkpoint Snapshot & Hazard Respawn
	var l2_res = load("res://scenes/platformer/levels/level_02_hazard_leap.tscn")
	var l2: PlatformerLevel = l2_res.instantiate() as PlatformerLevel
	root.add_child(l2)
	l2.player.use_simulated_input = true

	for i in range(10):
		await physics_frame

	# 1. Collect Shard 1 before checkpoint
	var s1 = l2.collectibles[0]
	l2.player.global_position = s1.global_position
	for i in range(5):
		await physics_frame
	assert_test(s1.is_collected, "Tier 2: Shard 1 collected on contact")
	assert_test(l2.collected_shards.has(s1.shard_id), "Tier 2: Shard 1 registered in level collected list")

	# 2. Steal block at (8, 11)
	var steal_cell = Vector2i(8, 11)
	l2.player.global_position = Vector2(steal_cell.x * 16.0 - 10.0, steal_cell.y * 16.0 + 8.0)
	l2.player.aim_offset = Vector2i(1, 0)
	l2.player.glove.try_interact()
	assert_test(l2.player.carried_block != null, "Tier 2: Block stolen into glove")
	assert_test(not l2.tile_manager.has_block(steal_cell), "Tier 2: Stolen block removed from TileManager")

	# 3. Reach and activate Checkpoint 1
	var cp1 = l2.checkpoints[0]
	l2.player.global_position = cp1.global_position
	for i in range(5):
		await physics_frame
	assert_test(cp1.is_active, "Tier 2: Checkpoint 1 activated on contact")
	assert_test(l2.active_checkpoint == cp1, "Tier 2: Active checkpoint updated in level")
	assert_test(l2.checkpoint_snapshot["carried_block"] != null, "Tier 2: Checkpoint snapshot preserved carried block")
	assert_test(l2.checkpoint_snapshot["shards"].has(s1.shard_id), "Tier 2: Checkpoint snapshot preserved Shard 1")

	# 4. Collect Shard 2 AFTER checkpoint
	var s2 = l2.collectibles[1]
	l2.player.global_position = s2.global_position
	for i in range(5):
		await physics_frame
	assert_test(s2.is_collected, "Tier 2: Shard 2 collected after checkpoint")

	# 5. Fall into hazard (spikes)
	var hazard = l2.hazards[0]
	l2.player.global_position = hazard.global_position
	for i in range(5):
		await physics_frame

	# 6. Verify Respawn & Restoration
	assert_test(l2.player.global_position.distance_to(cp1.global_position) < 5.0, "Tier 2: Player respawned at Checkpoint 1")
	assert_test(l2.player.carried_block != null, "Tier 2: Carried block restored from checkpoint snapshot")
	assert_test(s1.is_collected, "Tier 2: Shard 1 (pre-checkpoint) remains collected")
	assert_test(not s2.is_collected, "Tier 2: Shard 2 (post-checkpoint) reverted to uncollected")

	# 7. Test Level Restart (R key)
	l2.restart_level()
	for i in range(5):
		await physics_frame
	assert_test(l2.player.global_position.distance_to(l2.initial_snapshot["player_pos"]) < 5.0, "Tier 2: Restart restored initial player spawn")
	assert_test(l2.player.carried_block == null, "Tier 2: Restart restored empty hand")
	assert_test(l2.tile_manager.has_block(steal_cell), "Tier 2: Restart restored initial wall block")
	assert_test(not cp1.is_active, "Tier 2: Restart reverted checkpoint to dormant")
	assert_test(not s1.is_collected and not s2.is_collected, "Tier 2: Restart restored all shards")

	l2.queue_free()

	# Test Level 3 Sockets & Locked Door
	var l3_res = load("res://scenes/platformer/levels/level_03_conduit_gate.tscn")
	var l3: PlatformerLevel = l3_res.instantiate() as PlatformerLevel
	root.add_child(l3)
	l3.player.use_simulated_input = true
	for i in range(10):
		await physics_frame

	var socket: ChromaticSocket = l3.sockets[0]
	var door: LockedDoor = l3.doors[0]
	var exit: ExitPortal = l3.exit_portal

	assert_test(not socket.is_satisfied, "Tier 2 [L3]: Socket initially unsatisfied")
	assert_test(not door.is_open, "Tier 2 [L3]: LockedDoor initially closed")
	assert_test(exit.is_locked, "Tier 2 [L3]: ExitPortal initially locked (requires 1 socket)")

	# Steal Cyan block at (7, 8)
	var c_cell = Vector2i(7, 8)
	l3.player.global_position = Vector2(c_cell.x * 16.0 - 10.0, c_cell.y * 16.0 + 8.0)
	l3.player.aim_offset = Vector2i(1, 0)
	l3.player.glove.try_interact()
	assert_test(l3.player.carried_block != null and l3.player.carried_block["color"] == 1, "Tier 2 [L3]: Stole Cyan block")

	# Place Cyan block into socket at (12, 11)
	l3.player.global_position = Vector2(socket.grid_cell.x * 16.0 - 10.0, socket.grid_cell.y * 16.0 + 8.0)
	l3.player.aim_offset = Vector2i(1, 0)
	var place_ok = l3.player.glove.try_interact()
	assert_test(place_ok, "Tier 2 [L3]: Placed Cyan block into socket cell")
	l3.update_sockets_and_doors()

	assert_test(socket.is_satisfied, "Tier 2 [L3]: Socket is satisfied by Cyan block")
	assert_test(door.is_open, "Tier 2 [L3]: LockedDoor opened by satisfied socket")
	assert_test(not exit.is_locked, "Tier 2 [L3]: ExitPortal unlocked")

	# Steal block back out of socket
	l3.player.glove.try_interact()
	l3.update_sockets_and_doors()
	assert_test(not socket.is_satisfied, "Tier 2 [L3]: Socket unsatisfied after block removed")
	assert_test(not door.is_open, "Tier 2 [L3]: LockedDoor re-closed")
	assert_test(exit.is_locked, "Tier 2 [L3]: ExitPortal re-locked")

	l3.queue_free()

func test_tier_3_progression() -> void:
	var runner = LevelProgressionController.new()
	var scenes: Array[PackedScene] = [
		load("res://scenes/platformer/levels/level_01_stolen_ledge.tscn"),
		load("res://scenes/platformer/levels/level_02_hazard_leap.tscn"),
		load("res://scenes/platformer/levels/level_03_conduit_gate.tscn")
	]
	runner.level_scenes = scenes
	root.add_child(runner)
	runner.load_level(0)

	for i in range(10):
		await physics_frame

	# --- Traverse Level 1 ("The Stolen Ledge") ---
	var lvl1: PlatformerLevel = runner.current_level_node
	lvl1.player.use_simulated_input = true
	assert_test(lvl1.level_id == "w1_01", "Tier 3: Progression loaded Level 1 (w1_01)")

	# Step 1: Collect shard
	var l1_shard = lvl1.collectibles[0]
	lvl1.player.global_position = l1_shard.global_position
	for i in range(5):
		await physics_frame
	assert_test(l1_shard.is_collected, "Tier 3 [L1]: Shard 1 collected")

	# Step 2: Steal block at (6, 11)
	lvl1.player.global_position = Vector2(6 * 16.0 - 10.0, 11 * 16.0 + 8.0)
	lvl1.player.aim_offset = Vector2i(1, 0)
	lvl1.player.glove.try_interact()
	assert_test(lvl1.player.carried_block != null, "Tier 3 [L1]: Block stolen")

	# Step 3: Place block at (11, 11) to create stepping stone
	lvl1.player.global_position = Vector2(11 * 16.0 - 10.0, 11 * 16.0 + 8.0)
	lvl1.player.aim_offset = Vector2i(1, 0)
	var l1_place_ok = lvl1.player.glove.try_interact()
	assert_test(l1_place_ok, "Tier 3 [L1]: Stepping stone placed at (11, 11)")

	# Step 4: Reach exit portal
	lvl1.player.global_position = lvl1.exit_portal.global_position
	for i in range(10):
		await physics_frame
	assert_test(lvl1.is_completed, "Tier 3 [L1]: Level 1 completed via ExitPortal")

	# Advance to Level 2
	var adv_ok_1 = runner.advance_to_next_level()
	assert_test(adv_ok_1, "Tier 3: Advanced from Level 1 to Level 2")
	for i in range(10):
		await physics_frame

	# --- Traverse Level 2 ("The Hazard Leap") ---
	var lvl2: PlatformerLevel = runner.current_level_node
	lvl2.player.use_simulated_input = true
	assert_test(lvl2.level_id == "w1_02", "Tier 3: Progression loaded Level 2 (w1_02)")

	# Steal block at (8, 11)
	lvl2.player.global_position = Vector2(8 * 16.0 - 10.0, 11 * 16.0 + 8.0)
	lvl2.player.aim_offset = Vector2i(1, 0)
	lvl2.player.glove.try_interact()
	assert_test(lvl2.player.carried_block != null, "Tier 3 [L2]: Stole Cyan block")

	# Collect Shard 1
	lvl2.player.global_position = lvl2.collectibles[0].global_position
	for i in range(5):
		await physics_frame
	assert_test(lvl2.collectibles[0].is_collected, "Tier 3 [L2]: Collected Shard 1")

	# Place floating platform at (12, 12) across hazard chasm
	lvl2.player.global_position = Vector2(12 * 16.0 - 10.0, 12 * 16.0 + 8.0)
	lvl2.player.aim_offset = Vector2i(1, 0)
	var l2_place_ok = lvl2.player.glove.try_interact()
	assert_test(l2_place_ok, "Tier 3 [L2]: Floating platform placed at (12, 12) across chasm")

	# Collect Shard 2
	lvl2.player.global_position = lvl2.collectibles[1].global_position
	for i in range(5):
		await physics_frame
	assert_test(lvl2.collectibles[1].is_collected, "Tier 3 [L2]: Collected Shard 2")

	# Reach Exit Portal
	lvl2.player.global_position = lvl2.exit_portal.global_position
	for i in range(10):
		await physics_frame
	assert_test(lvl2.is_completed, "Tier 3 [L2]: Level 2 completed via ExitPortal")

	# Advance to Level 3
	var adv_ok_2 = runner.advance_to_next_level()
	assert_test(adv_ok_2, "Tier 3: Advanced from Level 2 to Level 3")
	for i in range(10):
		await physics_frame

	# --- Traverse Level 3 ("The Conduit Gate") ---
	var lvl3: PlatformerLevel = runner.current_level_node
	lvl3.player.use_simulated_input = true
	assert_test(lvl3.level_id == "w1_03", "Tier 3: Progression loaded Level 3 (w1_03)")

	# Collect Shard 1
	lvl3.player.global_position = lvl3.collectibles[0].global_position
	for i in range(5):
		await physics_frame

	# Steal Cyan block at (7, 8)
	lvl3.player.global_position = Vector2(7 * 16.0 - 10.0, 8 * 16.0 + 8.0)
	lvl3.player.aim_offset = Vector2i(1, 0)
	lvl3.player.glove.try_interact()
	assert_test(lvl3.player.carried_block != null, "Tier 3 [L3]: Stole Cyan block")

	# Place Cyan block into socket at (12, 11)
	lvl3.player.global_position = Vector2(12 * 16.0 - 10.0, 11 * 16.0 + 8.0)
	lvl3.player.aim_offset = Vector2i(1, 0)
	var l3_place = lvl3.player.glove.try_interact()
	assert_test(l3_place, "Tier 3 [L3]: Placed block into socket")
	lvl3.update_sockets_and_doors()

	# Collect Shard 2 & 3
	lvl3.player.global_position = lvl3.collectibles[1].global_position
	for i in range(5):
		await physics_frame
	lvl3.player.global_position = lvl3.collectibles[2].global_position
	for i in range(5):
		await physics_frame
	assert_test(lvl3.collectibles[1].is_collected and lvl3.collectibles[2].is_collected, "Tier 3 [L3]: Shards 2 & 3 collected")

	# Reach Exit Portal
	lvl3.player.global_position = lvl3.exit_portal.global_position
	for i in range(10):
		await physics_frame
	assert_test(lvl3.is_completed, "Tier 3 [L3]: Level 3 completed with all sockets & shards satisfied")

	# Verify ProgressService Persistence
	assert_test(ProgressService.is_level_completed("w1_01"), "Tier 3: ProgressService saved w1_01 completion")
	assert_test(ProgressService.is_level_completed("w1_02"), "Tier 3: ProgressService saved w1_02 completion")
	assert_test(ProgressService.is_level_completed("w1_03"), "Tier 3: ProgressService saved w1_03 completion")

	runner.queue_free()

func assert_test(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] %s" % description)
		pass_count += 1
	else:
		printerr("  [FAIL] %s" % description)
		fail_count += 1
