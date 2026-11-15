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
		var ch_num: int = ch["num"]
		var prefix: String = "Demo" if ch_num == 0 else "Chapter %d" % ch_num
		var status_marker: String = ""
		var count: int = ProgressService.get_chapter_completed_count(ch_num)
		var total: int = 3 if ch_num == 0 else 5
		if ProgressService.is_chapter_completed(ch_num):
			status_marker = " ★ [RESTORED %d/%d]" % [count, total]
		else:
			status_marker = " [%d/%d]" % [count, total]
		chapter_list.add_item("%s: %s%s" % [prefix, ch["title"], status_marker])
	if not chapter_list.item_selected.is_connected(_on_chapter_selected):
		chapter_list.item_selected.connect(_on_chapter_selected)

func _on_chapter_selected(index: int) -> void:
	if index >= 0 and index < CHAPTER_DATA.size():
		_select_chapter(CHAPTER_DATA[index]["num"])

func _select_chapter(ch_num: int) -> void:
	_selected_chapter = ch_num
	if chapter_desc:
		var desc_text: String = ""
		for ch in CHAPTER_DATA:
			if ch["num"] == ch_num:
				desc_text = ch["desc"]
				break
		if ProgressService.is_chapter_completed(ch_num):
			desc_text += "\n\n★ " + ProgressService.get_chapter_restoration_text(ch_num)
		chapter_desc.text = desc_text
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
		btn.custom_minimum_size = Vector2(130, 32)
		
		var is_unlocked: bool = ProgressService.is_level_unlocked(_selected_chapter, lvl_idx)
		var is_done: bool = completed.has(lvl_id)
		
		var label_str: String = ""
		if _selected_chapter == 0:
			label_str = "Demo %d" % (lvl_idx + 1)
		else:
			label_str = "Level %d-%d" % [_selected_chapter, lvl_idx + 1]
			
		if is_done:
			var turns: int = completed[lvl_id]
			var medal: String = ProgressService.get_level_medal(lvl_id, turns)
			var symbol: String = ProgressService.get_medal_symbol(medal)
			btn.text = "%s %s (%d)" % [label_str, symbol, turns]
			match medal:
				"Gold":
					btn.modulate = Color(1.0, 0.95, 0.6)
				"Silver":
					btn.modulate = Color(0.85, 0.92, 1.0)
				"Bronze":
					btn.modulate = Color(0.95, 0.82, 0.7)
				_:
					btn.modulate = Color(0.9, 1.0, 0.8)
			btn.disabled = false
		elif is_unlocked:
			btn.text = label_str
			btn.modulate = Color(1.0, 1.0, 1.0)
			btn.disabled = false
		else:
			btn.text = "%s [Locked]" % label_str
			btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
			btn.disabled = true
			
		var captured_ch: int = _selected_chapter
		var captured_idx: int = lvl_idx
		btn.pressed.connect(func(): level_selected.emit(captured_ch, captured_idx))
		level_grid.add_child(btn)

func _on_back_pressed() -> void:
	back_to_title_pressed.emit()
