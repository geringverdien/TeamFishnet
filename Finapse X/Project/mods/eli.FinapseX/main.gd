extends Node

const KEYWORD_COLOR = Color(0.8, 0.2, 0.8)  # Purple
const FUNCTION_COLOR = Color(0.2, 0.6, 1)  # Blue
const STRING_COLOR = Color(0.2, 0.8, 0.2)  # Green
const COMMENT_COLOR = Color(0.6, 0.6, 0.6)  # Gray
const NUMBER_COLOR = Color(0.8, 0.5, 0.2)  # Orange

var PlayerAPI
var KeybindsAPI
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
	
	get_tree().connect("node_added", self, "nodeAdded")
	setupSyntaxHighlighting(textEdit)
	execute.connect("pressed", self, "onClickExecute")
	clear.connect("pressed", self, "onClickClear")
	
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
	var script = GDScript.new()
	script.set_source_code(fullCode)
	print(fullCode)
	var result = null
	var success = true
	var instance = null
	
	var errorMessage = ""
	var reloadRes = script.reload()
	if reloadRes == OK:
		instance = script.new()
		result = instance.launchPayload(self)
		self.add_child(instance)
	else:
		errorMessage = "Failed to reload the script: " + reloadRes
		success = false
	
	if !success:
		print(errorMessage)

func onClickExecute():
	var text = textEdit.text
	var overriddenText = text.replace("print", "customPrnt")

	loadstring(overriddenText)
	
func onClickClear():
	textEdit.text = ""

func setupSyntaxHighlighting(text_edit):
	var keywords = [
		"extends", "func", "var", "if", "else", "while", "for", "in", "return", "class_name",
		"const", "enum", "break", "continue", "pass", "match", "yield",
		"tool", "signal", "export", "static", "true", "false"
	]
	for keyword in keywords:
		text_edit.add_keyword_color(keyword, KEYWORD_COLOR)

	text_edit.add_color_region("func ", "(", FUNCTION_COLOR, false)

	text_edit.add_color_region("\"", "\"", STRING_COLOR, false)
	text_edit.add_color_region("'", "'", STRING_COLOR, false)

	text_edit.add_color_region("#", "\n", COMMENT_COLOR, true)
