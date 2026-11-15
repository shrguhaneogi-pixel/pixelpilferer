class_name TitleScreen extends Control

signal continue_game_pressed
signal new_game_pressed
signal chapter_select_pressed
signal settings_pressed

@onready var click_prompt: Button = $ClickToStartOverlay
@onready var menu_container: VBoxContainer = $MenuContainer

@onready var continue_btn: Button = $MenuContainer/ContinueButton
@onready var new_game_btn: Button = $MenuContainer/NewGameButton
@onready var chapters_btn: Button = $MenuContainer/ChaptersButton
@onready var settings_btn: Button = $MenuContainer/SettingsButton
@onready var credits_btn: Button = $MenuContainer/CreditsButton
@onready var quit_btn: Button = $MenuContainer/QuitButton

@onready var confirm_modal: ConfirmModal = $ConfirmModal
@onready var credits_modal: CreditsModal = $CreditsModal

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

	if confirm_modal:
		confirm_modal.visible = false
		confirm_modal.confirmed.connect(_on_new_game_confirmed)
		
	if credits_modal:
		credits_modal.visible = false

	if quit_btn and OS.has_feature("web"):
		quit_btn.visible = false
		
	update_button_states()

func update_button_states() -> void:
	var has_save: bool = ProgressService.has_saved_game()
	if continue_btn:
		continue_btn.disabled = not has_save
		if has_save:
			var target: Dictionary = ProgressService.get_continue_target()
			var lid: String = target.get("level_id", "ch1_01")
			continue_btn.text = "Continue (%s)" % lid
			continue_btn.modulate = Color(0.9, 1.0, 0.9)
		else:
			continue_btn.text = "Continue"
			continue_btn.modulate = Color(0.6, 0.6, 0.6, 0.6)

func _on_click_to_start() -> void:
	if click_prompt:
		click_prompt.visible = false
	if menu_container:
		menu_container.visible = true
	update_button_states()

func _on_continue_pressed() -> void:
	continue_game_pressed.emit()

func _on_new_game_pressed() -> void:
	if ProgressService.has_saved_game():
		if confirm_modal:
			confirm_modal.prompt("Start a New Game?\nExisting campaign progress will be reset.")
	else:
		_on_new_game_confirmed()

func _on_new_game_confirmed() -> void:
	ProgressService.reset_progress()
	update_button_states()
	new_game_pressed.emit()

func _on_chapters_pressed() -> void:
	chapter_select_pressed.emit()

func _on_settings_pressed() -> void:
	settings_pressed.emit()

func _on_credits_pressed() -> void:
	if credits_modal:
		credits_modal.visible = true

func _on_quit_pressed() -> void:
	if not OS.has_feature("web"):
		get_tree().quit()
