class_name LockedDoor extends StaticBody2D

signal door_state_changed(is_open: bool)

@export var socket_id: String = ""
@export var door_size: Vector2 = Vector2(16.0, 32.0)
@export var sprite_closed_tex: Texture2D = null
@export var sprite_open_tex: Texture2D = null
var is_open: bool = false

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	collision_layer = 2 # Solid Terrain
	collision_mask = 1  # Player
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		var box = RectangleShape2D.new()
		box.size = door_size
		collision_shape.shape = box
		add_child(collision_shape)
	if (sprite_closed_tex or sprite_open_tex) and sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	set_open(false)

func set_open(open: bool) -> void:
	is_open = open
	if collision_shape:
		collision_shape.set_deferred("disabled", open)
	if sprite:
		sprite.texture = sprite_open_tex if open else sprite_closed_tex
		visible = true
	else:
		visible = not open
	door_state_changed.emit(open)
	queue_redraw()

func reset() -> void:
	set_open(false)

func _draw() -> void:
	if is_open or sprite != null:
		return
	# Barrier visual (energy grid)
	var half_w: float = door_size.x * 0.5
	var half_h: float = door_size.y * 0.5
	var rect = Rect2(-half_w, -half_h, door_size.x, door_size.y)
	draw_rect(rect, Color(0.9, 0.3, 0.4, 0.4), true)
	draw_rect(rect, Color(1.0, 0.4, 0.5, 0.9), false, 1.5)
	# Energy scanlines
	for y in range(int(-half_h + 4.0), int(half_h), 6):
		draw_line(Vector2(-half_w + 2.0, float(y)), Vector2(half_w - 2.0, float(y)), Color(1.0, 0.8, 0.8, 0.7), 1.0)
