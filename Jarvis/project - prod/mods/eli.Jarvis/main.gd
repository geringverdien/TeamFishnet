extends Node

var systemPrompt:String = """
You are Jarvis, an admin assistant tool for the videogame \"WEBFISHING\".

You will respond only in a strictly formatted string without any additional text to return a command to execute and the target's id. The user input will be a message that you have to interpret as which command to execute.
If the executed command requires a value such as when the user wants to change their speed to 10, add that value of 10 as the command value. If no value is needed, just put it as null

your response should look like the following:
{command name}-{target id}-{command value or "null"}
DO NOT wrap your response in any markdown. Reply with the raw string and nothing else that would add syntax highlighting

the list of possible commands and their definition is:
- punch (punches target)
- goto (teleports local player to the target player)
- warp (warps local player to one of the premade locations, return fitting location name as command value)
- speed (returns a user provided number to set their walking speed as command value, return null as command value if user asks to reset their speed)
- talk (puts your command value into chat, message should be kept short and MUST be under 500 characters. use this if user asks questions that dont apply to other commands)
- cmds (gives user a list of all commands, returns a target id of 0)
- null (only use this command if the user input does not match any of the previous commands, returns a target id of 0)


the list of player names and their target ids will be provided at the top of the user's message in a format like this:
players:
\"name\":target id
\"name2\":target id 2
...

the warp location names are:
- spawn
- lake
- lighthouse
- docks
- small_docks

if the user does not enter a fully matching player name then try to find the best matching name and therefore target id 

if the user input mentions themself/\"me\" as the target, use the \"local user\" target id provided by the user underneath the target id list.
if the user is referring to \"that guy\", \"him/her/them\" and the message does not seem to be referring to the last target, use the \"closest\" target id provided in the user message undeath the \"local user\" target id.
if you do think that the user is referring to the last selected target, use the "last target" target id

in conclusion, the provided user message will look similar to this:
---
players:
\"tim\":62777182000870859
\"alex\":37361058446513216

local player: 25626103718474759
closest: 37361058446513216
last target: 62777182000870859

input: 
please punch alex
---
""".strip_edges()

var baseInputMessage:String = """
players:
%s

local player: %s
closest: %s
last targe: %s

input:
%s
""".strip_edges()


var config:Dictionary = {
	"API_key": "get a free key at https://api.together.ai/settings/api-keys",
	"model": "meta-llama/Llama-3.3-70B-Instruct-Turbo-Free",
	"max_chat_length": 2000,
	"jarvis_chat_output": true,
	"debug_output": false,
	
}

const possibleCommands = {
	"punch": "punchFunc",
	"goto": "gotoFunc",
	"warp": "warpFunc",
	"speed": "speedFunc",
	"cmds": "listCommands",
	"talk": "talkFunc",
}

const warpLocations = {
	"spawn": Vector3(48.82, 4.24, -56.93),
	"lake": Vector3(45.76, 4.24, -13.59),
	"lighthouse": Vector3(48.76, 28.74, 59.00),
	"docks": Vector3(116.02, 4.24, 1.83),
	"small_docks": Vector3(123.69, 0.34, -142.20),
}


var TODOS = """ 
- spawn small cloud
- change size
- "reply" command
?- drink effects
"""

onready var playerAPI = get_node("/root/ToesSocks/Players")
onready var TackleBox := $"/root/TackleBox"
onready var utils = preload("res://mods/eli.Jarvis/utils.gd").new()

var convoData:Array = []

var localPlayer:Actor
var ingame:bool = false

var lastTarget:String = "0"

func _ready():
	playerAPI.connect("ingame", self, "onIngame")
	playerAPI.connect("player_removed", self, "playerLeft")
	
	add_child(utils)
	
	initConfig()
	TackleBox.connect("mod_config_updated", self, "configUpdated")
	
func onIngame():
	if ingame: return
	ingame = true
	
	localPlayer = playerAPI.local_player
	localPlayer.hud.connect("_message_sent", self, "chatted")
	
	resetConvoData()
	
func chatted(message:String):
	message = message.to_lower()
	var prefixTrimmed = message.trim_prefix("jarvis,")
	if prefixTrimmed == message: return
	parseMessageToAI(prefixTrimmed)
	
func parseMessageToAI(message:String):
	var inputMessage = generateInputMessage(message)
	addConvoMessage(inputMessage)
	getConvoResponse()
	
func generateInputMessage(input:String) -> String:
	var targetsString:String = ""
	var playerDict:Dictionary = playerAPI.get_players_dict(true)
	for targetID in playerDict.keys():
		var targetPlayer:Actor = playerDict[targetID]
		if not is_instance_valid(targetPlayer): continue
		var playerName:String = playerAPI.get_username(targetPlayer)
		var entryString:String = "%s:%s\n" % [str(targetID), playerName]
		targetsString += entryString
	
	var localString:String = ""
	var localID:int = localPlayer.owner_id if localPlayer.owner_id != -1 else 0
	localString = str(localID)
	
	var closestString:String = ""
	var closestPlayer:Actor = playerAPI.get_nearest_player()
	if closestPlayer != null and is_instance_valid(closestPlayer):
		closestString = playerAPI.get_id(closestPlayer)
	else:
		closestString = "0"
		
	
		
	var inputString:String = input.strip_edges()
	inputString = inputString.replace("\n", "\\n")
	
	var outputString:String = baseInputMessage % [targetsString, localString, closestString, lastTarget, inputString]
	
	return outputString
	
func addConvoMessage(content:String, role:String = "user"):
	convoData.append({
		"role": role,
		"content": content
	})
	
func resetConvoData():
	convoData = []
	addConvoMessage(systemPrompt, "system")

func getConvoResponse(model:String = config.model , messages:Array = convoData):
	var payload = {
		"model": model,
		"messages": messages
	}
	
	var convertedPayload:String = JSON.print(payload, "\t")
	
	var parsedPayload:JSONParseResult = JSON.parse(convertedPayload)
	#print(parsedPayload.error_string, " " + str(parsedPayload.error_line) + " - " + str(parsedPayload.error))
	
	#OS.clipboard = convertedPayload

	postRequest(
		"https://api.together.xyz/v1/chat/completions",
		["content-type: application/json", "accept: application/json", "authorization: Bearer " + config.API_key],
		convertedPayload
	)

func postRequest(url:String, headers:PoolStringArray, payload:String = "", useSSL = true):
	var http = HTTPRequest.new()
	http.connect("request_completed", self, "requestFinished", [http])
	add_child(http)
	var request = http.request(url, headers, useSSL, HTTPClient.METHOD_POST, payload)
	
	match str(request):
		"0": print("request sent successfully")
		"3": print("request object is not in tree")
		"25": print("cant connect to server")
		"31": print("invalid request parameters")
		"44": print("request is busy")
	
func requestFinished(result:int, responseCode:int, headers:PoolStringArray, body:PoolByteArray, httpObject:HTTPRequest):
	var json:JSONParseResult = JSON.parse(body.get_string_from_utf8())
		
	if json.error != OK:
		print("json error: ", json.error, " json error string: " + json.error_string)
		return
		
	var data:Dictionary = json.result
	
	if data.has("error"):
		var errMessage = data.error.message
		var errType = data.error.type
		var errCode = data.error.code
		print("request error (", errCode , ": ", errType , "): ", errMessage)
	
	var isRatelimited:bool
	var tokenLimit:int
	var tokensRemaining:int
	
	for header in headers:
		var splitHeader:Array = header.split(":")
		var headerKey:String = splitHeader[0].strip_edges()
		var headerValue:String = splitHeader[1].strip_edges()
		#print(headerKey, ": ", headerValue)
		match headerKey:
			"x-ratelimit-remaining-tokens": 
				tokensRemaining = int(headerValue)
			"x-ratelimit-limit-tokens": 
				tokenLimit = int(headerValue)
			"x-ratelimit":
				isRatelimited = headerValue == "true"
				
	if isRatelimited:
		jarvisChat("Error. Currently rate limited.")
		return
		
	if tokensRemaining <= tokenLimit - 200:
		jarvisChat("Warning. Approaching token ratelimit (" + str(tokensRemaining) + " remaining)")
		
	var message:String = data.choices[0].message.content
	var conversationLength:int = int(data.usage.total_tokens)
		
	if conversationLength >= config.max_chat_length:
		resetConvoData()
		jarvisChat("Nearing maximum chat length. Resetting conversation.")
	else:
		addConvoMessage(message, "assistant")
	
	if config.debug_output:
		jarvisChat(message, true)
	
	var splitMessage:PoolStringArray = message.split("-")
	if len(splitMessage) < 2: return
	var command:String = splitMessage[0]
	var commandTarget:int = int(splitMessage[1])
	var commandValue:String = "null"
	
	if len(splitMessage) > 2:
		splitMessage.remove(0) # command name
		splitMessage.remove(0) # target id
		commandValue = splitMessage.join("-")
	
	if not command in possibleCommands: return
	var commandFunc:String = possibleCommands[command]
	if not self.has_method(commandFunc): return
	self.call(commandFunc, commandTarget, commandValue)
	
	if commandTarget != 0: lastTarget = str(commandTarget)
	
	httpObject.queue_free()

func playerLeft(player:Actor):
	if player == localPlayer: 
		ingame = false
		lastTarget = "0"
		return
	
	var playerID:int = player.owner_id
	
		

func initConfig():
	var savedConfig:Dictionary = TackleBox.get_mod_config("eli.Jarvis")
	for key in config.keys():
		if not savedConfig.has(key):
			savedConfig[key] = config[key]
	
	config = savedConfig.duplicate()
	TackleBox.set_mod_config("eli.Jarvis", config)

func configUpdated(modID:String, updatedConfig:Dictionary):
	if modID != "eli.Jarvis": return
	config = updatedConfig.duplicate()
	


func jarvisChat(message:String, override:bool = false):
	if not override and not config.jarvis_chat_output: return
	Network._send_message("(Jarvis): " + message, "ffffffff")


func punch(target:Actor):
	if not is_instance_valid(target): return
	Network._send_P2P_Packet({
		"type": "player_punch", 
		"from_pos": target.global_transform.origin, 
		"punch_type": 1
	}, 
		str(target.owner_id), 
		2, 
		Network.CHANNELS.ACTOR_ACTION)
	
func listCommands(t,v):
	var baseReponse:String = "Commands:%s"
	var commandString:String = ""
	var resultString:String
	
	for command in possibleCommands:
		baseReponse += "\n- " + command
		
	resultString = baseReponse % commandString
	jarvisChat(resultString, true)
	
func kickFunc(target:int, v):
	if target == 0: return
	Network._send_P2P_Packet({
		"type": "actor_action", 
		"actor_id": localPlayer.actor_id, 
		"action": "_update_held_item",
		"params": [null]
	}, 
	str(target), 
	2, 
	Network.CHANNELS.ACTOR_ACTION)
	
func punchFunc(target:int, v):
	if target == 0: return
	var targetPlayer:Actor = playerAPI.get_player(str(target))
	punch(targetPlayer)
	
func gotoFunc(target:int, v):
	if target == 0: return
	var targetPlayer:Actor = playerAPI.get_player(str(target))
	
	if not targetPlayer.in_zone: 
		localPlayer.world._enter_zone(targetPlayer.current_zone, targetPlayer.current_zone_owner)
		yield(get_tree().create_timer(0.1), "timeout")
		
	localPlayer.global_transform.origin = targetPlayer.global_transform.origin
	
func warpFunc(t, locationName:String):
	if locationName == "null": return
	if not locationName in warpLocations: return
	
	if not localPlayer.current_zone == "main_zone":
		localPlayer.world._enter_zone("main_zone")
		yield(get_tree().create_timer(0.1), "timeout")
	
	localPlayer.global_transform.origin = warpLocations[locationName]
	
func speedFunc(t, value:String):
	var numValue = int(value) if value != "null" else 3.2
	localPlayer.walk_speed = numValue

func talkFunc(t, value:String):
	var truncatedMessage = value.left(500)
	jarvisChat(truncatedMessage, true)
