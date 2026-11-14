class_name TitleScreen extends Control

signal start_adventure_pressed
signal chapter_select_pressed
signal settings_pressed

@onready var click_prompt: Button = $ClickToStartOverlay
@onready var menu_container: VBoxContainer = $MenuContainer

func _ready() -> void:
	for child in find_children("*", "Button"):
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
			
	# Click to Start prompt ensures web audio context unlocks
	if click_prompt:
		click_prompt.visible = true
		click_prompt.pressed.connect(_on_click_to_start)
	if menu_container:
		menu_container.visible = false

func _on_click_to_start() -> void:
	if click_prompt:
		click_prompt.visible = false
	if menu_container:
		menu_container.visible = true

func _on_start_pressed() -> void:
	start_adventure_pressed.emit()

func _on_chapters_pressed() -> void:
	chapter_select_pressed.emit()

func _on_settings_pressed() -> void:
	settings_pressed.emit()
