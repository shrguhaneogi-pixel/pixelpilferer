class_name ChromaticSocket extends Node2D

const PlatformTileManager = preload("res://scripts/platformer/platform_tile_manager.gd")

signal satisfaction_changed(is_satisfied: bool)

@export var socket_id: String = ""
@export var required_color: int = 1 # 0: Neutral, 1: Cyan, 2: Amber, 3: Magenta, 4: Emerald
@export var grid_cell: Vector2i = Vector2i.ZERO

var is_satisfied: bool = false

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

func _ready() -> void:
	# Tile-aligned center
	position = Vector2(grid_cell.x * 16.0 + 8.0, grid_cell.y * 16.0 + 8.0)
	queue_redraw()

func check_satisfaction(tile_manager: PlatformTileManager) -> bool:
	if not tile_manager:
		return false

	var was_satisfied = is_satisfied
	if tile_manager.has_block(grid_cell):
		var block_color = tile_manager.get_block_color(grid_cell)
		if required_color == 0 or block_color == required_color:
			is_satisfied = true
		else:
			is_satisfied = false
	else:
		is_satisfied = false

	if is_satisfied != was_satisfied:
		satisfaction_changed.emit(is_satisfied)
		queue_redraw()

	return is_satisfied

func reset() -> void:
	is_satisfied = false
	queue_redraw()

func _draw() -> void:
	var col: Color = COLOR_TINTS.get(required_color, Color.WHITE)
	var rune: String = COLOR_RUNES.get(required_color, "◆")

	# Outer socket receptacle (16x16 indented frame)
	var frame_rect: Rect2 = Rect2(-8.0, -8.0, 16.0, 16.0)
	var bg_color: Color = Color(0.12, 0.14, 0.18, 0.9)
	draw_rect(frame_rect, bg_color, true)

	var border_color: Color = col if is_satisfied else col * 0.6
	draw_rect(frame_rect, border_color, false, 1.5)

	# Rune symbol
	var rune_color: Color = col if is_satisfied else Color(col.r, col.g, col.b, 0.5)
	# Center rune line/dots
	draw_circle(Vector2.ZERO, 3.0, rune_color)
	if is_satisfied:
		# Radiant activation aura
		draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), Color(col.r, col.g, col.b, 0.3), false, 1.0)
