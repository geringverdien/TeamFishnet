extends Reference


onready var gdunzip = load("res://mods/eli.ModSync/gdunzip.gd")

var file = File.new()
var dir = Directory.new()
var gdwDir = getGDWeaveDir()
var tempDir = gdwDir.plus_file("ModSyncTemp")

func installMod(modID, rawData):
	var gdz = gdunzip.new()
	var modDir = tempDir.plus_file(modID)
	if not dir.dir_exists(tempDir):
		dir.make_dir(tempDir)
		
	if file.open(modDir, File.WRITE) == OK:
		file.store_buffer(rawData)		
		file.close()
		
	if file.open(modDir, File.READ) == OK:
		var loadedZip = gdz.load(modDir)
		if loadedZip:
			for f in gdunzip.files.values():
				print(f["file_name"])
	
	
	
func getGDWeaveDir() -> String: # ty PuppyGirl my beloved
	
	var game_directory := OS.get_executable_path().get_base_dir()
	var default_directory := game_directory.plus_file("GDWeave")
	var folder_override: String
	var final_directory: String

	for argument in OS.get_cmdline_args():
		if argument.begins_with("--gdweave-folder-override="):
			folder_override = argument.trim_prefix("--gdweave-folder-override=").replace("\\", "/")

	if folder_override:
		var relative_path := game_directory.plus_file(folder_override)
		var is_relative = not ":" in relative_path and file.file_exists(relative_path)

		final_directory = relative_path if is_relative else folder_override
	else:
		final_directory = default_directory

	return final_directory
