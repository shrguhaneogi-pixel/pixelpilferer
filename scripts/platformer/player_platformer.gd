class_name PlayerPlatformer extends CharacterBody2D

## Signals
signal jumped()
signal landed()
signal died()
signal bounced(launch_velocity: float)
signal block_stolen(color: int)
signal block_placed(color: int, cell: Vector2i)
signal aim_changed(aim_cell: Vector2i)

## Physics Constants
const RUN_SPEED: float = 120.0
const ACCELERATION: float = 800.0
const FRICTION: float = 1000.0
const AIR_ACCELERATION: float = 650.0
const AIR_FRICTION: float = 400.0

const GRAVITY: float = 620.0
const JUMP_VELOCITY: float = -225.0
const TERMINAL_VELOCITY: float = 340.0
const VARIABLE_JUMP_CUTOFF: float = 0.45

const COYOTE_TIME: float = 0.08
const JUMP_BUFFER_TIME: float = 0.10
const INTERACTION_REACH: float = 28.0

## State Variables
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var facing_direction: int = 1 # 1 = right, -1 = left
var is_jumping: bool = false
var input_enabled: bool = true
var was_on_floor: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var respawn_position: Vector2 = Vector2.ZERO

## Carried Block State (Strict capacity: 1)
var carried_block: Variant = null # null or { "color": int, "symbol": String }

## Aiming
var aim_offset: Vector2i = Vector2i(1, 0) # Relative tile offset

## Simulated Input (for deterministic headless test verification)
var use_simulated_input: bool = false
var simulated_move_axis: float = 0.0
var simulated_jump_just_pressed: bool = false
var simulated_jump_just_released: bool = false
var simulated_jump_held: bool = false
var simulated_aim_up: bool = false
var simulated_aim_down: bool = false
var simulated_interact_just_pressed: bool = false

## Nodes
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var glove: Node2D = get_node_or_null("PixelGlove")

func _ready() -> void:
	spawn_position = global_position
	respawn_position = global_position
	# Safe collision layer setup: Player is on Layer 1, collides with Layer 2 (Terrain)
	collision_layer = 1
	collision_mask = 2

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return

	# 1. Update timers
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		if not was_on_floor:
			landed.emit()
			is_jumping = false
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	# 2. Read inputs
	var move_axis: float = 0.0
	var jump_pressed: bool = false
	var jump_released: bool = false
	var aim_up_pressed: bool = false
	var aim_down_pressed: bool = false
	var interact_pressed: bool = false

	if use_simulated_input:
		move_axis = simulated_move_axis
		jump_pressed = simulated_jump_just_pressed
		jump_released = simulated_jump_just_released
		aim_up_pressed = simulated_aim_up
		aim_down_pressed = simulated_aim_down
		interact_pressed = simulated_interact_just_pressed
		# Consume one-shot simulated triggers
		simulated_jump_just_pressed = false
		simulated_jump_just_released = false
		simulated_interact_just_pressed = false
	else:
		move_axis = Input.get_axis("move_left", "move_right")
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_released = Input.is_action_just_released("jump")
		aim_up_pressed = Input.is_action_pressed("aim_up")
		aim_down_pressed = Input.is_action_pressed("aim_down")
		interact_pressed = Input.is_action_just_pressed("interact")

	# 3. Facing & Aiming
	if move_axis > 0.05:
		facing_direction = 1
		if sprite:
			sprite.flip_h = false
	elif move_axis < -0.05:
		facing_direction = -1
		if sprite:
			sprite.flip_h = true

	var aim_y: int = 0
	if aim_up_pressed:
		aim_y = -1
	elif aim_down_pressed:
		aim_y = 1

	aim_offset = Vector2i(facing_direction, aim_y)

	# 4. Jump buffer registration
	if jump_pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME

	# 5. Jump execution (with coyote time and buffer)
	if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		execute_jump()

	# 6. Variable jump height (early release cutoff)
	if jump_released and velocity.y < 0.0 and is_jumping:
		velocity.y *= VARIABLE_JUMP_CUTOFF

	# 7. Gravity integration
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, TERMINAL_VELOCITY)

	# 8. Horizontal acceleration / friction
	var current_accel: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var current_friction: float = FRICTION if is_on_floor() else AIR_FRICTION

	if absf(move_axis) > 0.05:
		var target_speed: float = move_axis * RUN_SPEED
		velocity.x = move_toward(velocity.x, target_speed, current_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_friction * delta)

	# 9. Perform physics slide
	was_on_floor = is_on_floor()
	move_and_slide()

	# 9b. Check landing on spring platforms
	if is_on_floor():
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			if col.get_normal().y < -0.7:
				var collider = col.get_collider()
				if collider != null and collider.has_method("on_player_landed"):
					collider.on_player_landed(self)

	# 10. Interact with Pixel Glove
	if interact_pressed:
		if glove and glove.has_method("try_interact"):
			glove.try_interact()

	# 11. Check bottom boundary death
	if global_position.y > 600.0:
		die()

func execute_jump() -> void:
	velocity.y = JUMP_VELOCITY
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	is_jumping = true
	jumped.emit()

func bounce(launch_velocity: float = -370.0) -> void:
	velocity.y = launch_velocity
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	is_jumping = true
	bounced.emit(launch_velocity)

func die() -> void:
	velocity = Vector2.ZERO
	global_position = respawn_position
	died.emit()

func set_respawn_position(pos: Vector2) -> void:
	respawn_position = pos

func get_target_cell() -> Vector2i:
	var target_world_pos: Vector2 = global_position + Vector2(aim_offset.x * 16.0, aim_offset.y * 16.0)
	var cell_x: int = int(floor(target_world_pos.x / 16.0))
	var cell_y: int = int(floor(target_world_pos.y / 16.0))
	return Vector2i(cell_x, cell_y)

func get_player_bounds() -> Rect2:
	# 10x14 centered box relative to global position
	return Rect2(global_position.x - 5.0, global_position.y - 7.0, 10.0, 14.0)
