class_name BlockView extends Node2D

## Visual representation of a movable chromatic block or void bridge.

@export var tile_size: int = 16
@export var reduced_motion: bool = false

var block_id: int = 0
var block_color: int = 0
var is_bridge: bool = false
var current_cell: Vector2i = Vector2i.ZERO

var _sprite: Sprite2D
var _active_tween: Tween

static var _particle_texture: Texture2D = null

static func _get_particle_texture() -> Texture2D:
	if _particle_texture == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_particle_texture = ImageTexture.create_from_image(img)
	return _particle_texture

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

func get_color_rgb() -> Color:
	match block_color:
		Constants.BlockColor.NEUTRAL:
			return Color(0.75, 0.78, 0.85)
		Constants.BlockColor.CYAN:
			return Color(0.0, 0.9, 1.0)
		Constants.BlockColor.AMBER:
			return Color(1.0, 0.72, 0.01)
		Constants.BlockColor.MAGENTA:
			return Color(1.0, 0.0, 0.5)
		Constants.BlockColor.EMERALD:
			return Color(0.02, 0.84, 0.63)
		_:
			return Color.WHITE

func cancel_tweens() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

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
	_update_visuals()
	if reduced_motion:
		return
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	var target_scale: Vector2 = Vector2(0.9, 0.9) if is_bridge else Vector2(1.0, 1.0)
	scale = Vector2(0.2, 0.2)
	_spawn_particle_burst(false)
	
	if not is_inside_tree():
		scale = target_scale
		return
		
	_active_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, ^"scale", target_scale, 0.12)

func animate_steal(on_complete: Callable = Callable()) -> void:
	if reduced_motion:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_spawn_particle_burst(true)
	
	if not is_inside_tree():
		if on_complete.is_valid():
			on_complete.call()
		return
		
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_property(self, ^"scale", Vector2(0.1, 0.1), 0.10)
	_active_tween.parallel().tween_property(self, ^"modulate:a", 0.0, 0.10)
	if on_complete.is_valid():
		_active_tween.tween_callback(on_complete)

func pulse_socket_activation() -> void:
	if reduced_motion:
		return
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	var base_scale: Vector2 = Vector2(0.9, 0.9) if is_bridge else Vector2(1.0, 1.0)
	var base_mod: Color = Color(0.85, 0.9, 1.0, 0.9) if is_bridge else Color(1.0, 1.0, 1.0, 1.0)
	var pulse_scale: Vector2 = base_scale * 1.2
	var flash_mod: Color = Color(1.6, 1.6, 1.6, 1.0)
	
	if not is_inside_tree():
		return
		
	_active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, ^"scale", pulse_scale, 0.08)
	_active_tween.parallel().tween_property(self, ^"modulate", flash_mod, 0.08)
	_active_tween.chain().tween_property(self, ^"scale", base_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.parallel().tween_property(self, ^"modulate", base_mod, 0.12)

func _spawn_particle_burst(inward: bool = false) -> void:
	if reduced_motion or not is_inside_tree():
		return
	var particles := CPUParticles2D.new()
	particles.texture = _get_particle_texture()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 8
	particles.lifetime = 0.25
	particles.color = get_color_rgb()
	particles.gravity = Vector2.ZERO
	if inward:
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 8.0
		particles.spread = 180.0
		particles.initial_velocity_min = 5.0
		particles.initial_velocity_max = 15.0
	else:
		particles.spread = 180.0
		particles.initial_velocity_min = 15.0
		particles.initial_velocity_max = 35.0
	add_child(particles)
	
	var tree := get_tree()
	if tree != null:
		var timer := tree.create_timer(particles.lifetime + 0.05)
		timer.timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)
