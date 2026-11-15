class_name PlatformTileManager extends Node2D

const MovableFragment2D = preload("res://scripts/platformer/movable_fragment_2d.gd")

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

## Dictionary mapping Vector2i cell -> Node2D (StaticBody2D or MovableFragment2D)
var blocks: Dictionary = {}
var initial_snapshot: Array = []
var socket_cells: Array[Vector2i] = []

func _ready() -> void:
	for child in get_children():
		if child is MovableFragment2D:
			var frag = child as MovableFragment2D
			var cell: Vector2i = frag.home_cell
			blocks[cell] = frag
			if not frag.returned_home.is_connected(_on_fragment_returned_home):
				frag.returned_home.connect(_on_fragment_returned_home.bind(frag))
		elif child is StaticBody2D and (child.name.begins_with("Block") or child.has_meta("block_data")):
			var cell_x: int = int(round((child.position.x - 8.0) / 16.0))
			var cell_y: int = int(round((child.position.y - 8.0) / 16.0))
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			var color: int = 0
			if child.has_meta("color"):
				color = child.get_meta("color")
			elif child.has_meta("block_data"):
				color = child.get_meta("block_data").get("color", 0)
			register_existing_block(cell, child, color)
	capture_initial_snapshot()

func _on_fragment_returned_home(fragment: MovableFragment2D) -> void:
	# Clean up any placed cell reference
	var cells_to_clean: Array[Vector2i] = []
	for c in blocks.keys():
		if blocks[c] == fragment and c != fragment.home_cell:
			cells_to_clean.append(c)
	for c in cells_to_clean:
		blocks.erase(c)
		block_stolen.emit(c, fragment.color)

	blocks[fragment.home_cell] = fragment
	block_placed.emit(fragment.home_cell, fragment.color)

func register_socket_cell(cell: Vector2i) -> void:
	if not socket_cells.has(cell):
		socket_cells.append(cell)

func is_socket_cell(cell: Vector2i) -> bool:
	return socket_cells.has(cell)

func capture_initial_snapshot() -> void:
	initial_snapshot = capture_snapshot()

func capture_snapshot() -> Array:
	var snap: Array = []
	for cell in blocks.keys():
		var body = blocks[cell]
		if is_instance_valid(body):
			if body is MovableFragment2D:
				snap.append({
					"cell": cell,
					"color": body.color,
					"symbol": body.rune_symbol,
					"is_fragment": true,
					"fragment": body
				})
			else:
				var block_data = body.get_meta("block_data", { "color": 0, "symbol": "◆" })
				snap.append({
					"cell": cell,
					"color": block_data["color"],
					"symbol": block_data["symbol"],
					"is_fragment": false
				})
	return snap

func has_block(cell: Vector2i) -> bool:
	return blocks.has(cell)

func get_block_color(cell: Vector2i) -> int:
	if not blocks.has(cell):
		return -1
	var body = blocks[cell]
	if body is MovableFragment2D:
		return body.color
	var data = body.get_meta("block_data", { "color": 0 })
	return data.get("color", 0)

func remove_block(cell: Vector2i) -> Dictionary:
	if not blocks.has(cell):
		return {}

	var body = blocks[cell]
	blocks.erase(cell)

	if body is MovableFragment2D:
		body.transition_to(MovableFragment2D.State.CARRIED)
		var data = {
			"color": body.color,
			"symbol": body.rune_symbol,
			"fragment": body
		}
		block_stolen.emit(cell, body.color)
		return data
	else:
		var data: Dictionary = body.get_meta("block_data", { "color": 0, "symbol": "◆" })
		var shape: CollisionShape2D = body.get_node_or_null("CollisionShape2D")
		if shape:
			shape.disabled = true
		body.queue_free()
		block_stolen.emit(cell, data["color"])
		return data

func create_block(cell: Vector2i, color: int = 0, symbol: String = "", fragment = null, is_socket: bool = false) -> Node2D:
	if blocks.has(cell):
		return blocks[cell]

	if fragment != null and fragment is MovableFragment2D:
		var frag = fragment as MovableFragment2D
		frag.position = Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)
		frag.current_cell = cell
		if is_socket:
			frag.transition_to(MovableFragment2D.State.ANCHORED)
		else:
			frag.transition_to(MovableFragment2D.State.PLACED)
		blocks[cell] = frag
		block_placed.emit(cell, color)
		return frag

	if symbol == "":
		symbol = COLOR_RUNES.get(color, "◆")

	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Block_%d_%d" % [cell.x, cell.y]
	body.position = Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)
	body.collision_layer = 2 # Terrain/Solid
	body.collision_mask = 1  # Player

	var col_shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(16.0, 16.0)
	col_shape.shape = box
	body.add_child(col_shape)

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
	restore_snapshot(initial_snapshot)

func restore_snapshot(snap: Array) -> void:
	# 1. Reset any MovableFragment2D children back to home
	for child in get_children():
		if child is MovableFragment2D:
			(child as MovableFragment2D).reset_to_home()

	# 2. Clear ordinary StaticBody2D blocks
	for cell in blocks.keys():
		var body = blocks[cell]
		if is_instance_valid(body) and not (body is MovableFragment2D):
			var shape: CollisionShape2D = body.get_node_or_null("CollisionShape2D")
			if shape:
				shape.disabled = true
			body.queue_free()
	blocks.clear()

	# 3. Re-populate blocks from snapshot
	for entry in snap:
		if entry.get("is_fragment", false):
			var frag = entry.get("fragment")
			if is_instance_valid(frag):
				blocks[entry["cell"]] = frag
		else:
			create_block(entry["cell"], entry["color"], entry["symbol"])
