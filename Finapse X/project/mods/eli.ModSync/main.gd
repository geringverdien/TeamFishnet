extends Node

onready var TackleBox := $"/root/TackleBox"
onready var PlayerAPI := $"/root/BlueberryWolfiAPIs/PlayerAPI"
onready var installer = load("res://mods/eli.ModSync/installer.gd").new()


const ModSyncModID:String = "eli.ModSync"
const ignoredMods:Array = [ModSyncModID, "TackleBox", "BlueberryWolfi.APIs", "Lure"]
var isDebugging:bool
var commands:Dictionary = {
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
var syncedPlayers:Dictionary = {}

var file:File = File.new()
var packageHTTP:HTTPRequest = HTTPRequest.new()
var downloadHTTP:HTTPRequest = HTTPRequest.new()
var onlineRawJSON:String
var onlinePackages:Array

var GDWeavedir = getGDWeaveDir()
var ModSyncPath = GDWeavedir.plus_file("mods").plus_file(ModSyncModID)
var packageListPath = ModSyncPath.plus_file("packagelist.json")

var defaultConfig:Dictionary = {
	"sync_as_host": true,
	"sync_via_chat": true,
	"ignore_installed_mods": true,
	"save_list_to_file": false,
	"copy_as_JSON": false,
	"chat_advertisement": true,
	"modsync_only_lobby": false,
	"auto_download_mods": true,
	"mods_to_sync": "toggle which mods to share VVV"
}
var modConfig:Dictionary
var installedMods:Array
var syncedMods:Array

func _ready():
	isDebugging = OS.has_feature("editor")
	
	add_child(packageHTTP)
	add_child(downloadHTTP)
	
	packageHTTP.connect("request_completed", self, "onPackageListRequest", [])
	downloadHTTP.connect("request_completed", self, "onDownloadRequest")
	
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
	getOnlineModList()


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
			syncedPlayers[str(userID)] = true
			sendModList(userID)
			notify(sendingPlayer + " has received your modlist!")
			debugPrint("sent mod list to " + str(userID))
	

func processSentMods(modDict:Dictionary, sentFrom:String):
	var headerText = "missing mods" if modConfig.ignore_installed_mods else "full modlist"
	resultString = ""
	var modsToDownload:Dictionary = {}
	
	for modID in modDict.keys():
		if modConfig.ignore_installed_mods and modID in installedMods: continue

		var formattedString:String
		var modName = modDict[modID]
		if not modID in ignoredMods:
			 modsToDownload[modID] = modName
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
		
	if modConfig.auto_download_mods:
		downloadMods(modsToDownload)
		
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
	var targetString = spaceSplit[1] if len(spaceSplit) > 1 else ""
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
	

func initiateKick(userID):
	Network._send_P2P_Packet({
		"type": "message", 
		"message": "!!MODSYNC ONLY LOBBY!! Please install ModSync to join this lobby. Kicking in 30 seconds.", 
		"color": "ffffffff", 
		"local": false, 
		"position": Network.MESSAGE_ORIGIN, 
		"zone": Network.MESSAGE_ZONE, 
		"zone_owner": PlayerData.player_saved_zone_owner
	}, str(userID), 2, Network.CHANNELS.GAME_STATE)
	yield(get_tree().create_timer(30), "timeout")
	Network._kick_player(userID)

func checkSyncUser(userID):
	if not (Network.GAME_MASTER and modConfig.modsync_only_lobby): return
	yield(get_tree().create_timer(5), "timeout")
	if syncedPlayers[str(userID)]: return
	initiateKick(userID)

func playerAdded(player:Actor):
	syncedPlayers[str(player.owner_id)] = false
	if player != PlayerAPI.local_player:
		checkSyncUser(player.owner_id)
		return
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
	syncedPlayers = {}
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
	

func getOnlineModList():
	fetchOnlineModList()
#	if file.open(packageListPath, File.READ) == OK:
#		var timestamp = int(file.get_modified_time(packageListPath))
#		if timestamp == 0:
#			debugPrint("failed to get file timestamp")
#
#		file.close()
#		fetchOnlineModList()
#	else:
#		fetchOnlineModList()
	
func fetchOnlineModList():
	packageHTTP.request("https://thunderstore.io/c/webfishing/api/v1/package")
	debugPrint("sent api request")
	
func storeLocalModList():
	if file.open(packageListPath, File.WRITE) == OK:
		var compressedData = onlineRawJSON.to_utf8().compress(File.COMPRESSION_DEFLATE)
		file.store_buffer(compressedData)
		debugPrint("stored online mod list")
	

func downloadMods(modDict):
	for packageData in onlinePackages:
		var packageName = packageData.name
		for modID in modDict.keys():
			var modName = modDict[modID]
			var dotSplit:PoolStringArray = modID.split(".")
			var lastEntry:String = dotSplit[dotSplit.size() - 1]
			if not lastEntry in packageName: continue
			var packageVersions = packageData.versions
			var latestVersion = packageVersions[0]
			var downloadLink = latestVersion.download_url
			debugPrint("DOWNLOAD LINK: " + downloadLink)
		
	
	
func onPackageListRequest(result, responseCode, headers, body):
	if responseCode == 200: #and file.open(packageListPath, File.WRITE) == OK:
		file.close()
		onlineRawJSON = body.get_string_from_utf8()
		var JSONConverted:JSONParseResult = JSON.parse(onlineRawJSON)
		if JSONConverted.error == 0:
			onlinePackages = JSONConverted.result
			debugPrint("received online mod list")
		else:
			debugPrint("couldnt parse JSON")
		#storeLocalModList()
		#debugPrint(onlinePackages[0])
	else:
		debugPrint("request failed")

func onDownloadRequest(result, responseCode, headers, body):
	pass


func debugPrint(message):
	if not isDebugging: return
	print(message)
