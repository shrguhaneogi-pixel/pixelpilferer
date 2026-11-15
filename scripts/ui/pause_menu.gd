class_name PauseMenu extends Control

signal resume_pressed
signal restart_pressed
signal hint_pressed
signal settings_pressed
signal chapter_select_pressed
signal title_screen_pressed

@onready var resume_btn: Button = $Panel/Margin/VBox/ResumeBtn
@onready var restart_btn: Button = $Panel/Margin/VBox/RestartBtn
@onready var hint_btn: Button = $Panel/Margin/VBox/HintBtn
@onready var settings_btn: Button = $Panel/Margin/VBox/SettingsBtn
@onready var chapters_btn: Button = $Panel/Margin/VBox/ChaptersBtn
@onready var title_btn: Button = $Panel/Margin/VBox/TitleBtn

func _ready() -> void:
	for btn: Button in [resume_btn, restart_btn, hint_btn, settings_btn, chapters_btn, title_btn]:
		if is_instance_valid(btn):
			btn.focus_mode = Control.FOCUS_NONE

func _on_resume_pressed() -> void:
	visible = false
	resume_pressed.emit()

func _on_restart_pressed() -> void:
	visible = false
	restart_pressed.emit()

func _on_hint_pressed() -> void:
	visible = false
	hint_pressed.emit()

func _on_settings_pressed() -> void:
	settings_pressed.emit()

func _on_chapters_pressed() -> void:
	visible = false
	chapter_select_pressed.emit()

func _on_title_pressed() -> void:
	visible = false
	title_screen_pressed.emit()
