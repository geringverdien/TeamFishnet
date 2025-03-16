extends Control

onready var dialog = $WindowDialog
onready var tree = $WindowDialog/Tree
onready var button = $Button
onready var closeButton = dialog.get_close_button()

onready var menuOpen = dialog.visible

func _on_WindowDialog_popup_hide():
	menuOpen = false

func _on_Button_pressed():
	if menuOpen: return
	menuOpen = true
	dialog.popup_centered()
