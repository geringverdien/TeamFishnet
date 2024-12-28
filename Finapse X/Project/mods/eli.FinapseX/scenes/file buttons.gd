extends Control

onready var open_file_dialog = $OpenDialog
onready var save_file_dialog = $SaveDialog
onready var text_box = $Panel/TextEdit
onready var open_button = $Panel/Open
onready var save_button = $Panel/Save

func _ready():
	open_file_dialog.add_filter("*.gd ; GDScript Files")
	save_file_dialog.add_filter("*.gd ; GDScript Files")

	open_file_dialog.connect("file_selected", self, "_on_file_selected")
	open_button.connect("pressed", self, "_on_open_file_button_pressed")

	save_file_dialog.connect("file_selected", self, "_on_save_file_selected")
	save_button.connect("pressed", self, "_on_save_file_button_pressed")

func _on_open_file_button_pressed():
	open_file_dialog.popup_centered()

func _on_file_selected(path):
	var file = File.new()
	if file.file_exists(path):
		if file.open(path, File.READ) == OK:
			text_box.text = file.get_as_text()
		else:
			print("Failed to open file:", path)
		file.close()
	else:
		print("File does not exist:", path)

# Open the file dialog when the Save button is pressed
func _on_save_file_button_pressed():
	save_file_dialog.popup_centered()

# Handle the file selection for saving
func _on_save_file_selected(path):
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(text_box.text)
		file.close()
		print("File saved successfully at:", path)
	else:
		print("Failed to save file at:", path)
