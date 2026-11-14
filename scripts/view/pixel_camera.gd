class_name PixelCamera extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 12.0
@export var smooth_follow: bool = true

func _process(delta: float) -> void:
	if target == null:
		return
		
	if smooth_follow:
		var desired_pos: Vector2 = global_position.lerp(target.global_position, follow_speed * delta)
		# Snap to exact integer pixel to eliminate subpixel jitter
		global_position = desired_pos.round()
	else:
		global_position = target.global_position.round()

func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position.round()
