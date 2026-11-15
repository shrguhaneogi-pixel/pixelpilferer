class_name MainGame extends Node2D

## Main entry orchestrator for Pixel Pilferer.
## Manages TitleScreen, ChapterSelect, GameController, HUD, PauseMenu, and SettingsMenu.

var _current_chapter: int = 0
var _current_level_idx: int = 0

var game_controller: GameController
var hud_node: HUD
var title_screen: TitleScreen
var chapter_select: ChapterSelect
var settings_menu: SettingsMenu
var pause_menu: PauseMenu

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
	game_controller.menu_requested.connect(_open_pause_menu)
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
		hud_node.retry_pressed.connect(func(): game_controller.handle_restart())
		hud_node.undo_pressed.connect(func(): game_controller.handle_undo())
		hud_node.hint_pressed.connect(func(): game_controller.handle_hint())
		hud_node.pause_pressed.connect(_open_pause_menu)
		hud_node.chapter_select_pressed.connect(_show_chapter_select)
		hud_node.next_level_pressed.connect(_advance_next_level)
		hud_node.tutorial_dismissed.connect(_on_tutorial_dismissed)
		canvas.add_child(hud_node)
		hud_node.visible = false
	
	# Pause Menu
	var pause_packed = load("res://scenes/ui/pause_menu.tscn")
	if pause_packed:
		pause_menu = pause_packed.instantiate() as PauseMenu
		pause_menu.name = "PauseMenu"
		pause_menu.resume_pressed.connect(_on_pause_resume)
		pause_menu.restart_pressed.connect(_on_pause_restart)
		pause_menu.hint_pressed.connect(_on_pause_hint)
		pause_menu.settings_pressed.connect(_show_settings)
		pause_menu.chapter_select_pressed.connect(_on_pause_chapter_select)
		pause_menu.title_screen_pressed.connect(_on_pause_title_screen)
		canvas.add_child(pause_menu)
		pause_menu.visible = false

	# Title Screen
	var title_packed = load("res://scenes/ui/title_screen.tscn")
	if title_packed:
		title_screen = title_packed.instantiate() as TitleScreen
		title_screen.name = "TitleScreen"
		title_screen.continue_game_pressed.connect(_on_continue_game)
		title_screen.new_game_pressed.connect(_on_new_game)
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
		game_controller.audio.master_volume = s.get("master_volume", 1.0)
		game_controller.audio.sfx_enabled = s.get("sfx_enabled", true)
		game_controller.audio.sfx_volume = s.get("sfx_volume", 1.0)
		game_controller.audio.music_enabled = s.get("music_enabled", true)
		game_controller.audio.music_volume = s.get("music_volume", 0.8)
		game_controller.audio.update_music_volume()
		if game_controller.audio.music_enabled:
			game_controller.audio.start_music()
		else:
			game_controller.audio.stop_music()
	if game_controller:
		var rm: bool = s.get("reduced_motion", false)
		var ss: bool = s.get("screen_shake", true)
		game_controller.reduced_motion = rm
		if game_controller.renderer:
			game_controller.renderer.reduced_motion = rm
			game_controller.renderer.screen_shake_enabled = ss

func _show_title_screen() -> void:
	if title_screen:
		title_screen.update_button_states()
		title_screen.visible = true
	if chapter_select: chapter_select.visible = false
	if settings_menu: settings_menu.visible = false
	if pause_menu: pause_menu.visible = false
	if hud_node: hud_node.visible = false
	if game_controller and game_controller.renderer: game_controller.renderer.visible = false

func _show_chapter_select() -> void:
	if title_screen: title_screen.visible = false
	if chapter_select:
		chapter_select.visible = true
		chapter_select._populate_chapters()
		chapter_select._populate_levels()
	if settings_menu: settings_menu.visible = false
	if pause_menu: pause_menu.visible = false
	if hud_node: hud_node.visible = false
	if game_controller and game_controller.renderer: game_controller.renderer.visible = false

func _show_settings() -> void:
	if settings_menu:
		settings_menu.load_settings()
		settings_menu.visible = true

func _on_settings_closed(_settings: Dictionary) -> void:
	_apply_saved_settings()

func _on_continue_game() -> void:
	var target: Dictionary = ProgressService.get_continue_target()
	_load_specific_level(target.get("chapter", 1), target.get("level_idx", 0))

func _on_new_game() -> void:
	_load_specific_level(0, 0)

func _open_pause_menu() -> void:
	if pause_menu and hud_node and hud_node.visible:
		if game_controller:
			game_controller.set_paused(true)
		pause_menu.visible = true

func _on_pause_resume() -> void:
	if pause_menu:
		pause_menu.visible = false
	if game_controller:
		game_controller.set_paused(false)

func _on_pause_restart() -> void:
	_on_pause_resume()
	if game_controller:
		game_controller.handle_restart()

func _on_pause_hint() -> void:
	_on_pause_resume()
	if game_controller:
		game_controller.handle_hint()

func _on_pause_chapter_select() -> void:
	if pause_menu:
		pause_menu.visible = false
	if game_controller:
		game_controller.set_paused(false)
	_show_chapter_select()

func _on_pause_title_screen() -> void:
	if pause_menu:
		pause_menu.visible = false
	if game_controller:
		game_controller.set_paused(false)
	_show_title_screen()

func _on_tutorial_dismissed() -> void:
	var lvl: Dictionary = LevelRepository.load_level(_current_chapter, _current_level_idx)
	var lvl_id: String = lvl.get("id", "")
	if lvl_id != "":
		ProgressService.mark_tutorial_seen(lvl_id)

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
	if pause_menu: pause_menu.visible = false
	
	if game_controller:
		game_controller.set_paused(false)
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
		
		# Check for tutorial hint
		var lvl_id: String = lvl.get("id", "")
		if not ProgressService.is_tutorial_seen(lvl_id):
			var tut: String = ProgressService.get_tutorial_text(lvl_id)
			if tut != "":
				hud_node.show_tutorial(tut)
			else:
				hud_node.hide_tutorial()
		else:
			hud_node.hide_tutorial()
			
		if game_controller and game_controller.model:
			hud_node.update_state(game_controller.model.get_state())

func _on_turn_updated(turns: int) -> void:
	if hud_node:
		hud_node.update_turn_count(turns)

func _on_state_updated(state: BoardState) -> void:
	if hud_node:
		hud_node.update_state(state)
		# Auto-dismiss tutorial after player makes an active turn
		if state.turn_count > 0 and hud_node.tutorial_panel and hud_node.tutorial_panel.visible:
			_on_tutorial_dismissed()
			hud_node.hide_tutorial()

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
	var is_chapter_ending := (_current_level_idx + 1 >= levels.size())
	var is_campaign_ending := (_current_chapter == 4 and is_chapter_ending)
	if is_chapter_ending and game_controller and game_controller.audio:
		game_controller.audio.play_chapter_restored()
	if hud_node:
		hud_node.show_win(turns, lvl_id, is_campaign_ending, ProgressService.get_total_moves())

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
