extends SceneTree

const PlatformerLevel = preload("res://scripts/platformer/platformer_level.gd")
const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")
const MovableFragment2D = preload("res://scripts/platformer/movable_fragment_2d.gd")
const ExitPortal = preload("res://scripts/platformer/exit_portal.gd")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("============================================================")
	print("STARTING TEST: REBOUND SHOWCASE LEVEL (OPEN ASSETS INTEGRATION)")
	print("============================================================")
	run_showcase_test()

func run_showcase_test() -> void:
	var scene_res = load("res://scenes/platformer/levels/rebound_showcase_level.tscn")
	if not scene_res:
		_assert_true(false, "Showcase scene loaded successfully")
		quit(1)
		return

	var level: PlatformerLevel = scene_res.instantiate() as PlatformerLevel
	root.add_child(level)
	level.player.use_simulated_input = true

	# Allow Godot tree lifecycle & ready callbacks to complete
	for i in range(15):
		await physics_frame

	# 1. Structural and Node Verification
	_assert_not_null(level.player, "Player is discovered")
	_assert_not_null(level.tile_manager, "TileManager is discovered")
	_assert_not_null(level.exit_portal, "ExitPortal is discovered")

	var player: PlayerPlatformer = level.player
	var tile_mgr: PlatformTileManager = level.tile_manager
	var exit_portal: ExitPortal = level.exit_portal
	var cp = level.get_node_or_null("Checkpoint")
	var shard_cyan = level.get_node_or_null("ShardCyan")
	var shard_amber = level.get_node_or_null("ShardAmber")
	var door = level.get_node_or_null("LockedDoor")
	var music_player = level.get_node_or_null("MusicPlayer")

	var frag: MovableFragment2D = null
	for child in tile_mgr.get_children():
		if child is MovableFragment2D:
			frag = child as MovableFragment2D
			break

	_assert_not_null(cp, "Checkpoint node exists")
	_assert_not_null(shard_cyan, "Cyan Shard exists")
	_assert_not_null(shard_amber, "Amber Shard exists")
	_assert_not_null(door, "LockedDoor exists")
	_assert_not_null(music_player, "MusicPlayer exists")
	_assert_not_null(frag, "MovableFragment2D exists in TileManager")

	# 2. Verified Asset Binding Checks
	if player and player.sprite:
		_assert_true(player.sprite.texture != null, "Player sprite texture assigned")
		_assert_true(player.sprite.texture.resource_path.ends_with("pip_idle.png") or player.sprite.texture.resource_path.ends_with("pip.png"), "Player texture uses approved Pip asset")

	if cp:
		var visual = cp.get_node_or_null("Visual")
		_assert_not_null(visual, "Checkpoint has Visual sprite node")
		if visual is Sprite2D:
			_assert_true(visual.texture != null and visual.texture.resource_path.ends_with("checkpoint_flag.png"), "Checkpoint uses checkpoint_flag.png")

	if shard_cyan:
		_assert_true(shard_cyan.sprite != null and shard_cyan.sprite.texture != null, "Cyan shard has sprite texture")
		_assert_true(shard_cyan.sprite.texture.resource_path.ends_with("shard_cyan.png"), "Cyan shard uses shard_cyan.png")

	if shard_amber:
		_assert_true(shard_amber.sprite != null and shard_amber.sprite.texture != null, "Amber shard has sprite texture")
		_assert_true(shard_amber.sprite.texture.resource_path.ends_with("shard_amber.png"), "Amber shard uses shard_amber.png")

	if door:
		_assert_true(door.sprite_closed_tex != null and door.sprite_closed_tex.resource_path.ends_with("door_locked.png"), "Door uses door_locked.png")
		_assert_true(door.sprite_open_tex != null and door.sprite_open_tex.resource_path.ends_with("door_open.png"), "Door uses door_open.png")

	if music_player:
		_assert_true(music_player.stream != null and music_player.stream.resource_path.ends_with("music_world1_loop.mp3"), "Music player configured with music_world1_loop.mp3")

	# 3. Functional Mechanic Verification: Reality Snapback
	# Step A: Check initial fragment state
	_assert_equal(frag.state, MovableFragment2D.State.HOME, "Step A: Fragment starts in HOME state")
	var home_cell = frag.home_cell
	_assert_equal(home_cell, Vector2i(7, 11), "Step A: Fragment home_cell is (7, 11)")
	_assert_true(tile_mgr.has_block(home_cell), "Step A: home_cell is registered as solid")

	# Step B: Siphon block with Pixel Glove
	var glove = player.glove
	_assert_not_null(glove, "Step B: PixelGlove is attached to player")
	player.global_position = Vector2(frag.home_cell.x * 16.0 - 10.0, frag.home_cell.y * 16.0 + 8.0)
	player.velocity = Vector2.ZERO
	player.aim_offset = Vector2i(1, 0) # Aim right at (120, 184)
	for i in range(5):
		await physics_frame

	var steal_ok: bool = glove.try_interact()
	_assert_true(steal_ok, "Step B: Glove siphoned fragment")
	_assert_true(player.carried_block != null, "Step B: Player carried_block is populated")
	_assert_equal(frag.state, MovableFragment2D.State.CARRIED, "Step B: Fragment transitioned to CARRIED")
	_assert_false(tile_mgr.has_block(home_cell), "Step B: home_cell is now open/empty")
	_assert_not_null(frag.ghost_frame, "Step B: GhostFrame2D was instantiated")
	_assert_true(frag.ghost_frame.visible, "Step B: GhostFrame2D is visibly pulsating at home_cell")

	# Step C: Place fragment into free space to form spring
	# Place at cell (9, 12) -> position (152, 200)
	var place_cell = Vector2i(9, 12)
	player.global_position = Vector2(place_cell.x * 16.0 - 16.0, place_cell.y * 16.0 + 8.0)
	player.aim_offset = Vector2i(1, 0)
	for i in range(5):
		await physics_frame

	var place_ok: bool = glove.try_interact()
	_assert_true(place_ok, "Step C: Glove successfully placed block")
	for i in range(2):
		await physics_frame
	_assert_true(player.carried_block == null, "Step C: Player carried_block is cleared")
	_assert_equal(frag.state, MovableFragment2D.State.PLACED, "Step C: Fragment transitioned to PLACED")
	_assert_true(frag.collision_shape.disabled == false, "Step C: Placed spring collision shape is active")
	_assert_true(frag.sprite.texture.resource_path.ends_with("spring_rest.png"), "Step C: Spring visual updated to spring_rest.png")

	# Step D: Jump onto spring to trigger launch
	# Position Pip directly above spring with downward velocity
	player.global_position = Vector2(frag.global_position.x, frag.global_position.y - 24.0)
	player.velocity = Vector2(0, 80)
	player.was_on_floor = false

	for i in range(5):
		await physics_frame

	frag.on_player_landed(player)
	_assert_equal(frag.state, MovableFragment2D.State.TRIGGERED, "Step D: Spring transitioned to TRIGGERED upon landing")
	_assert_true(player.velocity.y <= -360.0, "Step D: Player received high-energy rebound impulse (vy = %f)" % player.velocity.y)
	_assert_true(frag.sprite.texture.resource_path.ends_with("spring_compressed.png"), "Step D: Spring visual compressed to spring_compressed.png")

	# Step E: Trigger snapback and verify air-collision cleanup
	frag.start_snapback()
	for i in range(2):
		await physics_frame
	_assert_equal(frag.state, MovableFragment2D.State.RETURNING, "Step E: Spring transitioned to RETURNING")
	_assert_true(frag.collision_shape.disabled, "Step E: Temporary spring collision immediately disabled")

	# Step F: Simulate Pip flight and settling on top of CliffHigh (y = 96)
	player.global_position = Vector2(240, 90)
	player.velocity = Vector2(0, 50)
	for frame in range(40):
		await physics_frame

	_assert_true(player.is_on_floor(), "Step F: Player touched down atop CliffHigh")
	_assert_true(player.global_position.y <= 98.0, "Step F: Player settled at high cliff top (y = %f)" % player.global_position.y)

	# Step G: Shard collection atop cliff
	player.global_position = shard_cyan.global_position
	shard_cyan.collect()
	_assert_true(shard_cyan.is_collected, "Step G: Cyan shard was collected")
	_assert_false(shard_cyan.visible, "Step G: Cyan shard is no longer visible")

	player.global_position = shard_amber.global_position
	shard_amber.collect()
	_assert_true(shard_amber.is_collected, "Step G: Amber shard was collected")

	# Step H: Checkpoint activation
	cp.activate()
	_assert_true(cp.is_active, "Step H: Checkpoint flag activated")
	_assert_equal(cp.visual.modulate, Color(0.2, 0.9, 0.4), "Step H: Checkpoint flag visual modulated to active green")

	# Step I: Door unlocking & Exit
	door.set_open(true)
	for i in range(2):
		await physics_frame
	_assert_true(door.is_open, "Step I: Door opened")
	_assert_true(door.collision_shape.disabled, "Step I: Door collision disabled")
	_assert_true(door.sprite.texture.resource_path.ends_with("door_open.png"), "Step I: Door sprite updated to door_open.png")

	# Reach exit portal
	player.global_position = exit_portal.global_position
	exit_portal._on_body_entered(player)
	_assert_true(level.is_completed, "Step I: Level marked completed upon reaching exit portal")

	# Summary
	print("------------------------------------------------------------")
	print("SHOWCASE LEVEL TEST SUMMARY: %d PASSED, %d FAILED" % [_passed, _failed])
	print("------------------------------------------------------------")

	if _failed > 0:
		print("FAILED: Showcase level test had failures.")
		quit(1)
	else:
		print("SUCCESS: Showcase level verified 100% with open-source assets!")
		quit(0)

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % msg)

func _assert_false(cond: bool, msg: String) -> void:
	_assert_true(not cond, msg)

func _assert_not_null(val: Variant, msg: String) -> void:
	_assert_true(val != null, msg)

func _assert_equal(val: Variant, expected: Variant, msg: String) -> void:
	if val == expected:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s (got %s, expected %s)" % [msg, str(val), str(expected)])
