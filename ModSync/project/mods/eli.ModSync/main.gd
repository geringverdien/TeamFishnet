extends Node

onready var TackleBox := $"/root/TackleBox"
onready var PlayerAPI := $"/root/BlueberryWolfiAPIs/PlayerAPI"

const ModSyncModID = "eli.ModSync"
const ignoredMods = [ModSyncModID, "TackleBox", "BlueberryWolfi.APIs"]
var isDebugging:bool
var commands = {
	"modsync": "requestCommand",
}

var resultString:String
var fileScene = preload("res://mods/eli.ModSync/fileScene.tscn").instance()
var fileDialog:FileDialog

var ingame = false
var localPlayer:Actor
var localName:String
var localID:int
var hostID:int
var lobbyID:int


var defaultConfig:Dictionary = {
	"sync_as_host": true,
	"sync_via_chat": true,
	"ignore_installed_mods": true,
	"save_list_to_file": false,
	"copy_as_JSON": false,
	"chat_advertisement": true,
	"mods_to_sync": "toggle which mods to share VVV"
}
var modConfig:Dictionary
var installedMods:Array
var syncedMods:Array

func _ready():
	isDebugging = OS.has_feature("editor")
	
	fileDialog = fileScene.get_node("CanvasLayer/FileDialog")
	fileDialog.mode = FileDialog.MODE_SAVE_FILE
	fileDialog.access = FileDialog.ACCESS_FILESYSTEM
	fileDialog.filters = ["*.txt ; Text Files", "*.json ; JSON Files"]
	fileDialog.current_file = "modlist.txt"
	fileDialog.resizable = true
	fileDialog.connect("file_selected", self, "onFileSelected")
	add_child(fileScene)
	
	get_tree().connect("node_added", self, "nodeAdded")
	PlayerAPI.connect("_player_added", self, "playerAdded")
	#PlayerAPI.connect("_player_removed", self, "playerRemoving") # doesnt work for localplayer :(
	installedMods = TackleBox._get_loaded_mods()
	debugPrint(installedMods)
	Steam.connect("lobby_message", self, "onSteamMessage")
	loadConfig()
	TackleBox.connect("mod_config_updated", self, "configUpdated")
	syncedMods = getSyncedMods()
	


func onSteamMessage(lobbyID:int, userID:int, message:String, chatType:int):
	if isDebugging == false and (lobbyID != lobbyID or userID == localID): return 
	var splitMessage = message.split("|")
	if splitMessage.size() != 3: return
	
	debugPrint("received ModSync message")
	
	var messageType = splitMessage[0]
	var targetID = int(splitMessage[1])
	var packetData = splitMessage[2]
	var sendingPlayer = Network._get_username_from_id(userID)
	
	if targetID != localID: 
		debugPrint("not the message target")
		return
	
	
	match messageType:
		"SendMods":
			var decodedMods = unpackModList(packetData)
			processSentMods(decodedMods, sendingPlayer)
			if modConfig.chat_advertisement == false: return
			Network._send_message(sendingPlayer + " has shared their mods with " + localName + " using ModSync!", Color(1,1,1).to_html(), false)
			
		"RequestMods":
			match packetData:
				"host":
					if modConfig.sync_as_host == false: return
				"command":
					if modConfig.sync_via_chat == false: return
				"_":
					return
			sendModList(userID)
			notify(sendingPlayer + " has received your modlist!")
			debugPrint("sent mod list to " + str(userID))
	

func processSentMods(modDict:Dictionary, sentFrom:String):
	var headerText = "missing mods" if modConfig.ignore_installed_mods else "full modlist"
	resultString = ""
	
	
	for modID in modDict.keys():
		if modConfig.ignore_installed_mods and modID in installedMods: continue
		
		var formattedString:String
		var modName = modDict[modID]
		debugPrint("mod name: " + str(modName))
		if modName == "" or modName == modID:
			formattedString = modID
		else:
			formattedString = modName + " (" + modID + ")"
		
		resultString += formattedString + "\n"
	
	if resultString == "": 
		notify("found no mods to sync")
		return
		
	resultString = resultString.trim_suffix("\n")
	debugPrint("formatted mod list: " + resultString)
	popup(
		sentFrom + "'s mods:", 
		"copied " + headerText + " to clipboard:\n" + resultString.strip_edges() + "\n"
	)
	
	if modConfig.copy_as_JSON:
		resultString = JSON.print(modDict)
		
	OS.clipboard = resultString
		
	if modConfig.save_list_to_file == false: return
	var fileEnding = ".json" if modConfig.copy_as_JSON else ".txt"
	promptSaveFile(sentFrom, fileEnding)

func getSyncedMods():
	var syncedMods:Array = []
	for modID in installedMods:
		if modID in ignoredMods: continue
		var isSynced = modConfig[modID]
		if not isSynced: continue
		syncedMods.append(modID)
	return syncedMods
	
func sendModList(steamID:int):
	syncedMods = getSyncedMods()
	var packedList = packModList(syncedMods)
	var message = "SendMods|"
	message += str(steamID) + "|"
	message += packedList
	debugPrint("sent mod list:" + message)
	Steam.sendLobbyChatMsg(lobbyID, message)
	
func requestModList(steamID:int, requestFromHost:bool):
	debugPrint("requesting mod list")
	var message = "RequestMods|"
	message += str(steamID) + "|"
	if requestFromHost:
		message += "host"
	else:
		message += "command"
	debugPrint("sending message: " + message)
	Steam.sendLobbyChatMsg(lobbyID, message)
	
func packModList(mods:Array):
	var nativeDict = {}
	
	for modID in mods:
		var metadata = TackleBox.get_mod_metadata(modID)
		var modName = ""
		if metadata.has("name"):
			modName = metadata.name
		nativeDict[modID] = modName
		
	var JSONDict = JSON.print(nativeDict)
	return JSONDict
	
func unpackModList(modJSON):
	var decodedDict = JSON.parse(modJSON)
	if decodedDict.error != 0:
		debugPrint("JSON error: " + decodedDict.error_string)
		return {}
	return decodedDict.result
	

func findPlayer(inputStr:String):
	if not inputStr: return
		
	for plr in PlayerAPI.players:
		if not is_instance_valid(plr): continue
		var plrName = Network._get_username_from_id(plr.owner_id)
		if inputStr.to_lower() in plrName.to_lower():
			debugPrint("player found: " + plrName)
			return plr
	
	return null
	debugPrint("no target found")

func onMessage(msg:String):
	if modConfig.sync_via_chat == false: return
	debugPrint(msg)
	var hasPrefix = msg.begins_with("-")
	if not hasPrefix: return
	var trimmed = msg.trim_prefix("-")
	var spaceSplit = trimmed.split(" ")

	var command = spaceSplit[0]
	var targetString = spaceSplit[1]
	if targetString == "": return
	var target = findPlayer(targetString)
	if not target:return
	
	handleCommand(command, target)

func handleCommand(cmdName:String, target:Actor):
	if not cmdName in commands: return
	var selectedCallback = commands[cmdName]
	
	if not selectedCallback: return
	self.call(selectedCallback, target)


func requestCommand(target):
	requestModList(target.owner_id, false)
	

func playerAdded(player:Actor):
	if player != PlayerAPI.local_player: return
	ingame = true
	localPlayer = player
	debugPrint("localplayer loaded")
	
	localID = Network.STEAM_ID
	localName = Network._get_username_from_id(localID)
	lobbyID = Network.STEAM_LOBBY_ID
	hostID = Steam.getLobbyOwner(lobbyID)
	
	localPlayer.hud.connect("_message_sent", self, "onMessage")
	
	if isDebugging == false and hostID == localID: return
	if modConfig.sync_as_host == false: return
	requestModList(hostID, true)
	
func nodeAdded(node:Node): 
	if node.name != "main_menu": return
	if not ingame: return
	playerRemoving()

func playerRemoving():
	#if player != localPlayer: return
	ingame = false
	debugPrint("left game")
	
	
func configUpdated(modID:String, updatedConfig:Dictionary):
	if modID != ModSyncModID: return
	modConfig = updatedConfig.duplicate()
	debugPrint("mod config updated")
	debugPrint(modConfig)
	
func loadConfig():
	var loadedConfig = TackleBox.get_mod_config(ModSyncModID).duplicate()
	if loadedConfig.empty(): 
		debugPrint("loading default config")
		loadedConfig = defaultConfig.duplicate()

	if not loadedConfig.has_all(defaultConfig.keys()):
		debugPrint("default key missing, generating default config")
		#loadedConfig = defaultConfig.duplicate()
		
		var copiedDefaultConfig = defaultConfig.duplicate()
		debugPrint("loaded: " + str(loadedConfig))
		debugPrint("copied: " + str(copiedDefaultConfig))
		for key in loadedConfig.keys():
			if key in defaultConfig: 
				debugPrint("skipping default key " + key)
				continue
			#if not key in loadedConfig: continue
			var modValue = loadedConfig[key]
			debugPrint("adding back " + key)
			copiedDefaultConfig[key] = modValue
		loadedConfig = copiedDefaultConfig
	
	for modID in installedMods:
		var modValue
		if loadedConfig.has(modID):
			#loadedConfig[modID] = 
			debugPrint("found setting for " + modID)
		else:
			debugPrint("adding default value for " + modID)
			loadedConfig[modID] = true
		
	for key in loadedConfig.keys():
		var value = loadedConfig[key]
		if key in defaultConfig: continue
		if key in installedMods: continue
		loadedConfig.erase(key)
		debugPrint("removed orphaned mod setting " + key)
		
	loadedConfig.erase(ModSyncModID)
	modConfig = loadedConfig.duplicate()
	TackleBox.set_mod_config(ModSyncModID, loadedConfig)
	
	debugPrint("loaded config data")
	
	
func notify(text:String = "Text", useRed:bool = false):
	var typeNum = 1 if useRed == true else 0
	PlayerData._send_notification(text, typeNum)	
	
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

	
func onFileSelected(path):
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(resultString)
		file.close()
		debugPrint("saved modlist")
	else:
		debugPrint("failed to save file")
		
func promptSaveFile(sentFrom:String, fileExtension:String):
	var safeName = makeNameFileSafe(sentFrom)
	fileDialog.current_file = safeName + " modlist" + fileExtension
	fileDialog.popup_centered()
	debugPrint("spawned file window")
	
func makeNameFileSafe(rawName: String):
	var invalidChars = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	
	for character in invalidChars:
		rawName = rawName.replace(character, "_")
	
	rawName = rawName.strip_edges()
	
	return rawName
	
	
func debugPrint(message):
	if not isDebugging: return
	print(message)
