class_name ConfirmModal extends Control

signal confirmed
signal cancelled

@onready var message_label: Label = $Panel/Margin/VBox/MessageLabel
@onready var confirm_btn: Button = $Panel/Margin/VBox/HBox/ConfirmBtn
@onready var cancel_btn: Button = $Panel/Margin/VBox/HBox/CancelBtn

func _ready() -> void:
	if confirm_btn:
		confirm_btn.focus_mode = Control.FOCUS_NONE
		confirm_btn.pressed.connect(_on_confirm_pressed)
	if cancel_btn:
		cancel_btn.focus_mode = Control.FOCUS_NONE
		cancel_btn.pressed.connect(_on_cancel_pressed)

func prompt(message: String) -> void:
	if message_label:
		message_label.text = message
	visible = true

func _on_confirm_pressed() -> void:
	visible = false
	confirmed.emit()

func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
