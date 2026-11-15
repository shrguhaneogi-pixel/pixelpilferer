class_name HUD extends CanvasLayer

signal next_level_pressed
signal restart_pressed
signal retry_pressed
signal undo_pressed
signal hint_pressed
signal pause_pressed
signal menu_pressed
signal chapter_select_pressed
signal tutorial_dismissed

@onready var title_label: Label = $TopPanel/Margin/VBox/Row1/TitleLabel
@onready var turn_label: Label = $TopPanel/Margin/VBox/Row1/MovesLabel
@onready var undo_btn: Button = $TopPanel/Margin/VBox/Row1/UndoBtn
@onready var restart_btn: Button = $TopPanel/Margin/VBox/Row1/RestartBtn
@onready var hint_btn: Button = $TopPanel/Margin/VBox/Row1/HintBtn
@onready var pause_btn: Button = $TopPanel/Margin/VBox/Row1/PauseBtn

@onready var glove_label: Label = $TopPanel/Margin/VBox/Row2/GloveSlot/GloveLabel
@onready var carried_block_rect: TextureRect = $TopPanel/Margin/VBox/Row2/GloveSlot/CarriedBlockRect
@onready var sockets_label: Label = $TopPanel/Margin/VBox/Row2/SocketsLabel
@onready var exit_label: Label = $TopPanel/Margin/VBox/Row2/ExitLabel

@onready var tutorial_panel: PanelContainer = $TutorialPanel
@onready var tutorial_label: Label = $TutorialPanel/Margin/HBox/TutorialLabel
@onready var tutorial_dismiss_btn: Button = $TutorialPanel/Margin/HBox/DismissBtn

@onready var hint_panel: PanelContainer = $HintPanel
@onready var hint_text_label: Label = $HintPanel/MarginContainer/VBox/HintText
@onready var hint_close_btn: Button = $HintPanel/MarginContainer/VBox/CloseBtn

@onready var win_modal: PanelContainer = $WinModal
@onready var win_title_label: Label = $WinModal/MarginContainer/VBox/Title
@onready var win_medal_label: Label = $WinModal/MarginContainer/VBox/MedalLabel
@onready var win_stats_label: Label = $WinModal/MarginContainer/VBox/StatsLabel
@onready var win_next_btn: Button = $WinModal/MarginContainer/VBox/ButtonsRow/NextBtn
@onready var win_retry_btn: Button = $WinModal/MarginContainer/VBox/ButtonsRow/RetryBtn
@onready var win_chapters_btn: Button = $WinModal/MarginContainer/VBox/ButtonsRow/ChaptersBtn

var _blocks_texture: Texture2D

func _ready() -> void:
	if ResourceLoader.exists("res://assets/sprites/blocks.png"):
		_blocks_texture = load("res://assets/sprites/blocks.png")

	# Ensure buttons NEVER steal keyboard focus from gameplay
	for btn in [undo_btn, restart_btn, hint_btn, pause_btn, tutorial_dismiss_btn, hint_close_btn, win_next_btn, win_retry_btn, win_chapters_btn]:
		if is_instance_valid(btn) and btn is Button:
			(btn as Button).focus_mode = Control.FOCUS_NONE

	if tutorial_panel:
		tutorial_panel.visible = false
	if hint_panel:
		hint_panel.visible = false
	if win_modal:
		win_modal.visible = false

	# Initial defaults
	update_carried_indicator({})
	if exit_label:
		exit_label.text = "Exit: OPEN"
		exit_label.modulate = Color(0.0, 1.0, 1.0)
	if sockets_label:
		sockets_label.text = "No Sockets"
		sockets_label.modulate = Color(0.7, 0.75, 0.8)

func set_level_info(level_title: String, chapter_num: int) -> void:
	if title_label:
		if chapter_num == 0:
			title_label.text = level_title
		else:
			title_label.text = "Ch %d: %s" % [chapter_num, level_title]

func update_turn_count(turns: int) -> void:
	if turn_label:
		turn_label.text = "Moves: %d" % turns

func update_state(state: BoardState) -> void:
	if state == null:
		return
	update_turn_count(state.turn_count)
	update_carried_indicator(state.carried_block)
	update_socket_and_exit_indicators(state)

func update_carried_indicator(carried_block: Dictionary) -> void:
	if glove_label == null:
		return
		
	if carried_block == null or carried_block.is_empty():
		glove_label.text = "Glove: Empty"
		glove_label.modulate = Color(0.7, 0.72, 0.8)
		if carried_block_rect:
			carried_block_rect.visible = false
	else:
		var color_idx: int = carried_block.get("color", 0)
		var c_name: String = Constants.color_name(color_idx)
		var rune: String = Constants.color_symbol(color_idx)
		glove_label.text = "Glove: %s %s Fragment" % [rune, c_name]
		glove_label.modulate = _get_color_for_block(color_idx)
		
		if carried_block_rect:
			if _blocks_texture != null:
				var atlas := AtlasTexture.new()
				atlas.atlas = _blocks_texture
				atlas.region = Rect2(clamp(color_idx, 0, 4) * 16, 0, 16, 16)
				carried_block_rect.texture = atlas
				carried_block_rect.visible = true
			else:
				carried_block_rect.visible = false

func update_socket_and_exit_indicators(state: BoardState) -> void:
	if state == null:
		return
		
	if sockets_label:
		var total_sockets: int = state.sockets.size()
		if total_sockets == 0:
			sockets_label.text = "No Sockets"
			sockets_label.modulate = Color(0.65, 0.7, 0.8)
		else:
			var active: int = 0
			for pos: Vector2i in state.sockets:
				if state.is_socket_satisfied(pos):
					active += 1
			if active == total_sockets:
				sockets_label.text = "Sockets: %d/%d (Active)" % [active, total_sockets]
				sockets_label.modulate = Color(0.02, 0.84, 0.63) # Emerald / active green
			else:
				sockets_label.text = "Sockets: %d/%d" % [active, total_sockets]
				sockets_label.modulate = Color(1.0, 0.72, 0.01) # Amber

	if exit_label:
		if state.is_all_sockets_satisfied():
			exit_label.text = "Exit: OPEN"
			exit_label.modulate = Color(0.0, 1.0, 1.0) # Radiant cyan
		else:
			exit_label.text = "Exit: LOCKED"
			exit_label.modulate = Color(1.0, 0.55, 0.15) # Amber / dim

func _get_color_for_block(color_idx: int) -> Color:
	match color_idx:
		Constants.BlockColor.NEUTRAL:
			return Color(0.85, 0.88, 0.95)
		Constants.BlockColor.CYAN:
			return Color(0.0, 1.0, 1.0)
		Constants.BlockColor.AMBER:
			return Color(1.0, 0.72, 0.01)
		Constants.BlockColor.MAGENTA:
			return Color(1.0, 0.15, 0.6)
		Constants.BlockColor.EMERALD:
			return Color(0.02, 0.9, 0.63)
		_:
			return Color.WHITE

func show_tutorial(text: String) -> void:
	if tutorial_panel and tutorial_label:
		tutorial_label.text = text
		tutorial_panel.visible = true

func hide_tutorial() -> void:
	if tutorial_panel:
		tutorial_panel.visible = false

func show_hint(text: String) -> void:
	if hint_panel and hint_text_label:
		hint_text_label.text = text
		hint_panel.visible = true

func hide_hint() -> void:
	if hint_panel:
		hint_panel.visible = false

func show_win(turns: int, level_id_or_ending: Variant = "", is_ending: bool = false, total_moves: int = 0) -> void:
	var level_id: String = ""
	if level_id_or_ending is bool:
		is_ending = level_id_or_ending
	elif level_id_or_ending is String:
		level_id = level_id_or_ending
	if win_modal and win_stats_label:
		var opt_moves: int = ProgressService.get_optimal_moves(level_id)
		var medal: String = ProgressService.get_level_medal(level_id, turns)
		var medal_symbol: String = ProgressService.get_medal_symbol(medal)
		
		if win_medal_label:
			match medal:
				"Gold":
					win_medal_label.text = "%s GOLD MEDAL (Optimal: %d moves)" % [medal_symbol, opt_moves]
					win_medal_label.modulate = Color(1.0, 0.84, 0.0) # Gold
				"Silver":
					win_medal_label.text = "%s SILVER MEDAL (+%d moves, Minimal: %d)" % [medal_symbol, max(0, turns - opt_moves), opt_moves]
					win_medal_label.modulate = Color(0.75, 0.75, 0.8) # Silver
				"Bronze":
					win_medal_label.text = "%s BRONZE MEDAL (Cleared in %d moves)" % [medal_symbol, turns]
					win_medal_label.modulate = Color(0.8, 0.5, 0.2) # Bronze
				_:
					win_medal_label.text = "LEVEL COMPLETE"
					win_medal_label.modulate = Color.WHITE

		if is_ending:
			if win_title_label:
				win_title_label.text = "THE PIXEL CORE IS RESTORED!"
				win_title_label.modulate = Color(0.0, 1.0, 1.0)
			win_stats_label.text = "★ THE PIXEL CORE IS RESTORED! ★\n\nFull spectrum radiance returns to the world.\nYou have stolen the blocks and rebuilt your escape.\n\nFinal Level: %d moves | Campaign Total: %d moves\nThank you for playing PIXEL PILFERER!" % [turns, total_moves]
		else:
			if win_title_label:
				win_title_label.text = "LEVEL CLEARED!"
				win_title_label.modulate = Color(0.02, 0.84, 0.63)
			var prev_best: int = ProgressService.get_level_best_turns(level_id)
			var best_str: String = "Best: %d moves" % (prev_best if prev_best > 0 else turns)
			win_stats_label.text = "Completed in %d moves | Optimal: %d moves\n%s" % [turns, opt_moves, best_str]
			
		win_modal.visible = true

func hide_win() -> void:
	if win_modal:
		win_modal.visible = false

func _on_undo_button_pressed() -> void:
	undo_pressed.emit()

func _on_restart_button_pressed() -> void:
	restart_pressed.emit()

func _on_hint_button_pressed() -> void:
	hint_pressed.emit()

func _on_pause_button_pressed() -> void:
	pause_pressed.emit()
	menu_pressed.emit()

func _on_dismiss_tutorial_pressed() -> void:
	hide_tutorial()
	tutorial_dismissed.emit()

func _on_next_level_button_pressed() -> void:
	hide_win()
	next_level_pressed.emit()

func _on_retry_button_pressed() -> void:
	hide_win()
	retry_pressed.emit()

func _on_win_chapters_button_pressed() -> void:
	hide_win()
	chapter_select_pressed.emit()

func _on_close_hint_pressed() -> void:
	hide_hint()
