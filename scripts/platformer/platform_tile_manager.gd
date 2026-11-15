class_name PlatformTileManager extends Node2D

## Signals
signal block_stolen(cell: Vector2i, color: int)
signal block_placed(cell: Vector2i, color: int)

## Preloaded block visual texture
const BLOCKS_TEX = preload("res://assets/sprites/blocks.png")

## Block Color mapping to rune symbol and color tint
const COLOR_TINTS = {
	0: Color("#d0c8b0"), # Neutral
	1: Color("#3b9eff"), # Cyan
	2: Color("#ffa32b"), # Amber
	3: Color("#ff4297"), # Magenta
	4: Color("#2de082")  # Emerald
}

const COLOR_RUNES = {
	0: "◆",
	1: "▲",
	2: "■",
	3: "●",
	4: "✚"
}

## Dictionary mapping Vector2i cell -> StaticBody2D
var blocks: Dictionary = {}
var initial_snapshot: Array = []

func _ready() -> void:
	capture_initial_snapshot()

func capture_initial_snapshot() -> void:
	initial_snapshot.clear()
	for cell in blocks.keys():
		var block_data = blocks[cell].get_meta("block_data", { "color": 0, "symbol": "◆" })
		initial_snapshot.append({
			"cell": cell,
			"color": block_data["color"],
			"symbol": block_data["symbol"]
		})

func has_block(cell: Vector2i) -> bool:
	return blocks.has(cell)

func get_block_color(cell: Vector2i) -> int:
	if not blocks.has(cell):
		return -1
	var body: StaticBody2D = blocks[cell]
	var data = body.get_meta("block_data", { "color": 0 })
	return data.get("color", 0)

func remove_block(cell: Vector2i) -> Dictionary:
	if not blocks.has(cell):
		return {}

	var body: StaticBody2D = blocks[cell]
	var data: Dictionary = body.get_meta("block_data", { "color": 0, "symbol": "◆" })
	blocks.erase(cell)

	# Synchronously disable collision
	var shape: CollisionShape2D = body.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = true
	body.queue_free()

	block_stolen.emit(cell, data["color"])
	return data

func create_block(cell: Vector2i, color: int = 0, symbol: String = "") -> StaticBody2D:
	if blocks.has(cell):
		return blocks[cell]

	if symbol == "":
		symbol = COLOR_RUNES.get(color, "◆")

	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Block_%d_%d" % [cell.x, cell.y]
	# Center of 16x16 tile at cell (cell.x * 16 + 8, cell.y * 16 + 8)
	body.position = Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)
	body.collision_layer = 2 # Terrain/Solid
	body.collision_mask = 1  # Player

	# Collision Shape (16x16 box)
	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(16.0, 16.0)
	col_shape.shape = box
	body.add_child(col_shape)

	# Visual representation: Sprite or Label with rune
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = BLOCKS_TEX
	sprite.modulate = COLOR_TINTS.get(color, Color.WHITE)
	body.add_child(sprite)

	var label: Label = Label.new()
	label.text = symbol
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(16.0, 16.0)
	label.position = Vector2(-8.0, -8.0)
	label.modulate = Color.BLACK
	body.add_child(label)

	body.set_meta("block_data", { "color": color, "symbol": symbol })
	add_child(body)
	blocks[cell] = body

	block_placed.emit(cell, color)
	return body

func register_existing_block(cell: Vector2i, body: StaticBody2D, color: int = 0) -> void:
	body.collision_layer = 2
	body.collision_mask = 1
	var symbol: String = COLOR_RUNES.get(color, "◆")
	body.set_meta("block_data", { "color": color, "symbol": symbol })
	blocks[cell] = body

func reset_to_snapshot() -> void:
	# Clear all current dynamic blocks
	for cell in blocks.keys():
		var body = blocks[cell]
		if is_instance_valid(body):
			body.queue_free()
	blocks.clear()

	# Re-create blocks from initial snapshot
	for entry in initial_snapshot:
		create_block(entry["cell"], entry["color"], entry["symbol"])
