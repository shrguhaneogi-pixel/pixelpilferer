class_name ExitPortal extends Area2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")

signal level_completed()

@export var is_locked: bool = false
var is_completed: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 # Player is Layer 1
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_completed or is_locked:
		return
	if body is PlayerPlatformer:
		is_completed = true
		level_completed.emit()
