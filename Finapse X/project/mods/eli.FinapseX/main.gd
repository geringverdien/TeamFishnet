extends Node

const KEYWORD_COLOR = Color(0.8, 0.2, 0.8)  # Purple
const FUNCTION_COLOR = Color(0.2, 0.6, 1)  # Blue
const STRING_COLOR = Color(0.2, 0.8, 0.2)  # Green
const COMMENT_COLOR = Color(0.6, 0.6, 0.6)  # Gray
const NUMBER_COLOR = Color(0.8, 0.5, 0.2)  # Orange

var PlayerAPI
var KeybindsAPI
var gds
var ingame = false
var isOpen = false
var localPlayer
var entities
var storedInputEvents = {}
var executor = preload("res://mods/eli.FinapseX/scenes/executor.tscn")
var ui = executor.instance()
var control = ui.get_node("Control")
var panel = control.get_node("Panel")
var textEdit = panel.get_node("TextEdit")
var execute = panel.get_node("Execute")
var clear = panel.get_node("Clear")
var clearCache = panel.get_node("ClearCache")

var payload = """
extends Node
var _finapseScript
var PlayerAPI 
var KeybindsAPI
var localPlayer

func customPrnt(message):
	Network._update_chat("[color=#4a4a4a]" + str(message) + "[/color]", true)
	print(message)
	

func launchPayload(selfPassed):
	_finapseScript = selfPassed
	PlayerAPI = _finapseScript.PlayerAPI
	KeybindsAPI = _finapseScript.KeybindsAPI
	
	localPlayer = PlayerAPI.local_player
	
"""

func _ready():
	ui.visible = isOpen
	while not get_node_or_null("/root/BlueberryWolfiAPIs/KeybindsAPI"): # wait for libraries
		yield(get_tree(), "idle_frame") 
	PlayerAPI = get_node_or_null("/root/BlueberryWolfiAPIs/PlayerAPI")
	KeybindsAPI = get_node_or_null("/root/BlueberryWolfiAPIs/KeybindsAPI")
	
	
	
	var toggleOpenKeybind = KeybindsAPI.register_keybind({
	  "action_name": "toggle_finapse",
	  "title": "Open/Close Finapse X",
	  "key": KEY_F1,
	})
	
	KeybindsAPI.connect(toggleOpenKeybind + "_up", self, "onKeybindPressed")
	PlayerAPI.connect("_ingame", self, "onIngame")
	PlayerAPI.connect("_playeradded", self, "playerAdded")
	PlayerAPI.connect("_player_removed", self, "playerRemoved")
	
	setupSyntaxHighlighting(textEdit)
	execute.connect("pressed", self, "onClickExecute")
	clear.connect("pressed", self, "onClickClear")
	clearCache.connect("pressed", self, "onClickClearCache")
	
func onKeybindPressed():
	if !ingame: return
	
	isOpen = !isOpen
	if isOpen:
		disableInputEvents()
	else:
		enableInputEvents()
	ui.visible = isOpen

func onIngame():
	ingame = true
	initExecutor()

func playerAdded(plr):
	if plr.name == "player":
		localPlayer = plr

func playerRemoved(plr):
	if plr.name == "player":
		ingame = false

func initExecutor():
	add_child(ui)

func disableInputEvents():
	storedInputEvents.clear()
	
	for action in InputMap.get_actions():
		if action == "toggle_finapse": continue
		var events = InputMap.get_action_list(action)
		storedInputEvents[action] = []
		
		for event in events:
			storedInputEvents[action].append(event.duplicate())
			InputMap.action_erase_event(action, event)

func enableInputEvents():
	for action in storedInputEvents.keys():
		for event in storedInputEvents[action]:
			InputMap.action_add_event(action, event)

	storedInputEvents.clear()

func loadstring(code): 
	var fullCode = payload + code
	fullCode = fullCode.strip_edges()
	
	if gds == null:
		gds = GDScript.new()
		gds.reload(true)
		
	
	
	gds.set_source_code(fullCode)
	var result
	var instance
	
	var errorMessage = ""
	var reloadRes = gds.reload(true)
	if reloadRes == OK:
		instance = gds.new()
		result = instance.launchPayload(self)
		self.add_child(instance)
	else:
		errorMessage = "[color=#ff0000]Parser error (invalid syntax)[/color]"
		Network._update_chat(errorMessage, true)
		print(errorMessage)

func onClickExecute():
	var text = textEdit.text
	var overriddenText = text.replace("print(", "customPrnt(")

	loadstring(overriddenText)
	
func onClickClear():
	textEdit.text = "func _ready():\n\t"
	
func onClickClearCache():
	for child in get_children():
		if child is CanvasLayer: continue
		child.queue_free()

func setupSyntaxHighlighting(text_edit):
	var keywords = [
		"if", "elif", "else", "for", "while", "match", 
		"break", "continue", "pass", "return", "class", "class_name",
		"extends", "as", "is" , "self", "tool", "signal", 
		"func", "static", "const", "enum", "var", "onready",
		"export", "setget", "breakpoint", "preload", "yield", "assert",
		"remote", "master", "puppet", "remotesync", "mastersync", "puppetsync",
		"PI", "TAU", "INF", "NAN", 
		"in", "not", "and", "or"
	]

	for keyword in keywords:
		text_edit.add_keyword_color(keyword, KEYWORD_COLOR)

	text_edit.add_color_region("func ", "(", FUNCTION_COLOR, false)

	text_edit.add_color_region("\"", "\"", STRING_COLOR, false)
	text_edit.add_color_region("'", "'", STRING_COLOR, false)

	text_edit.add_color_region("#", "\n", COMMENT_COLOR, true)
