class_name HUD extends CanvasLayer

signal next_level_pressed
signal restart_pressed
signal undo_pressed
signal hint_pressed
signal menu_pressed

@onready var title_label: Label = $TopBar/TitleLabel
@onready var turn_label: Label = $TopBar/TurnLabel
@onready var hint_panel: PanelContainer = $HintPanel
@onready var hint_text_label: Label = $HintPanel/MarginContainer/VBox/HintText
@onready var win_modal: PanelContainer = $WinModal
@onready var win_stats_label: Label = $WinModal/MarginContainer/VBox/StatsLabel

func _ready() -> void:
	if hint_panel:
		hint_panel.visible = false
	if win_modal:
		win_modal.visible = false

func set_level_info(level_title: String, chapter_num: int) -> void:
	if title_label:
		title_label.text = "Ch %d: %s" % [chapter_num, level_title]

func update_turn_count(turns: int) -> void:
	if turn_label:
		turn_label.text = "Turns: %d" % turns

func show_hint(text: String) -> void:
	if hint_panel and hint_text_label:
		hint_text_label.text = text
		hint_panel.visible = true

func hide_hint() -> void:
	if hint_panel:
		hint_panel.visible = false

func show_win(turns: int) -> void:
	if win_modal and win_stats_label:
		win_stats_label.text = "All sockets active!\nCompleted in %d turns!" % turns
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

func _on_menu_button_pressed() -> void:
	menu_pressed.emit()

func _on_next_level_button_pressed() -> void:
	hide_win()
	next_level_pressed.emit()

func _on_close_hint_pressed() -> void:
	hide_hint()
