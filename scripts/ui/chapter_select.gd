class_name ChapterSelect extends Control

signal level_selected(chapter_num: int, level_index: int)
signal back_to_title_pressed

@onready var chapter_list: ItemList = $Panel/VBox/HBox/ChapterList
@onready var level_grid: GridContainer = $Panel/VBox/HBox/ScrollContainer/LevelGrid
@onready var chapter_desc: Label = $Panel/VBox/DescriptionLabel
@onready var back_btn: Button = $Panel/VBox/Header/BackBtn

const CHAPTER_DATA = [
	{
		"num": 0,
		"title": "Tutorial & Demo",
		"desc": "Training grounds. Master block theft, void bridging, and chromatic socket activation."
	},
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

var _selected_chapter: int = 0

func _ready() -> void:
	if back_btn:
		back_btn.focus_mode = Control.FOCUS_NONE
	_populate_chapters()
	_select_chapter(0)

func _populate_chapters() -> void:
	if chapter_list == null:
		return
	chapter_list.clear()
	for ch in CHAPTER_DATA:
		if ch["num"] == 0:
			chapter_list.add_item("Demo: %s" % ch["title"])
		else:
			chapter_list.add_item("Chapter %d: %s" % [ch["num"], ch["title"]])
	chapter_list.item_selected.connect(_on_chapter_selected)

func _on_chapter_selected(index: int) -> void:
	if index >= 0 and index < CHAPTER_DATA.size():
		_select_chapter(CHAPTER_DATA[index]["num"])

func _select_chapter(ch_num: int) -> void:
	_selected_chapter = ch_num
	if chapter_desc:
		for ch in CHAPTER_DATA:
			if ch["num"] == ch_num:
				chapter_desc.text = ch["desc"]
				break
	_populate_levels()

func _populate_levels() -> void:
	if level_grid == null:
		return
	for child in level_grid.get_children():
		child.queue_free()
		
	var progress := ProgressService.load_progress()
	var completed: Dictionary = progress.get("completed_levels", {})
	
	var ch_data := LevelRepository.load_chapter(_selected_chapter)
	var levels: Array = ch_data.get("levels", [])
	
	for lvl_idx in range(levels.size()):
		var lvl: Dictionary = levels[lvl_idx]
		var lvl_id: String = lvl.get("id", "")
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(110, 32)
		
		var is_done: bool = completed.has(lvl_id)
		var label_str: String = ""
		if _selected_chapter == 0:
			label_str = "Demo %d" % (lvl_idx + 1)
		else:
			label_str = "Level %d-%d" % [_selected_chapter, lvl_idx + 1]
			
		if is_done:
			label_str += " (%d moves)" % completed[lvl_id]
			
		btn.text = label_str
		var captured_ch: int = _selected_chapter
		var captured_idx: int = lvl_idx
		btn.pressed.connect(func(): level_selected.emit(captured_ch, captured_idx))
		level_grid.add_child(btn)

func _on_back_pressed() -> void:
	back_to_title_pressed.emit()
