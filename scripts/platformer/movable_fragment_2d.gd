class_name MovableFragment2D extends StaticBody2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const GhostFrame2D = preload("res://scripts/platformer/ghost_frame_2d.gd")
const BLOCKS_TEX = preload("res://assets/sprites/blocks.png")
const SPRING_REST_TEX = preload("res://assets/gameplay/spring_rest.png")
const SPRING_COMP_TEX = preload("res://assets/gameplay/spring_compressed.png")

enum State {
	HOME,
	CARRIED,
	PLACED,
	TRIGGERED,
	RETURNING,
	ANCHORED
}

signal state_changed(old_state: State, new_state: State)
signal bounced(player: PlayerPlatformer)
signal returned_home()
signal return_deferred_due_to_overlap()

const COLOR_TINTS = {
	0: Color("#d0c8b0"),
	1: Color("#3b9eff"),
	2: Color("#ffa32b"),
	3: Color("#ff4297"),
	4: Color("#2de082")
}

const COLOR_RUNES = {
	0: "◆",
	1: "▲",
	2: "■",
	3: "●",
	4: "✚"
}

@export var color: int = 0
@export var rune_symbol: String = "◆"
@export var bounce_velocity: float = -370.0

var home_cell: Vector2i = Vector2i.ZERO
var current_cell: Vector2i = Vector2i.ZERO
var state: State = State.HOME

var ghost_frame: GhostFrame2D = null
var is_restoration_deferred: bool = false
var player_ref: PlayerPlatformer = null
var tween: Tween = null

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var spring_sensor: Area2D = get_node_or_null("SpringSensor")

func _ready() -> void:
	collision_layer = 2 # Terrain/Solid
	collision_mask = 1  # Player

	home_cell = Vector2i(int(round((position.x - 8.0) / 16.0)), int(round((position.y - 8.0) / 16.0)))
	current_cell = home_cell

	if rune_symbol == "":
		rune_symbol = COLOR_RUNES.get(color, "◆")

	setup_internal_nodes()
	setup_ghost_frame()
	apply_state_visuals()

func setup_internal_nodes() -> void:
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		var box = RectangleShape2D.new()
		box.size = Vector2(16.0, 16.0)
		collision_shape.shape = box
		add_child(collision_shape)

	if sprite == null:
		sprite = Sprite2D.new()
		sprite.texture = BLOCKS_TEX
		sprite.modulate = COLOR_TINTS.get(color, Color.WHITE)
		add_child(sprite)

	var label = get_node_or_null("Label")
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.text = rune_symbol
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(16.0, 16.0)
		label.position = Vector2(-8.0, -8.0)
		label.modulate = Color.BLACK
		add_child(label)

	if spring_sensor == null:
		spring_sensor = Area2D.new()
		spring_sensor.name = "SpringSensor"
		spring_sensor.collision_layer = 4
		spring_sensor.collision_mask = 1
		var sensor_shape = CollisionShape2D.new()
		var sensor_box = RectangleShape2D.new()
		# Thin horizontal trigger plate on top surface (width 14px, height 4px, centered at y = -8)
		sensor_box.size = Vector2(14.0, 4.0)
		sensor_shape.shape = sensor_box
		sensor_shape.position = Vector2(0.0, -8.0)
		spring_sensor.add_child(sensor_shape)
		add_child(spring_sensor)

	if not spring_sensor.body_entered.is_connected(_on_spring_sensor_body_entered):
		spring_sensor.body_entered.connect(_on_spring_sensor_body_entered)

func setup_ghost_frame() -> void:
	ghost_frame = GhostFrame2D.new()
	ghost_frame.name = "GhostFrame_%d_%d" % [home_cell.x, home_cell.y]
	ghost_frame.color = color
	ghost_frame.rune_symbol = rune_symbol
	ghost_frame.position = Vector2(home_cell.x * 16.0 + 8.0, home_cell.y * 16.0 + 8.0)
	ghost_frame.visible = false
	get_parent().call_deferred("add_child", ghost_frame)

func _physics_process(_delta: float) -> void:
	# 1. Check if Pip has launched into the air after triggering spring
	if state == State.TRIGGERED:
		if player_ref:
			var player_launched: bool = player_ref.velocity.y < 0.0 or not player_ref.is_on_floor()
			var player_distance: float = player_ref.global_position.distance_to(global_position)
			if player_launched or player_distance > 18.0:
				start_snapback()

	# 2. Check deferred restoration at home cell
	if is_restoration_deferred:
		var home_rect = Rect2(home_cell.x * 16.0, home_cell.y * 16.0, 16.0, 16.0)
		var is_obstructed: bool = false
		if player_ref:
			is_obstructed = player_ref.get_player_bounds().intersects(home_rect)
		if not is_obstructed:
			finalize_home_restoration()

func transition_to(new_state: State) -> bool:
	if state == new_state:
		return true

	# State validation matrix
	var valid: bool = false
	match state:
		State.HOME:
			valid = (new_state == State.CARRIED)
		State.CARRIED:
			valid = (new_state == State.PLACED or new_state == State.ANCHORED or new_state == State.HOME)
		State.PLACED:
			valid = (new_state == State.CARRIED or new_state == State.TRIGGERED or new_state == State.HOME)
		State.TRIGGERED:
			valid = (new_state == State.RETURNING or new_state == State.HOME)
		State.RETURNING:
			valid = (new_state == State.HOME)
		State.ANCHORED:
			valid = (new_state == State.CARRIED or new_state == State.HOME)

	if not valid:
		printerr("Invalid MovableFragment2D state transition: %s -> %s" % [state, new_state])
		return false

	var old_state = state
	state = new_state
	apply_state_visuals()
	state_changed.emit(old_state, new_state)
	return true

func apply_state_visuals() -> void:
	var lbl = get_node_or_null("Label")
	match state:
		State.HOME:
			visible = true
			modulate.a = 1.0
			scale = Vector2.ONE
			position = Vector2(home_cell.x * 16.0 + 8.0, home_cell.y * 16.0 + 8.0)
			if collision_shape:
				collision_shape.set_deferred("disabled", false)
			if ghost_frame:
				ghost_frame.visible = false
			is_restoration_deferred = false
			if sprite:
				sprite.texture = BLOCKS_TEX
				sprite.modulate = COLOR_TINTS.get(color, Color.WHITE)
			if lbl:
				lbl.visible = true

		State.CARRIED:
			visible = false
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
			if ghost_frame:
				ghost_frame.visible = true

		State.PLACED:
			visible = true
			modulate.a = 1.0
			scale = Vector2.ONE
			if collision_shape:
				collision_shape.set_deferred("disabled", false)
			if ghost_frame:
				ghost_frame.visible = true
			if sprite:
				sprite.texture = SPRING_REST_TEX
				sprite.modulate = Color.WHITE
			if lbl:
				lbl.visible = false

		State.TRIGGERED:
			visible = true
			if ghost_frame:
				ghost_frame.visible = true
			if sprite:
				sprite.texture = SPRING_COMP_TEX
				sprite.modulate = Color.WHITE
			if lbl:
				lbl.visible = false

		State.RETURNING:
			visible = true
			if collision_shape:
				collision_shape.set_deferred("disabled", true)
			if ghost_frame:
				ghost_frame.visible = true
			if sprite:
				sprite.texture = BLOCKS_TEX
				sprite.modulate = COLOR_TINTS.get(color, Color.WHITE)
			if lbl:
				lbl.visible = true

		State.ANCHORED:
			visible = true
			modulate.a = 1.0
			scale = Vector2.ONE
			if collision_shape:
				collision_shape.set_deferred("disabled", false)
			if ghost_frame:
				ghost_frame.visible = true
			if sprite:
				sprite.texture = BLOCKS_TEX
				sprite.modulate = COLOR_TINTS.get(color, Color.WHITE)
			if lbl:
				lbl.visible = true

	queue_redraw()

func _on_spring_sensor_body_entered(_body: Node2D) -> void:
	pass

func on_player_landed(p: PlayerPlatformer) -> void:
	if state != State.PLACED:
		return
	if p == null:
		return

	# Only launch if player was falling/landing onto the spring from above
	if p.velocity.y < 20.0 and p.was_on_floor:
		return

	# Only trigger bounce if player is above block center
	if p.global_position.y > global_position.y:
		return

	player_ref = p
	p.bounce(bounce_velocity)
	bounced.emit(p)
	transition_to(State.TRIGGERED)

	# Squash & Stretch animation
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 0.65), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.85, 1.15), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)

func start_snapback() -> void:
	if state != State.TRIGGERED:
		return

	transition_to(State.RETURNING)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var target_home_pos: Vector2 = Vector2(home_cell.x * 16.0 + 8.0, home_cell.y * 16.0 + 8.0)

	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	# Fast, snappy return arc/line
	tween.tween_property(self, "position", target_home_pos, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(self._on_snapback_arrived)

func _on_snapback_arrived() -> void:
	var home_rect = Rect2(home_cell.x * 16.0, home_cell.y * 16.0, 16.0, 16.0)
	var is_obstructed: bool = false
	if player_ref:
		is_obstructed = player_ref.get_player_bounds().intersects(home_rect)

	if is_obstructed:
		# Defer collision restoration safely until Pip moves away
		is_restoration_deferred = true
		modulate.a = 0.4
		return_deferred_due_to_overlap.emit()
	else:
		finalize_home_restoration()

func finalize_home_restoration() -> void:
	is_restoration_deferred = false
	current_cell = home_cell
	transition_to(State.HOME)
	returned_home.emit()

func reset_to_home() -> void:
	if tween and tween.is_valid():
		tween.kill()
	is_restoration_deferred = false
	current_cell = home_cell
	state = State.HOME
	apply_state_visuals()

func _draw() -> void:
	# If PLACED: draw top spring plate indicator
	if state == State.PLACED or state == State.TRIGGERED:
		var spring_col = Color(1.0, 0.9, 0.3) # Bright yellow spring indicator
		# Spring coil lines
		draw_line(Vector2(-6.0, -8.0), Vector2(6.0, -8.0), spring_col, 2.0)
		draw_line(Vector2(-4.0, -10.0), Vector2(4.0, -10.0), spring_col, 1.5)
		draw_line(Vector2(-2.0, -12.0), Vector2(2.0, -12.0), spring_col, 1.0)
