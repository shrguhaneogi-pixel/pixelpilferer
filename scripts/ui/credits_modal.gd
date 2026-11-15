class_name CreditsModal extends Control

signal closed

@onready var close_btn: Button = $Panel/Margin/VBox/CloseBtn

func _ready() -> void:
	if close_btn:
		close_btn.focus_mode = Control.FOCUS_NONE
		close_btn.pressed.connect(_on_close_pressed)

func _on_close_pressed() -> void:
	visible = false
	closed.emit()
