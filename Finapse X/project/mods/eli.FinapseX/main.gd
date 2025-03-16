extends Node

const KEYWORD_COLOR = Color(0.8, 0.2, 0.8)  # Purple
const FUNCTION_COLOR = Color(0.2, 0.6, 1)  # Blue
const STRING_COLOR = Color(0.2, 0.8, 0.2)  # Green
const COMMENT_COLOR = Color(0.6, 0.6, 0.6)  # Gray
const NUMBER_COLOR = Color(0.8, 0.5, 0.2)  # Orange

onready var TackleBox := $"/root/TackleBox"
onready var Socks = get_node_or_null("/root/ToesSocks/Players")
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
var clearCache = panel.get_node("ClearCache")
var shareButton:Button = panel.get_node("ShareScript")
var shareTree:Tree = shareButton.get_node("Tree")
var shareRoot:TreeItem
var playerTreeItems = {}
var finapseUsers = {}
var server
var clients = {}
var isDebugging:bool
var localID:int
var lobbyID:int

var receivingScript:bool = false
var lastSentScript:String = ""

var config = {
	"websocket_enabled": false,
	"script_sharing": true,
	"share_cooldown": 5
}

var commands:Dictionary = {
	"sendscript": "sendScript",
}

var payload = """
extends Node
var _finapseScript
var PlayerAPI 
var KeybindsAPI
var localPlayer

func customPrnt(message):
	Network._update_chat("[color=#d1d1d1]" + str(message) + "[/color]", true)
	print(message)

func warn(message):
	Network._update_chat("[color=#dede00]" + str(message) + "[/color]", true)
	print(message)

func error(message):
	Network._update_chat("[color=#ff0000]" + str(message) + "[/color]", true)
	print(message)
	

func launchPayload(selfPassed):
	_finapseScript = selfPassed
	PlayerAPI = _finapseScript.PlayerAPI
	KeybindsAPI = _finapseScript.KeybindsAPI
	
	localPlayer = PlayerAPI.local_player
	
"""


func _ready():
	isDebugging = false#= OS.has_feature("editor")
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
	Socks.connect("ingame", self, "onIngame")
	Socks.connect("player_added", self, "playerAdded")
	Socks.connect("player_removed", self, "playerRemoved")
	
	setupSyntaxHighlighting(textEdit)
	execute.connect("pressed", self, "onClickExecute")
	clear.connect("pressed", self, "onClickClear")
	clearCache.connect("pressed", self, "onClickClearCache")
	
	initConfig()
	TackleBox.connect("mod_config_updated", self, "configUpdated")
	
	Steam.connect("lobby_message", self, "onSteamMessage")
	
	shareRoot = shareTree.create_item()
	shareRoot.set_text(0, "Script Share:")
	shareRoot.set_selectable(0, false)
	shareTree.connect("cell_selected", self, "cellSelected")
	shareButton.connect("pressed", self, "onShareButtonPressed")
	
	var useSocket = config.websocket_enabled
	if useSocket: initWebsocket()

func _process(d):
	if not server: return
	if server.is_listening():
		server.poll()

func onSteamMessage(senderLobbyID:int, userID:int, message:String, chatType:int):
	if isDebugging == false and (senderLobbyID != lobbyID or userID == localID): 
		print("base check failed")
		return 
	
	var splitMessage = message.split("|")
	if splitMessage.size() != 3: return
	
	print("received Finapse script")
	
	var messageType = splitMessage[0]
	var targetID = int(splitMessage[1])
	var packetData = splitMessage[2]
	var sendingPlayer = Network._get_username_from_id(userID)
	
	if targetID != localID: 
		print("not the message target")
		return
	
	
	match messageType:
		"Deregister":
			if not (str(userID) in finapseUsers.keys()): return
			print("received deregistration by " + sendingPlayer)
			
			playerTreeItems[str(userID)].free()
			playerTreeItems.erase(str(userID))
			finapseUsers.erase(str(userID))
			
		"Register":
			print("registration incoming")
			if str(userID) in finapseUsers.keys() and finapseUsers[str(userID)] != null: return
			print("received registatrion by " + sendingPlayer)
			var userActor = Socks.get_player(str(userID))
			finapseUsers[str(userID)] = userActor if userActor else false
			registerPlayer(userActor)
		"SendScript":
			if not config.script_sharing: return
			if receivingScript: return
			receivingScript = true
			var decodedBuffer = Marshalls.base64_to_raw(packetData)
			var decompressedScript = decodedBuffer.decompress_dynamic(-1, File.COMPRESSION_DEFLATE)
			var finalScript = decompressedScript.get_string_from_utf8()
			lastSentScript = finalScript
			popup(
				"Finapse script share",
				sendingPlayer + " wants to share a script with you.\nClick Accept to paste it into your FinapseX window\n\nCode:\n" + lastSentScript
			)

func popup(mailTitle:String = "Title", mailContent:String = "Content"):
	var letterData = {
		"header": mailTitle + ("\n").repeat(50),
		"body": mailContent,
		"items": [],
		"closing": "",
		"from": "-Team Fishnet :3",
		"letter_id": 0
	}
	localPlayer.hud._on_inbox__read_letter(letterData)
	var buttonContainer = localPlayer.hud.get_node("letter_view/Control/Control/HBoxContainer")
	print(buttonContainer)
	var acceptButton = buttonContainer.get_node("Button3")
	acceptButton.connect("pressed", self, "onLetterAccept")
	var acceptTooltip = acceptButton.get_node("TooltipNode")
	acceptTooltip.header = "Accept Script"
	acceptTooltip.body = "automatically pastes the code into your executor window\n(will overwrite the code that is in there right now)"
	var denyButton = buttonContainer.get_node("Button2")
	denyButton.connect("pressed", self, "onLetterDeny")
	var denyTooltip = denyButton.get_node("TooltipNode")
	denyTooltip.header = "Deny Script"
	denyTooltip.body = "rejects the code that was sent you"
	var cancelButton = buttonContainer.get_node("Button")
	cancelButton.visible = false
	#cancelButton.connect("pressed", self, "onLetterDeny")
	
func onLetterAccept():
	textEdit.text = lastSentScript
	yield(get_tree().create_timer(config.share_cooldown), "timeout")
	receivingScript = false
	
func onLetterDeny():
	yield(get_tree().create_timer(config.share_cooldown), "timeout")
	receivingScript = false


func findPlayer(inputStr:String):
	if not inputStr: return
		
	for plr in PlayerAPI.players:
		if not is_instance_valid(plr): continue
		var plrName = Network._get_username_from_id(plr.owner_id)
		if inputStr.to_lower() in plrName.to_lower():
			return plr
			
func onMessage(msg:String):
	if not config.script_sharing: return
	var hasPrefix = msg.begins_with("-")
	if not hasPrefix: return
	var trimmed = msg.trim_prefix("-")
	var spaceSplit = trimmed.split(" ")

	var command = spaceSplit[0]
	var targetString = spaceSplit[1] if len(spaceSplit) > 1 else ""
	if targetString == "": return
	var target = findPlayer(targetString)
	if not target:return
	
	handleCommand(command, target)

func handleCommand(cmdName:String, target:Actor):
	print("command ", cmdName)
	if not cmdName in commands: return
	var selectedCallback = commands[cmdName]
	
	if not selectedCallback: return
	print("running callback")
	self.call(selectedCallback, target)
	
func sendScript(target):
	var compressedScript = compressScript(textEdit.text)
	var encodedScript = Marshalls.raw_to_base64(compressedScript)
	var message = "SendScript|"
	message += str(target.owner_id) + "|"
	message += encodedScript
	print("sending " + message)
	Steam.sendLobbyChatMsg(lobbyID, message)

func sendRegistration(steamID, setByConfig = false):
	if setByConfig == false and config.script_sharing == false: return
	var message = "Register|"
	message += str(steamID) + "|"
	Steam.sendLobbyChatMsg(lobbyID, message)
	
func sendDeregistration(steamID):
	var message = "Deregister|"
	message += str(steamID) + "|"
	Steam.sendLobbyChatMsg(lobbyID, message)
	
	
func compressScript(code:String):
	var utf8converted = code.to_utf8()
	var compressedBuffer = utf8converted.compress(File.COMPRESSION_DEFLATE)
	return compressedBuffer
	
func decompressScript(compressedBuffer:PoolByteArray):
	var decompressedBuffer = compressedBuffer.decompress_dynamic(-1, File.COMPRESSION_DEFLATE)


func onShareButtonPressed():
	shareTree.visible = !shareTree.visible

func registerPlayer(player):
	if !isDebugging and player == localPlayer: return
	var steamID = player.owner_id
	var playerName = Steam.getFriendPersonaName(steamID)
	var playerTree:TreeItem = shareTree.create_item(shareRoot)

	playerTreeItems[str(steamID)] = playerTree
	
	playerTree.set_text(0, playerName)
	playerTree.set_text_align(0, TreeItem.ALIGN_CENTER)
	playerTree.set_editable(0, false)
	playerTree.set_selectable(0, true)
	playerTree.set_metadata(0, player)
	
func cellSelected():
	var cell = shareTree.get_selected()
	var metadata = cell.get_metadata(0)
	if not metadata: return
	
	var targetPlayer = cell.get_metadata(0)
	var targetID = targetPlayer.owner_id
	var targetName = Steam.getFriendPersonaName(targetID)
	
	sendScript(targetPlayer)
	PlayerData._send_notification("sent script share request to " + targetName)
			
	yield(get_tree().create_timer(0.1), "timeout")
	
	cell.deselect(0)
	

func initConfig() -> void:
	var savedConfig = TackleBox.get_mod_config("eli.FinapseX")
	for key in config.keys():
		if not savedConfig.has(key):
			savedConfig[key] = config[key]
	
	config = savedConfig.duplicate()
	TackleBox.set_mod_config("eli.FinapseX", config)

func configUpdated(modID:String, updatedConfig:Dictionary):
	if modID != "eli.FinapseX": return
#	print(config.script_sharing, updatedConfig.script_sharing)
#	if ingame and config.script_sharing == false and updatedConfig.script_sharing == true:
#		for playerID in Socks.get_players_dict().keys():
#			#if playerID == localID: continue
#			print("sent registration to current member " + str(playerID))
#			sendRegistration(playerID, true)
#	if ingame and config.script_sharing == true and updatedConfig.script_sharing == false:
#		for playerID in Socks.get_players_dict().keys():
#			#if playerID == localID: continue
#			print("sent deregistration to current member " + str(playerID))
#			sendDeregistration(playerID)
	config = updatedConfig.duplicate()


func initWebsocket():
	print("ws init")
	server = WebSocketServer.new()
	server.connect("connection_closed", self, "clientDisconnected")
	server.connect("connection_error", self, "clientDisconnected")
	server.connect("connection_established", self, "clientConnected")
	server.connect("data_received", self, "onData")
	
	var err = server.listen(24892)
	if err != OK:
		print("Unable to start server")
		set_process(false)
		return
	print("WebSocket Server started on port 24892")
	set_process(true)

func sendMessage(message):
	if server.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED:
		server.get_peer(1).put_packet(message.to_utf8())
	else:
		print("Not connected to server")

func clientConnected(id, protocol):
		print("Client %d connected with protocol: %s" % [id, protocol])
		clients[id] = true
		server.get_peer(id).put_packet("Connection confirmed".to_utf8())

func clientDisconnected(id, was_clean = false):
		print("Client %d disconnected, clean: %s" % [id, str(was_clean)])
		clients.erase(id)

func onData(id = 1):
	#print("Received data from client: ", id)
	var packet = server.get_peer(id).get_packet()
	var dataString = packet.get_string_from_utf8()
	
	match dataString:
		"IS_READY":
			server.get_peer(id).put_packet("TRUE".to_utf8())
		"ATTACH":
			server.get_peer(id).put_packet("READY".to_utf8())
		_:
			print("Executing remote script")
			loadstring(dataString)
			server.get_peer(id).put_packet("OK".to_utf8())


func onKeybindPressed():
	#if !ingame: return
	
	isOpen = !isOpen
	if isOpen:
		disableInputEvents()
	else:
		enableInputEvents()
	ui.visible = isOpen

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


func onIngame():
	ingame = true
	localPlayer = PlayerAPI.local_player
	localID = Network.STEAM_ID
	lobbyID = Network.STEAM_LOBBY_ID
	localPlayer.hud.connect("_message_sent", self, "onMessage")
	initExecutor()
	yield(get_tree().create_timer(5), "timeout")
	for playerID in Socks.get_players_dict().keys():
		#if playerID == localID: continue
		print("sent registration to current member " + str(playerID))
		sendRegistration(playerID)

func playerAdded(plr):
	if plr.name == "player":
		localPlayer = plr
		return
	yield(get_tree().create_timer(5), "timeout")
	sendRegistration(plr.owner_id)
	print("sent registration to new player " + str(plr.owner_id))
	
		#if isDebugging: registerPlayer(plr)

func playerRemoved(plr):
	if str(plr.owner_id) in playerTreeItems.keys():
		playerTreeItems[str(plr.owner_id)].free()
		playerTreeItems.erase(str(plr.owner_id))
		finapseUsers[str(plr.owner_id)] = null
		
	if plr.name == "player":
		ingame = false
		for item in playerTreeItems.values():
			item.free()
		playerTreeItems = {}
		finapseUsers = {}

func initExecutor():
	if ui.get_parent(): return
	add_child(ui)



func loadstring(code): 
	var overridenCode = code.replace("extends Node", "")
	overridenCode = overridenCode.replace("print(", "customPrnt(")
	var fullCode = payload + overridenCode
	fullCode = fullCode.strip_edges()
	
	var gds = GDScript.new()
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
	loadstring(text)
	
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
