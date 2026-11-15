class_name PixelGlove extends Node2D

const PlayerPlatformer = preload("res://scripts/platformer/player_platformer.gd")
const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")

## Signals
signal steal_success(cell: Vector2i, color: int)
signal place_success(cell: Vector2i, color: int)
signal interact_rejected(reason: String)

## Exports
@export var player: PlayerPlatformer = null
@export var tile_manager: PlatformTileManager = null

## Target Indicator Node
var indicator: Node2D = null

func _ready() -> void:
	if not player and get_parent() is PlayerPlatformer:
		player = get_parent() as PlayerPlatformer
	setup_indicator()

func setup_indicator() -> void:
	indicator = Node2D.new()
	indicator.name = "TargetIndicator"
	add_child(indicator)

func _process(_delta: float) -> void:
	update_indicator_position()

func update_indicator_position() -> void:
	if not player or not indicator:
		return
	var cell: Vector2i = player.get_target_cell()
	# Center of tile in world space
	indicator.global_position = Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)
	queue_redraw()

func _draw() -> void:
	if not player:
		return
	var cell: Vector2i = player.get_target_cell()
	var cell_center: Vector2 = Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)
	var local_center: Vector2 = to_local(cell_center)
	var rect: Rect2 = Rect2(local_center.x - 8.0, local_center.y - 8.0, 16.0, 16.0)

	var in_range: bool = player.global_position.distance_to(cell_center) <= PlayerPlatformer.INTERACTION_REACH
	var color: Color = Color(0.2, 0.9, 1.0, 0.7) if in_range else Color(0.8, 0.2, 0.2, 0.4)
	draw_rect(rect, color, false, 1.0)

func try_interact() -> bool:
	if not player or not tile_manager:
		interact_rejected.emit("missing_dependencies")
		return false

	var cell: Vector2i = player.get_target_cell()
	var cell_center: Vector2 = Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)

	# 1. Reach check (<= 28.0 px)
	var dist: float = player.global_position.distance_to(cell_center)
	if dist > PlayerPlatformer.INTERACTION_REACH:
		interact_rejected.emit("out_of_reach")
		return false

	# 2. STEAL action (hand is empty)
	if player.carried_block == null:
		if not tile_manager.has_block(cell):
			interact_rejected.emit("no_block_to_steal")
			return false

		var block_data = tile_manager.remove_block(cell)
		player.carried_block = block_data
		steal_success.emit(cell, block_data["color"])
		player.block_stolen.emit(block_data["color"])
		return true

	# 3. PLACE action (hand has fragment)
	else:
		# Target must not already contain a block
		if tile_manager.has_block(cell):
			interact_rejected.emit("cell_occupied")
			return false

		# Dynamic Collision Safety: target block rect must NOT overlap player body
		var block_rect: Rect2 = Rect2(cell.x * 16.0, cell.y * 16.0, 16.0, 16.0)
		var player_bounds: Rect2 = player.get_player_bounds()
		if player_bounds.intersects(block_rect):
			interact_rejected.emit("overlaps_player")
			return false

		var color: int = player.carried_block.get("color", 0)
		var symbol: String = player.carried_block.get("symbol", "◆")
		var fragment = player.carried_block.get("fragment", null)
		var is_socket: bool = tile_manager.is_socket_cell(cell)
		tile_manager.create_block(cell, color, symbol, fragment, is_socket)

		player.carried_block = null
		place_success.emit(cell, color)
		player.block_placed.emit(color, cell)
		return true
