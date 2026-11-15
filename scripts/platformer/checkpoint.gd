class_name Checkpoint extends Area2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")

signal checkpoint_activated(checkpoint: Checkpoint)

@export var checkpoint_id: String = ""
var is_active: bool = false

@onready var visual: Node2D = get_node_or_null("Visual")

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 # Player is Layer 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	update_visual()

func _on_body_entered(body: Node2D) -> void:
	if is_active:
		return
	if body is PlayerPlatformer:
		activate()

func activate() -> void:
	is_active = true
	update_visual()
	checkpoint_activated.emit(self)

func reset() -> void:
	is_active = false
	update_visual()

func update_visual() -> void:
	if visual:
		visual.modulate = Color(0.2, 0.9, 0.4) if is_active else Color(0.5, 0.6, 0.7, 0.6)
	queue_redraw()

func _draw() -> void:
	if visual == null:
		# Fallback direct draw for beacon pole & flag
		var base_color: Color = Color(0.18, 0.88, 0.45) if is_active else Color(0.4, 0.5, 0.6, 0.7)
		# Pole
		draw_line(Vector2(0, 8), Vector2(0, -12), Color(0.3, 0.3, 0.3), 2.0)
		# Flag
		var pts = PackedVector2Array([
			Vector2(0, -12),
			Vector2(10, -8),
			Vector2(0, -4)
		])
		draw_polygon(pts, PackedColorArray([base_color, base_color, base_color]))
