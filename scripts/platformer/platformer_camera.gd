class_name PlatformerCamera extends Camera2D

@export var target: Node2D = null
@export var follow_speed: float = 6.0
@export var lookahead_distance: float = 24.0
@export var vertical_deadzone: float = 24.0

var current_target_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	position_smoothing_enabled = false # Custom integer-snapped smoothing
	if target:
		global_position = target.global_position.round()
		current_target_pos = target.global_position

func _process(delta: float) -> void:
	if not target:
		return

	var facing: float = 1.0
	if "facing_direction" in target:
		facing = float(target.facing_direction)

	var desired_x: float = target.global_position.x + (facing * lookahead_distance)
	var desired_y: float = current_target_pos.y

	# Vertical deadzone check
	var diff_y: float = target.global_position.y - current_target_pos.y
	if absf(diff_y) > vertical_deadzone:
		desired_y = target.global_position.y - (signf(diff_y) * vertical_deadzone)

	current_target_pos.x = lerpf(current_target_pos.x, desired_x, follow_speed * delta)
	current_target_pos.y = lerpf(current_target_pos.y, desired_y, (follow_speed * 0.7) * delta)

	# Clamping within level limits if set
	var final_x: float = current_target_pos.x
	var final_y: float = current_target_pos.y

	if limit_left != -10000000:
		final_x = maxf(final_x, float(limit_left) + (get_viewport_rect().size.x * 0.5))
	if limit_right != 10000000:
		final_x = minf(final_x, float(limit_right) - (get_viewport_rect().size.x * 0.5))
	if limit_top != -10000000:
		final_y = maxf(final_y, float(limit_top) + (get_viewport_rect().size.y * 0.5))
	if limit_bottom != 10000000:
		final_y = minf(final_y, float(limit_bottom) - (get_viewport_rect().size.y * 0.5))

	# Integer pixel rounding to prevent shimmer
	global_position = Vector2(roundf(final_x), roundf(final_y))
