class_name ChapterSelect extends Control

signal level_selected(chapter_num: int, level_index: int)
signal back_to_title_pressed

@onready var chapter_list: ItemList = $Panel/VBox/HBox/ChapterList
@onready var level_grid: GridContainer = $Panel/VBox/HBox/ScrollContainer/LevelGrid
@onready var chapter_desc: Label = $Panel/VBox/DescriptionLabel

const CHAPTER_DATA = [
	{
		"num": 1,
		"title": "The Stolen Street",
		"desc": "Dim twilight streets with glowing neon circuits. Master the art of block theft and basic bridging."
	},
	{
		"num": 2,
		"title": "The Broken Bridges",
		"desc": "Indigo voids and skyway ruins. Leapfrog across expansive chasms by stealing back your bridges."
	},
	{
		"num": 3,
		"title": "The Forgotten Vault",
		"desc": "Ancient obsidian corridors powered by amber energy conduits. Match chromatic sockets."
	},
	{
		"num": 4,
		"title": "The Chromatic Core",
		"desc": "The sacred heart of the grid. Harmonize Cyan, Amber, Magenta, and Emerald fragments."
	}
]

var _selected_chapter: int = 1

func _ready() -> void:
	_populate_chapters()
	_select_chapter(1)

func _populate_chapters() -> void:
	if chapter_list == null:
		return
	chapter_list.clear()
	for ch in CHAPTER_DATA:
		chapter_list.add_item("Chapter %d: %s" % [ch["num"], ch["title"]])
	chapter_list.item_selected.connect(_on_chapter_selected)

func _on_chapter_selected(index: int) -> void:
	_select_chapter(index + 1)

func _select_chapter(ch_num: int) -> void:
	_selected_chapter = ch_num
	if chapter_desc:
		chapter_desc.text = CHAPTER_DATA[ch_num - 1]["desc"]
	_populate_levels()

func _populate_levels() -> void:
	if level_grid == null:
		return
	for child in level_grid.get_children():
		child.queue_free()
		
	var progress := SaveManager.load_progress()
	var completed: Dictionary = progress.get("completed_levels", {})
	
	for lvl_idx in range(5):
		var lvl_id: String = "ch%d_0%d" % [_selected_chapter, lvl_idx + 1]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 32)
		
		var is_done: bool = completed.has(lvl_id)
		var text: String = "Level %d-%d" % [_selected_chapter, lvl_idx + 1]
		if is_done:
			text += " (%d turns)" % completed[lvl_id]
			
		btn.text = text
		btn.pressed.connect(func(): level_selected.emit(_selected_chapter, lvl_idx))
		level_grid.add_child(btn)

func _on_back_pressed() -> void:
	back_to_title_pressed.emit()
