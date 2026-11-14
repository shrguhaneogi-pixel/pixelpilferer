class_name PlayerView extends Node2D

@export var tile_size: int = 16
@export var move_duration: float = 0.10
@export var reduced_motion: bool = false

var _sprite: Sprite2D
var _carried_sprite: Sprite2D
var _active_tween: Tween
var _current_cell: Vector2i = Vector2i.ZERO

func _ready() -> void:
	# Main Pip sprite
	_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/pip.png"):
		_sprite.texture = load("res://assets/sprites/pip.png")
	_sprite.hframes = 4
	_sprite.vframes = 1
	_sprite.frame = 0 # South
	_sprite.centered = true
	add_child(_sprite)
	
	# Carried block sprite floating above head
	_carried_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/blocks.png"):
		_carried_sprite.texture = load("res://assets/sprites/blocks.png")
	_carried_sprite.hframes = 5
	_carried_sprite.vframes = 1
	_carried_sprite.centered = true
	_carried_sprite.position = Vector2(0, -12)
	_carried_sprite.scale = Vector2(0.75, 0.75)
	_carried_sprite.visible = false
	add_child(_carried_sprite)

func set_facing(direction: Vector2i) -> void:
	if _sprite == null:
		return
	if direction == Constants.DIR_SOUTH:
		_sprite.frame = 0
	elif direction == Constants.DIR_EAST:
		_sprite.frame = 1
	elif direction == Constants.DIR_NORTH:
		_sprite.frame = 2
	elif direction == Constants.DIR_WEST:
		_sprite.frame = 3

func snap_to_cell(cell: Vector2i, facing: Vector2i = Constants.DIR_SOUTH) -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_current_cell = cell
	position = Vector2(cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)
	set_facing(facing)

func animate_move(target_cell: Vector2i, facing: Vector2i) -> void:
	set_facing(facing)
	_current_cell = target_cell
	var target_pos := Vector2(target_cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)
	
	if reduced_motion:
		position = target_pos
		return
		
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, ^"position", target_pos, move_duration)

func update_carried_visual(carried_block: Dictionary) -> void:
	if _carried_sprite == null:
		return
		
	if carried_block.is_empty():
		_carried_sprite.visible = false
	else:
		_carried_sprite.visible = true
		_carried_sprite.frame = carried_block.get("color", 0)
