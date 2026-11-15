class_name BoardRenderer extends Node2D

## Displays terrain, fragments, sockets, and exits strictly driven by BoardState.

signal player_move_completed
signal portal_unlocked

@export var tile_size: int = 16
@export var screen_shake_enabled: bool = true
@export var reduced_motion: bool = false:
	set(val):
		reduced_motion = val
		if player_view:
			player_view.reduced_motion = val
		for bv: BlockView in block_views.values():
			if is_instance_valid(bv):
				bv.reduced_motion = val

# Dedicated Godot 4.7 TileMapLayers
var void_layer: TileMapLayer
var floor_layer: TileMapLayer
var socket_layer: TileMapLayer
var wall_layer: TileMapLayer
var entity_container: Node2D

var player_view: PlayerView
var exit_sprite: Sprite2D
var block_views: Dictionary = {} # Vector2i -> BlockView
var camera: PixelCamera

var terrain_tileset: TileSet
var socket_tileset: TileSet
var _last_carried_empty: bool = true
var _last_portal_open: bool = false
var _portal_tween: Tween = null

func _ready() -> void:
	if terrain_tileset == null or socket_tileset == null:
		_init_tilesets()
	if void_layer == null:
		_build_scene_tree()

func _init_tilesets() -> void:
	# 1. Terrain TileSet (tileset.png: 64x16 -> 4 tiles of 16x16)
	# Tile 0: Floor, Tile 1: Wall, Tile 2: Void, Tile 3: Bridge
	terrain_tileset = TileSet.new()
	terrain_tileset.tile_size = Vector2i(tile_size, tile_size)
	if ResourceLoader.exists("res://assets/sprites/tileset.png"):
		var t_src := TileSetAtlasSource.new()
		t_src.texture = load("res://assets/sprites/tileset.png")
		t_src.texture_region_size = Vector2i(tile_size, tile_size)
		for i in 4:
			t_src.create_tile(Vector2i(i, 0))
		terrain_tileset.add_source(t_src, 0)
		
	# 2. Socket TileSet (sockets.png: 160x16 -> 10 tiles of 16x16)
	# 5 colors x 2 states [0,1: Neutral, 2,3: Cyan, 4,5: Amber, 6,7: Magenta, 8,9: Emerald]
	socket_tileset = TileSet.new()
	socket_tileset.tile_size = Vector2i(tile_size, tile_size)
	if ResourceLoader.exists("res://assets/sprites/sockets.png"):
		var s_src := TileSetAtlasSource.new()
		s_src.texture = load("res://assets/sprites/sockets.png")
		s_src.texture_region_size = Vector2i(tile_size, tile_size)
		for i in 10:
			s_src.create_tile(Vector2i(i, 0))
		socket_tileset.add_source(s_src, 0)

func _build_scene_tree() -> void:
	void_layer = TileMapLayer.new()
	void_layer.name = "VoidLayer"
	void_layer.z_index = -3
	void_layer.tile_set = terrain_tileset
	add_child(void_layer)
	
	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.z_index = -2
	floor_layer.tile_set = terrain_tileset
	add_child(floor_layer)
	
	socket_layer = TileMapLayer.new()
	socket_layer.name = "SocketLayer"
	socket_layer.z_index = -1
	socket_layer.tile_set = socket_tileset
	add_child(socket_layer)
	
	wall_layer = TileMapLayer.new()
	wall_layer.name = "WallLayer"
	wall_layer.z_index = 3
	wall_layer.tile_set = terrain_tileset
	add_child(wall_layer)
	
	entity_container = Node2D.new()
	entity_container.name = "EntityContainer"
	entity_container.y_sort_enabled = true
	add_child(entity_container)
	
	exit_sprite = Sprite2D.new()
	if ResourceLoader.exists("res://assets/sprites/exit_portal.png"):
		exit_sprite.texture = load("res://assets/sprites/exit_portal.png")
	exit_sprite.hframes = 2
	exit_sprite.frame = 0
	exit_sprite.centered = true
	exit_sprite.z_index = 0
	entity_container.add_child(exit_sprite)
	
	player_view = PlayerView.new()
	player_view.name = "PlayerView"
	player_view.z_index = 2
	player_view.reduced_motion = reduced_motion
	player_view.move_completed.connect(func(): player_move_completed.emit())
	entity_container.add_child(player_view)
	
	camera = PixelCamera.new()
	camera.name = "PixelCamera"
	camera.target = player_view
	add_child(camera)
	if is_inside_tree():
		camera.make_current()

func apply_chapter_theme(chapter_num: int) -> void:
	match chapter_num:
		1:
			modulate = Color(1.0, 0.98, 0.94) # The Stolen Street: Warm amber stone
		2:
			modulate = Color(0.92, 0.96, 1.05) # The Broken Bridges: Deep skyway oceanic
		3:
			modulate = Color(0.98, 0.93, 1.05) # The Forgotten Vault: Obsidian violet
		4:
			modulate = Color(1.04, 1.02, 1.05) # The Chromatic Core: Full spectrum radiance
		_:
			modulate = Color(1.0, 1.0, 1.0) # Demo / Neutral

func setup_board(state: BoardState) -> void:
	if terrain_tileset == null or socket_tileset == null:
		_init_tilesets()
	if void_layer == null:
		_build_scene_tree()
	else:
		if void_layer.tile_set == null: void_layer.tile_set = terrain_tileset
		if floor_layer.tile_set == null: floor_layer.tile_set = terrain_tileset
		if wall_layer.tile_set == null: wall_layer.tile_set = terrain_tileset
		if socket_layer.tile_set == null: socket_layer.tile_set = socket_tileset

	void_layer.clear()
	floor_layer.clear()
	socket_layer.clear()
	wall_layer.clear()
	
	# Render base terrain
	for pos: Vector2i in state.tiles:
		var t: int = state.tiles[pos]
		match t:
			Constants.TileType.FLOOR:
				floor_layer.set_cell(pos, 0, Vector2i(0, 0))
			Constants.TileType.WALL:
				wall_layer.set_cell(pos, 0, Vector2i(1, 0))
			Constants.TileType.VOID:
				void_layer.set_cell(pos, 0, Vector2i(2, 0))
	
	# Position Exit Portal
	if state.exit_cell != Vector2i(-1, -1):
		exit_sprite.position = Vector2(state.exit_cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)
		exit_sprite.visible = true
	else:
		exit_sprite.visible = false
		
	_last_carried_empty = not state.is_carrying()
	_last_portal_open = state.is_all_sockets_satisfied()
	update_view(state, true)

func update_view(state: BoardState, snap: bool = false) -> void:
	if void_layer == null:
		_build_scene_tree()
		
	# 1. Update Sockets layer
	socket_layer.clear()
	for pos: Vector2i in state.sockets:
		var col: int = state.sockets[pos]
		var is_satisfied: bool = state.is_socket_satisfied(pos)
		var frame_idx: int = col * 2 + (1 if is_satisfied else 0)
		socket_layer.set_cell(pos, 0, Vector2i(frame_idx, 0))
		
	# 2. Update Bridges in void
	for pos: Vector2i in state.tiles:
		if state.tiles[pos] == Constants.TileType.VOID:
			if state.is_bridge_at(pos):
				floor_layer.set_cell(pos, 0, Vector2i(3, 0))
			else:
				floor_layer.erase_cell(pos)
				
	# 3. Exit portal open/locked state & event
	var is_portal_now_open: bool = state.is_all_sockets_satisfied()
	if is_portal_now_open != _last_portal_open:
		if is_portal_now_open:
			exit_sprite.frame = 1
			if not snap and not reduced_motion and is_inside_tree():
				_animate_portal_open()
				trigger_screen_shake(1.5, 0.14)
			portal_unlocked.emit()
		else:
			exit_sprite.frame = 0
			exit_sprite.scale = Vector2.ONE
		_last_portal_open = is_portal_now_open
	else:
		exit_sprite.frame = 1 if is_portal_now_open else 0
		if not is_portal_now_open:
			exit_sprite.scale = Vector2.ONE
		
	# 4. Movable Blocks
	if snap:
		for pos: Vector2i in block_views:
			var bv: BlockView = block_views[pos]
			if is_instance_valid(bv):
				bv.queue_free()
		block_views.clear()
		
		for pos: Vector2i in state.blocks:
			var b_data: Dictionary = state.blocks[pos]
			var bv := BlockView.new()
			bv.reduced_motion = reduced_motion
			entity_container.add_child(bv)
			bv.setup(b_data["id"], b_data["color"], b_data["is_bridge"], pos)
			block_views[pos] = bv
	else:
		# Check removed blocks (stolen)
		var removed_positions: Array[Vector2i] = []
		for pos: Vector2i in block_views:
			if not state.blocks.has(pos):
				removed_positions.append(pos)
				
		for pos: Vector2i in removed_positions:
			var bv: BlockView = block_views[pos]
			block_views.erase(pos)
			if is_instance_valid(bv):
				bv.animate_steal(func():
					if is_instance_valid(bv):
						bv.queue_free()
				)
				
		# Check added or existing blocks
		for pos: Vector2i in state.blocks:
			var b_data: Dictionary = state.blocks[pos]
			if block_views.has(pos):
				var bv: BlockView = block_views[pos]
				if is_instance_valid(bv):
					bv.setup(b_data["id"], b_data["color"], b_data["is_bridge"], pos)
			else:
				var bv := BlockView.new()
				bv.reduced_motion = reduced_motion
				entity_container.add_child(bv)
				bv.setup(b_data["id"], b_data["color"], b_data["is_bridge"], pos)
				block_views[pos] = bv
				bv.animate_placement()
				if state.sockets.has(pos) and state.is_socket_satisfied(pos):
					bv.pulse_socket_activation()
					
	# 5. Player actor updates
	if snap:
		player_view.snap_to_cell(state.player_pos, state.player_facing)
		player_view.update_carried_visual(state.carried_block)
		if camera:
			camera.snap_to_target()
	else:
		player_view.animate_move(state.player_pos, state.player_facing)
		if _last_carried_empty and state.is_carrying():
			player_view.animate_steal(state.player_pos + state.player_facing, state.carried_block.get("color", 0))
		elif not _last_carried_empty and not state.is_carrying():
			player_view.animate_placement(state.player_pos + state.player_facing)
		else:
			player_view.update_carried_visual(state.carried_block)
			
	_last_carried_empty = not state.is_carrying()

func _animate_portal_open() -> void:
	if _portal_tween and _portal_tween.is_valid():
		_portal_tween.kill()
	exit_sprite.scale = Vector2(0.6, 0.6)
	_portal_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_portal_tween.tween_property(exit_sprite, ^"scale", Vector2(1.2, 1.2), 0.15)
	_portal_tween.chain().tween_property(exit_sprite, ^"scale", Vector2.ONE, 0.12)

func trigger_screen_shake(intensity: float = 1.5, duration: float = 0.12) -> void:
	if reduced_motion or not screen_shake_enabled or camera == null:
		return
	camera.shake(intensity, duration)

func animate_player_move(target_cell: Vector2i, facing: Vector2i) -> void:
	if player_view:
		player_view.animate_move(target_cell, facing)

func snap_player(cell: Vector2i, facing: Vector2i) -> void:
	if player_view:
		player_view.snap_to_cell(cell, facing)
	if camera:
		camera.snap_to_target()

func animate_invalid_bump(facing: Vector2i) -> void:
	if player_view:
		player_view.animate_invalid_bump(facing)

func animate_victory(on_complete: Callable = Callable()) -> void:
	if player_view:
		player_view.animate_victory(on_complete)

func kill_all_tweens() -> void:
	if _portal_tween and _portal_tween.is_valid():
		_portal_tween.kill()
		_portal_tween = null
	if player_view:
		player_view.cancel_tweens()
	for bv: BlockView in block_views.values():
		if is_instance_valid(bv):
			bv.cancel_tweens()
