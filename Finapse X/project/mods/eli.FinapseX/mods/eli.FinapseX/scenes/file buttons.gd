extends Control

onready var openFileDialog = $OpenDialog
onready var saveFileDialog = $SaveDialog
onready var textBox = $Panel/TextEdit
onready var openButton = $Panel/Open
onready var saveButton = $Panel/Save

func _ready():
	var desktopPath = getDesktopPath()
	openFileDialog.current_dir = desktopPath
	saveFileDialog.current_dir = desktopPath
	openFileDialog.add_filter("*.gd ; GDScript Files")
	saveFileDialog.add_filter("*.gd ; GDScript Files")

	openFileDialog.connect("file_selected", self, "onFileSelected")
	openButton.connect("pressed", self, "onOpenFileButtonPressed")

	saveFileDialog.connect("file_selected", self, "onSaveFileSelected")
	saveButton.connect("pressed", self, "onSaveFileButtonPressed")

func onOpenFileButtonPressed():
	openFileDialog.popup_centered()

func onFileSelected(path):
	var file = File.new()
	if file.file_exists(path):
		if file.open(path, File.READ) == OK:
			textBox.text = file.get_as_text()
		else:
			print("Failed to open file:", path)
		file.close()
	else:
		print("File does not exist:", path)

func onSaveFileButtonPressed():
	saveFileDialog.popup_centered()

func onSaveFileSelected(path):
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(textBox.text)
		file.close()
		print("File saved successfully at:", path)
	else:
		print("Failed to save file at:", path)

func getDesktopPath():
	var desktopPath = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if desktopPath == "":
		desktopPath = OS.get_user_data_dir()
	return desktopPath
