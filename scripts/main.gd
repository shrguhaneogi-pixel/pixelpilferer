class_name MainGame extends Node2D

var _current_chapter: int = 1
var _current_level_idx: int = 0
var _chapter_data: Array = []

var level_view: LevelView
var hud_node: HUD
var title_screen: TitleScreen
var chapter_select: ChapterSelect
var settings_menu: SettingsMenu

func _ready() -> void:
	_load_all_chapters()
	_instantiate_ui_nodes()
	_apply_saved_settings()
	_show_title_screen()

func _load_all_chapters() -> void:
	_chapter_data.clear()
	for ch_num in range(1, 5):
		var path := "res://data/levels/ch%d_levels.json" % ch_num
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				_chapter_data.append(json.data)
			file.close()

func _instantiate_ui_nodes() -> void:
	# 1. Level View
	level_view = LevelView.new()
	level_view.name = "LevelView"
	level_view.level_completed.connect(_on_level_completed)
	level_view.turn_changed.connect(_on_turn_changed)
	level_view.hint_requested.connect(_on_hint_requested)
	add_child(level_view)
	level_view.visible = false
	
	# 2. CanvasLayer UI containers
	var canvas := CanvasLayer.new()
	canvas.name = "GameCanvas"
	add_child(canvas)
	
	# HUD
	hud_node = HUD.new()
	hud_node.name = "HUD"
	hud_node.restart_pressed.connect(func(): level_view._handle_restart())
	hud_node.undo_pressed.connect(func(): level_view._handle_undo())
	hud_node.hint_pressed.connect(func(): level_view._handle_hint())
	hud_node.menu_pressed.connect(_show_chapter_select)
	hud_node.next_level_pressed.connect(_advance_next_level)
	canvas.add_child(hud_node)
	hud_node.visible = false
	
	# Title Screen
	title_screen = TitleScreen.new()
	title_screen.name = "TitleScreen"
	title_screen.start_adventure_pressed.connect(_start_adventure)
	title_screen.chapter_select_pressed.connect(_show_chapter_select)
	title_screen.settings_pressed.connect(_show_settings)
	canvas.add_child(title_screen)
	
	# Chapter Select
	chapter_select = ChapterSelect.new()
	chapter_select.name = "ChapterSelect"
	chapter_select.level_selected.connect(_load_specific_level)
	chapter_select.back_to_title_pressed.connect(_show_title_screen)
	canvas.add_child(chapter_select)
	chapter_select.visible = false
	
	# Settings Menu
	settings_menu = SettingsMenu.new()
	settings_menu.name = "SettingsMenu"
	settings_menu.settings_closed.connect(_on_settings_closed)
	canvas.add_child(settings_menu)
	settings_menu.visible = false

func _apply_saved_settings() -> void:
	var progress := SaveManager.load_progress()
	var s: Dictionary = progress.get("settings", {})
	if level_view and level_view.audio_mgr:
		level_view.audio_mgr.sfx_enabled = s.get("sfx_enabled", true)
		level_view.audio_mgr.sfx_volume = s.get("sfx_volume", 1.0)
	if level_view:
		level_view.reduced_motion = s.get("reduced_motion", false)

func _show_title_screen() -> void:
	title_screen.visible = true
	chapter_select.visible = false
	settings_menu.visible = false
	hud_node.visible = false
	level_view.visible = false

func _show_chapter_select() -> void:
	title_screen.visible = false
	chapter_select.visible = true
	settings_menu.visible = false
	hud_node.visible = false
	level_view.visible = false
	chapter_select._populate_levels()

func _show_settings() -> void:
	settings_menu.load_settings()
	settings_menu.visible = true

func _on_settings_closed(settings: Dictionary) -> void:
	_apply_saved_settings()

func _start_adventure() -> void:
	_load_specific_level(1, 0)

func _load_specific_level(chapter_num: int, level_idx: int) -> void:
	_current_chapter = chapter_num
	_current_level_idx = level_idx
	
	if _current_chapter - 1 >= _chapter_data.size():
		return
		
	var ch_dict: Dictionary = _chapter_data[_current_chapter - 1]
	var levels: Array = ch_dict.get("levels", [])
	if _current_level_idx >= levels.size():
		return
		
	var lvl: Dictionary = levels[_current_level_idx]
	
	title_screen.visible = false
	chapter_select.visible = false
	settings_menu.visible = false
	
	level_view.visible = true
	level_view.load_level(lvl)
	
	hud_node.visible = true
	hud_node.set_level_info(lvl.get("name", "Untitled"), _current_chapter)
	hud_node.update_turn_count(0)
	hud_node.hide_hint()
	hud_node.hide_win()

func _on_turn_changed(turns: int) -> void:
	hud_node.update_turn_count(turns)

func _on_hint_requested(hint_text: String) -> void:
	hud_node.show_hint(hint_text)

func _on_level_completed() -> void:
	var ch_dict: Dictionary = _chapter_data[_current_chapter - 1]
	var lvl: Dictionary = ch_dict["levels"][_current_level_idx]
	var lvl_id: String = lvl["id"]
	var turns: int = level_view.current_state.turn_count
	
	# Determine next level id
	var next_id: String = ""
	if _current_level_idx + 1 < ch_dict["levels"].size():
		next_id = ch_dict["levels"][_current_level_idx + 1]["id"]
	elif _current_chapter < 4:
		next_id = "ch%d_01" % (_current_chapter + 1)
		
	SaveManager.mark_level_completed(lvl_id, turns, next_id)
	hud_node.show_win(turns)

func _advance_next_level() -> void:
	var ch_dict: Dictionary = _chapter_data[_current_chapter - 1]
	if _current_level_idx + 1 < ch_dict["levels"].size():
		_load_specific_level(_current_chapter, _current_level_idx + 1)
	elif _current_chapter < 4:
		_load_specific_level(_current_chapter + 1, 0)
	else:
		# Campaign Complete!
		_show_chapter_select()
