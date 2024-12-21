extends Control

# Declare references for UI elements
onready var file_dialog = $FileDialog
onready var text_box = $Panel/TextEdit  # Use TextEdit if displaying multi-line content
onready var button = $Panel/Open

func _ready():
	file_dialog.add_filter("*.gd ; GDScript Files")
	# Connect the file dialog's file_selected signal
	file_dialog.connect("file_selected", self, "_on_file_selected")

	# Connect the button's pressed signal
	button.connect("pressed", self, "_on_open_file_button_pressed")

# Open the file dialog when the button is pressed
func _on_open_file_button_pressed():
	file_dialog.popup_centered()

# Handle the file selection
func _on_file_selected(path):
	var file = File.new()
	if file.file_exists(path):
		if file.open(path, File.READ) == OK:
			# Read the file contents and set the text box's text
			text_box.text = file.get_as_text()
		else:
			print("Failed to open file:", path)
		file.close()
	else:
		print("File does not exist:", path)
