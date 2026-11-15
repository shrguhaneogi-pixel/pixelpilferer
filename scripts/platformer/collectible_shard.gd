class_name CollectibleShard extends Area2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")

signal collected(shard: CollectibleShard)

@export var shard_id: String = ""
@export var sprite_texture: Texture2D = null
var is_collected: bool = false
var base_position: Vector2 = Vector2.ZERO
var anim_time: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	base_position = position
	collision_layer = 4
	collision_mask = 1 # Player is Layer 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if sprite_texture and sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = sprite_texture
		add_child(sprite)

func _process(delta: float) -> void:
	if not is_collected:
		anim_time += delta
		position.y = base_position.y + sin(anim_time * 5.0) * 2.5
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body is PlayerPlatformer:
		collect()

func collect() -> void:
	is_collected = true
	visible = false
	set_deferred("monitoring", false)
	collected.emit(self)

func reset() -> void:
	is_collected = false
	visible = true
	position = base_position
	set_deferred("monitoring", true)
	queue_redraw()

func _draw() -> void:
	if is_collected or (sprite and sprite.texture):
		return
	# Draw diamond pixel shard
	var diamond_pts = PackedVector2Array([
		Vector2(0, -6),
		Vector2(5, 0),
		Vector2(0, 6),
		Vector2(-5, 0)
	])
	var gold = Color(1.0, 0.85, 0.2)
	var shine = Color(1.0, 1.0, 0.7)
	draw_polygon(diamond_pts, PackedColorArray([gold, gold, gold, gold]))
	draw_line(Vector2(-1, -4), Vector2(1, -2), shine, 1.5)
