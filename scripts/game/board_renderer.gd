class_name BoardRenderer extends Node2D

## Displays terrain, fragments, sockets, and exits using dedicated TileMapLayers.

@export var tile_size: int = 16
@export var reduced_motion: bool = false

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

func _ready() -> void:
	_build_scene_tree()

func _build_scene_tree() -> void:
	void_layer = TileMapLayer.new()
	void_layer.name = "VoidLayer"
	void_layer.z_index = -3
	add_child(void_layer)
	
	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.z_index = -2
	add_child(floor_layer)
	
	socket_layer = TileMapLayer.new()
	socket_layer.name = "SocketLayer"
	socket_layer.z_index = -1
	add_child(socket_layer)
	
	wall_layer = TileMapLayer.new()
	wall_layer.name = "WallLayer"
	wall_layer.z_index = 3
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
	entity_container.add_child(player_view)
	
	camera = PixelCamera.new()
	camera.name = "PixelCamera"
	camera.target = player_view
	add_child(camera)
	camera.make_current()

func setup_board(state: BoardState) -> void:
	void_layer.clear()
	floor_layer.clear()
	socket_layer.clear()
	wall_layer.clear()
	
	if state.exit_cell != Vector2i(-1, -1):
		exit_sprite.position = Vector2(state.exit_cell * tile_size) + Vector2(tile_size * 0.5, tile_size * 0.5)
		exit_sprite.visible = true
	else:
		exit_sprite.visible = false
		
	update_view(state, true)

func update_view(state: BoardState, snap: bool = false) -> void:
	# Clean up outdated block views
	for pos: Vector2i in block_views:
		var bv: BlockView = block_views[pos]
		if is_instance_valid(bv):
			bv.queue_free()
	block_views.clear()
	
	# Instantiate block views
	for pos: Vector2i in state.blocks:
		var b_data: Dictionary = state.blocks[pos]
		var bv := BlockView.new()
		bv.reduced_motion = reduced_motion
		entity_container.add_child(bv)
		bv.setup(b_data["id"], b_data["color"], b_data["is_bridge"], pos)
		block_views[pos] = bv
		
	if snap:
		player_view.snap_to_cell(state.player_pos, state.player_facing)
		camera.snap_to_target()
	else:
		player_view.animate_move(state.player_pos, state.player_facing)
		
	player_view.update_carried_visual(state.carried_block)
	
	if state.is_all_sockets_satisfied():
		exit_sprite.frame = 1
	else:
		exit_sprite.frame = 0

func animate_player_move(target_cell: Vector2i, facing: Vector2i) -> void:
	player_view.animate_move(target_cell, facing)

func snap_player(cell: Vector2i, facing: Vector2i) -> void:
	player_view.snap_to_cell(cell, facing)
	camera.snap_to_target()
