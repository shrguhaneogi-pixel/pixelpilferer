class_name PixelCamera extends Camera2D

## Integer-snapping 2D camera with optional subtle screen shake.

@export var target: Node2D
@export var follow_speed: float = 12.0
@export var smooth_follow: bool = true

var _shake_offset: Vector2 = Vector2.ZERO
var _shake_tween: Tween

func _process(delta: float) -> void:
	if target == null:
		return
		
	if smooth_follow:
		var desired_pos: Vector2 = global_position.lerp(target.global_position, follow_speed * delta)
		global_position = desired_pos.round() + _shake_offset
	else:
		global_position = target.global_position.round() + _shake_offset

func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position.round()

func shake(intensity: float = 1.5, duration: float = 0.12) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_method(func(val: float):
		_shake_offset = Vector2(randf_range(-val, val), randf_range(-val, val)).round()
	, intensity, 0.0, duration)
	_shake_tween.tween_callback(func():
		_shake_offset = Vector2.ZERO
	)
