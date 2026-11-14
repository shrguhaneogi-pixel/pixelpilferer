class_name BlockView extends Node2D

@export var tile_size: int = 16
@export var reduced_motion: bool = false

var block_id: int = 0
var block_color: int = 0
var is_bridge: bool = false
var current_cell: Vector2i = Vector2i.ZERO

var _sprite: Sprite2D
var _active_tween: Tween

func _ready() -> void:
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/blocks.png"):
		_sprite.texture = load("res://assets/sprites/blocks.png")
	_sprite.hframes = 5
	_sprite.vframes = 1
	_sprite.centered = true
	add_child(_sprite)
	_update_visuals()

func setup(id: int, color: int, bridge: bool, cell: Vector2i) -> void:
	block_id = id
	block_color = color
	is_bridge = bridge
	current_cell = cell
	position = Vector2(cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)
	_update_visuals()

func _update_visuals() -> void:
	if _sprite == null:
		return
	_sprite.frame = clamp(block_color, 0, 4)
	if is_bridge:
		z_index = 0
		modulate = Color(0.85, 0.9, 1.0, 0.9)
		scale = Vector2(0.9, 0.9)
	else:
		z_index = 2
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = Vector2(1.0, 1.0)

func animate_placement() -> void:
	if reduced_motion or _sprite == null:
		return
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	scale = Vector2(0.2, 0.2)
	_active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, ^"scale", Vector2(1.0, 1.0), 0.12)

func animate_steal(on_complete: Callable = Callable()) -> void:
	if reduced_motion or _sprite == null:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, ^"scale", Vector2(0.1, 0.1), 0.10)
	if on_complete.is_valid():
		_active_tween.tween_callback(on_complete)
