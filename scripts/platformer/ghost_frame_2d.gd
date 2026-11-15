class_name GhostFrame2D extends Node2D

@export var color: int = 0
@export var rune_symbol: String = "◆"

const COLOR_TINTS = {
	0: Color("#d0c8b0"),
	1: Color("#3b9eff"),
	2: Color("#ffa32b"),
	3: Color("#ff4297"),
	4: Color("#2de082")
}

var pulse_time: float = 0.0

func _process(delta: float) -> void:
	if visible:
		pulse_time += delta
		queue_redraw()

func _draw() -> void:
	var base_col: Color = COLOR_TINTS.get(color, Color.WHITE)
	var alpha: float = 0.4 + 0.25 * sin(pulse_time * 4.0)
	var outline_col: Color = Color(base_col.r, base_col.g, base_col.b, alpha)

	# 16x16 dashed outline (-8 to +8)
	var rect = Rect2(-7.5, -7.5, 15.0, 15.0)
	draw_rect(rect, outline_col, false, 1.0)

	# Corner tick marks for tech/glove aesthetic
	draw_line(Vector2(-7.5, -7.5), Vector2(-4.5, -7.5), outline_col, 1.5)
	draw_line(Vector2(-7.5, -7.5), Vector2(-7.5, -4.5), outline_col, 1.5)

	draw_line(Vector2(7.5, -7.5), Vector2(4.5, -7.5), outline_col, 1.5)
	draw_line(Vector2(7.5, -7.5), Vector2(7.5, -4.5), outline_col, 1.5)

	draw_line(Vector2(-7.5, 7.5), Vector2(-4.5, 7.5), outline_col, 1.5)
	draw_line(Vector2(-7.5, 7.5), Vector2(-7.5, 4.5), outline_col, 1.5)

	draw_line(Vector2(7.5, 7.5), Vector2(4.5, 7.5), outline_col, 1.5)
	draw_line(Vector2(7.5, 7.5), Vector2(7.5, 4.5), outline_col, 1.5)

	# Center dot / faint rune mark
	draw_circle(Vector2.ZERO, 1.5, Color(base_col.r, base_col.g, base_col.b, alpha * 0.7))
