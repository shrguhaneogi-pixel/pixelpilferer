class_name SettingsMenu extends Control

signal settings_closed(updated_settings: Dictionary)

@onready var sfx_volume_slider: HSlider = $Panel/VBox/SFXVolumeRow/HSlider
@onready var sfx_enable_check: CheckBox = $Panel/VBox/SFXEnableRow/CheckBox
@onready var music_volume_slider: HSlider = $Panel/VBox/MusicVolumeRow/HSlider
@onready var music_enable_check: CheckBox = $Panel/VBox/MusicEnableRow/CheckBox
@onready var reduced_motion_check: CheckBox = $Panel/VBox/MotionRow/CheckBox
@onready var shake_check: CheckBox = $Panel/VBox/ShakeRow/CheckBox
@onready var high_contrast_check: CheckBox = $Panel/VBox/HighContrastRow/CheckBox

var current_settings: Dictionary = {}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var data := ProgressService.load_progress()
	current_settings = data.get("settings", {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 0.8,
		"sfx_enabled": true,
		"music_enabled": true,
		"reduced_motion": false,
		"screen_shake": true
	})
	
	if sfx_volume_slider:
		sfx_volume_slider.value = current_settings.get("sfx_volume", 1.0) * 100.0
	if sfx_enable_check:
		sfx_enable_check.button_pressed = current_settings.get("sfx_enabled", true)
	if music_volume_slider:
		music_volume_slider.value = current_settings.get("music_volume", 0.8) * 100.0
	if music_enable_check:
		music_enable_check.button_pressed = current_settings.get("music_enabled", true)
	if reduced_motion_check:
		reduced_motion_check.button_pressed = current_settings.get("reduced_motion", false)
	if shake_check:
		shake_check.button_pressed = current_settings.get("screen_shake", true)
	if high_contrast_check:
		high_contrast_check.button_pressed = current_settings.get("high_contrast", false)

func save_and_close() -> void:
	if sfx_volume_slider:
		current_settings["sfx_volume"] = sfx_volume_slider.value / 100.0
	if sfx_enable_check:
		current_settings["sfx_enabled"] = sfx_enable_check.button_pressed
	if music_volume_slider:
		current_settings["music_volume"] = music_volume_slider.value / 100.0
	if music_enable_check:
		current_settings["music_enabled"] = music_enable_check.button_pressed
	if reduced_motion_check:
		current_settings["reduced_motion"] = reduced_motion_check.button_pressed
	if shake_check:
		current_settings["screen_shake"] = shake_check.button_pressed
	if high_contrast_check:
		current_settings["high_contrast"] = high_contrast_check.button_pressed
		
	var data := ProgressService.load_progress()
	data["settings"] = current_settings
	ProgressService.save_progress(data)
	
	settings_closed.emit(current_settings)
	visible = false

func _on_back_pressed() -> void:
	save_and_close()
