extends Node

const PREFIX = "Socks"

const MODULES_LIST = {
	"Players": preload("res://mods/Toes.Socks/modules/Socks.Players/main.gd"),
	"Chat": preload("res://mods/Toes.Socks/modules/Socks.Chat/main.gd")
}

var modules = {}
func _ready():
	for module in MODULES_LIST:
		var resource = MODULES_LIST[module]

		modules[module] = resource.new()
		modules[module].set_name(module.replace(PREFIX, ""))
		add_child(modules[module])
