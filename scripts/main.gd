class_name MainGame extends Node2D

## Main entry orchestrator for Pixel Pilferer.

var _current_chapter: int = 0
var _current_level_idx: int = 0

var game_controller: GameController
var hud_node: HUD
var title_screen: TitleScreen
var chapter_select: ChapterSelect
var settings_menu: SettingsMenu

func _ready() -> void:
	_setup_subsystems()
	_apply_saved_settings()
	_show_title_screen()

func _setup_subsystems() -> void:
	# 1. Game Controller
	game_controller = GameController.new()
	game_controller.name = "GameController"
	game_controller.level_completed.connect(_on_level_completed)
	game_controller.turn_updated.connect(_on_turn_updated)
	game_controller.state_updated.connect(_on_state_updated)
	game_controller.hint_triggered.connect(_on_hint_triggered)
	game_controller.menu_requested.connect(_show_chapter_select)
	add_child(game_controller)
	if game_controller.renderer:
		game_controller.renderer.visible = false
	
	# 2. CanvasLayer UI containers
	var canvas := CanvasLayer.new()
	canvas.name = "GameCanvas"
	add_child(canvas)
	
	# HUD
	var hud_packed = load("res://scenes/ui/hud.tscn")
	if hud_packed:
		hud_node = hud_packed.instantiate() as HUD
		hud_node.name = "HUD"
		hud_node.restart_pressed.connect(func(): game_controller.handle_restart())
		hud_node.undo_pressed.connect(func(): game_controller.handle_undo())
		hud_node.hint_pressed.connect(func(): game_controller.handle_hint())
		hud_node.menu_pressed.connect(_show_chapter_select)
		hud_node.next_level_pressed.connect(_advance_next_level)
		canvas.add_child(hud_node)
		hud_node.visible = false
	
	# Title Screen
	var title_packed = load("res://scenes/ui/title_screen.tscn")
	if title_packed:
		title_screen = title_packed.instantiate() as TitleScreen
		title_screen.name = "TitleScreen"
		title_screen.start_adventure_pressed.connect(_start_adventure)
		title_screen.chapter_select_pressed.connect(_show_chapter_select)
		title_screen.settings_pressed.connect(_show_settings)
		canvas.add_child(title_screen)
	
	# Chapter Select
	var chapter_packed = load("res://scenes/ui/chapter_select.tscn")
	if chapter_packed:
		chapter_select = chapter_packed.instantiate() as ChapterSelect
		chapter_select.name = "ChapterSelect"
		chapter_select.level_selected.connect(_load_specific_level)
		chapter_select.back_to_title_pressed.connect(_show_title_screen)
		canvas.add_child(chapter_select)
		chapter_select.visible = false
	
	# Settings Menu
	var settings_packed = load("res://scenes/ui/settings_menu.tscn")
	if settings_packed:
		settings_menu = settings_packed.instantiate() as SettingsMenu
		settings_menu.name = "SettingsMenu"
		settings_menu.settings_closed.connect(_on_settings_closed)
		canvas.add_child(settings_menu)
		settings_menu.visible = false

func _apply_saved_settings() -> void:
	var progress := ProgressService.load_progress()
	var s: Dictionary = progress.get("settings", {})
	if game_controller and game_controller.audio:
		game_controller.audio.sfx_enabled = s.get("sfx_enabled", true)
		game_controller.audio.sfx_volume = s.get("sfx_volume", 1.0)
	if game_controller:
		game_controller.reduced_motion = s.get("reduced_motion", false)
		if game_controller.renderer:
			game_controller.renderer.reduced_motion = s.get("reduced_motion", false)

func _show_title_screen() -> void:
	if title_screen: title_screen.visible = true
	if chapter_select: chapter_select.visible = false
	if settings_menu: settings_menu.visible = false
	if hud_node: hud_node.visible = false
	if game_controller and game_controller.renderer: game_controller.renderer.visible = false

func _show_chapter_select() -> void:
	if title_screen: title_screen.visible = false
	if chapter_select:
		chapter_select.visible = true
		chapter_select._populate_levels()
	if settings_menu: settings_menu.visible = false
	if hud_node: hud_node.visible = false
	if game_controller and game_controller.renderer: game_controller.renderer.visible = false

func _show_settings() -> void:
	if settings_menu:
		settings_menu.load_settings()
		settings_menu.visible = true

func _on_settings_closed(_settings: Dictionary) -> void:
	_apply_saved_settings()

func _start_adventure() -> void:
	# Launching Start Adventure starts at Demo Level 0 (demo_01)
	_load_specific_level(0, 0)

func _load_specific_level(chapter_num: int, level_idx: int) -> void:
	_current_chapter = chapter_num
	_current_level_idx = level_idx
	
	var lvl: Dictionary = LevelRepository.load_level(_current_chapter, _current_level_idx)
	if lvl.is_empty():
		printerr("MainGame: Failed to load level %d-%d" % [_current_chapter, _current_level_idx + 1])
		return
		
	if title_screen: title_screen.visible = false
	if chapter_select: chapter_select.visible = false
	if settings_menu: settings_menu.visible = false
	
	if game_controller:
		if game_controller.renderer: game_controller.renderer.visible = true
		game_controller.load_level_data(lvl)
	
	if hud_node:
		hud_node.visible = true
		var title_str: String = ""
		if _current_chapter == 0:
			title_str = "Demo %d: %s" % [_current_level_idx + 1, lvl.get("name", "Untitled")]
		else:
			title_str = "Level %d-%d: %s" % [_current_chapter, _current_level_idx + 1, lvl.get("name", "Untitled")]
		hud_node.set_level_info(title_str, _current_chapter)
		hud_node.update_turn_count(0)
		hud_node.hide_hint()
		hud_node.hide_win()
		if game_controller and game_controller.model:
			hud_node.update_state(game_controller.model.get_state())

func _on_turn_updated(turns: int) -> void:
	if hud_node:
		hud_node.update_turn_count(turns)

func _on_state_updated(state: BoardState) -> void:
	if hud_node:
		hud_node.update_state(state)

func _on_hint_triggered(hint_text: String) -> void:
	if hud_node:
		hud_node.show_hint(hint_text)

func _on_level_completed(turns: int) -> void:
	var lvl: Dictionary = LevelRepository.load_level(_current_chapter, _current_level_idx)
	var lvl_id: String = lvl.get("id", "demo_01" if _current_chapter == 0 else "ch1_01")
	
	var next_id: String = ""
	var ch_data := LevelRepository.load_chapter(_current_chapter)
	var levels: Array = ch_data.get("levels", [])
	
	if _current_level_idx + 1 < levels.size():
		next_id = levels[_current_level_idx + 1]["id"]
	elif _current_chapter == 0:
		next_id = "ch1_01"
	elif _current_chapter < 4:
		next_id = "ch%d_01" % (_current_chapter + 1)
		
	ProgressService.record_level_completion(lvl_id, turns, next_id)
	var is_campaign_ending := (_current_chapter == 4 and _current_level_idx + 1 >= levels.size())
	if hud_node:
		hud_node.show_win(turns, is_campaign_ending, ProgressService.get_total_moves())

func _advance_next_level() -> void:
	var ch_data := LevelRepository.load_chapter(_current_chapter)
	var levels: Array = ch_data.get("levels", [])
	
	if _current_level_idx + 1 < levels.size():
		_load_specific_level(_current_chapter, _current_level_idx + 1)
	elif _current_chapter == 0:
		# Advance from Demo (Chapter 0) to Chapter 1, Level 0
		_load_specific_level(1, 0)
	elif _current_chapter < 4:
		_load_specific_level(_current_chapter + 1, 0)
	else:
		_show_chapter_select()
