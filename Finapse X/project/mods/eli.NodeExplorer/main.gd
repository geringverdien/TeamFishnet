extends Node

func _ready():

	# Attach display to root
	var scene_navigator_path = "res://mods/eli.NodeExplorer/SceneNavigator.tscn"
	var scene_navigator_instance = load(scene_navigator_path).instance()
	get_tree().root.call_deferred("add_child", scene_navigator_instance)

	#print("Attached scene viewer to root")
