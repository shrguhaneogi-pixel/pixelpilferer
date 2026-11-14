class_name SettingsMenu extends Control

signal settings_closed(updated_settings: Dictionary)

@onready var volume_slider: HSlider = $Panel/VBox/VolumeRow/HSlider
@onready var sfx_check: CheckBox = $Panel/VBox/SFXRow/CheckBox
@onready var reduced_motion_check: CheckBox = $Panel/VBox/MotionRow/CheckBox

var current_settings: Dictionary = {}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var data := SaveManager.load_progress()
	current_settings = data.get("settings", {
		"sfx_volume": 1.0,
		"sfx_enabled": true,
		"reduced_motion": false
	})
	
	if volume_slider:
		volume_slider.value = current_settings.get("sfx_volume", 1.0) * 100.0
	if sfx_check:
		sfx_check.button_pressed = current_settings.get("sfx_enabled", true)
	if reduced_motion_check:
		reduced_motion_check.button_pressed = current_settings.get("reduced_motion", false)

func save_and_close() -> void:
	if volume_slider:
		current_settings["sfx_volume"] = volume_slider.value / 100.0
	if sfx_check:
		current_settings["sfx_enabled"] = sfx_check.button_pressed
	if reduced_motion_check:
		current_settings["reduced_motion"] = reduced_motion_check.button_pressed
		
	var data := SaveManager.load_progress()
	data["settings"] = current_settings
	SaveManager.save_progress(data)
	
	settings_closed.emit(current_settings)
	visible = false

func _on_back_pressed() -> void:
	save_and_close()
