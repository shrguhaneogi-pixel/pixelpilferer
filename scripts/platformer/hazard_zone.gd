class_name HazardZone extends Area2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")

signal player_entered(hazard: HazardZone)

@export var hazard_type: String = "spikes" # spikes, void, pit

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 # Player is Layer 1
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerPlatformer:
		player_entered.emit(self)

func _draw() -> void:
	# If no children, draw retro pixel spikes
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col and col.shape is RectangleShape2D:
		var rect_shape: RectangleShape2D = col.shape as RectangleShape2D
		var half_w: float = rect_shape.size.x * 0.5
		var half_h: float = rect_shape.size.y * 0.5
		var spike_color: Color = Color(0.9, 0.25, 0.25)
		var num_spikes: int = int(rect_shape.size.x / 8.0)
		for i in range(num_spikes):
			var sx: float = -half_w + i * 8.0
			var pts = PackedVector2Array([
				Vector2(sx, half_h),
				Vector2(sx + 4.0, -half_h),
				Vector2(sx + 8.0, half_h)
			])
			draw_polygon(pts, PackedColorArray([spike_color, spike_color, spike_color]))
