extends Node

onready var Socks = get_node_or_null("/root/ToesSocks/Players")
var hauntingUI = preload("res://mods/eli.ParanoiaFishing/hauntingUI.tscn")
onready var utils = preload("res://mods/eli.ParanoiaFishing/utils.gd").new()

var UI
var tree:Tree
var root:TreeItem

var ingame = false
var localPlayer

var playerItems = {}

var playerInteractions = {
	"jail": {
		"type": "button",
		"callback": "spawnJail",
	},
	"clear props": {
		"type": "button",
		"callback": "clearPlayerProps"
	},
	"test button": {
		"type": "button",
		"callback": "testFunc",
	},
	"test label": {
		"type": "label",
	},
}

func _ready():
	add_child(utils)
	Socks.connect("ingame", self, "onIngame")
	Socks.connect("player_added", self, "playerAdded")
	Socks.connect("player_removed", self, "playerRemoved")
	#get_tree().connect("node_added", self, "nodeAdded")
	#initUI()
	
func initUI():
	clearUI()
	UI = hauntingUI.instance()
	tree = UI.get_node("Holder/WindowDialog/Tree")
	root = tree.create_item()
	add_child(UI)
	tree.connect("cell_selected", self, "cellSelected")

func clearUI():
	if UI == null or !is_instance_valid(UI): return
	UI.queue_free()
	UI = null
	tree = null
	root = null

func registerPlayer(player):
	var steamID = player.owner_id
	var playerName = Steam.getFriendPersonaName(steamID)
	var playerTree:TreeItem = tree.create_item(root)
	
	playerItems[str(steamID)] = {
		"tree": playerTree,
		"actors": [],
		"flags": {
		}
	}
	
	playerTree.set_text(0, playerName)
	playerTree.set_text_align(0, TreeItem.ALIGN_LEFT)
	playerTree.set_editable(0, false)
	playerTree.set_selectable(0, false)
	playerTree.set_metadata(0, player)
	
	for treeName in playerInteractions.keys():
		var treeData = playerInteractions[treeName]
		var treeItem = tree.create_item(playerTree)
		
		treeItem.set_editable(0, false)
		treeItem.set_text_align(0, TreeItem.ALIGN_CENTER)
		match treeData.type:
			"button":
				treeItem.set_selectable(0, true)
				treeItem.set_metadata(0, treeData.callback)
				treeItem.set_text(0, "(" + treeName + ")")
			"label":
				treeItem.set_selectable(0, false)
				treeItem.set_text(0, treeName)
				#treeItem.set_metadata(0, "label")

func cellSelected():
	var cell = tree.get_selected()
	var metadata = cell.get_metadata(0)
	if not metadata: return
	
	var parentCell = cell.get_parent()
	var targetPlayer = parentCell.get_metadata(0)
	var targetID = targetPlayer.owner_id
	var targetName = Steam.getFriendPersonaName(targetID)
	
	for actionName in playerInteractions.keys():
		var actionData = playerInteractions[actionName]
		
		if actionData.has("callback") and actionData.callback == metadata:
			self.call(metadata, targetPlayer)
			break
			
	yield(get_tree().create_timer(0.1), "timeout")
	
	cell.deselect(0)

func playerRemoved(player):
	clearPlayerProps(player)
	playerItems[str(player.owner_id)].tree.free()
	playerItems.erase(str(player.owner_id))
		
func playerAdded(player):
	#if player == localPlayer: return
	registerPlayer(player)
	
func nodeAdded(node:Node): 
	if node.name != "main_menu": return
	if not ingame: return
	ingame = false
	localPlayer = null
	clearUI()

func onIngame():
	ingame = true
	localPlayer = Socks.local_player
	playerItems = {}
	#var entities = localPlayer.get_parent()
	#print(entities)
	#entities.connect("tree_exiting", self, "playerRemoved")
	initUI()


func testFunc(player):
	var steamID = player.owner_id
	var steamName = Steam.getFriendPersonaName(steamID)
	var msg = "hello, "	+ steamName
	utils.sendPrivateMessage(player, msg)
	utils.sendPrivateMessage(player, msg, true)
	print(msg)


var chai
var chairPositions = [
		[Vector3(0,  -0.15, -1), Vector3(0,180,0)], # front
		[Vector3(0,  -0.15, 1), Vector3(0,0,0)], # back
		[Vector3(1,  -0.15, 0), Vector3(0,90,0)], # left
		[Vector3(-1, -0.15, 0), Vector3(0,-90,0)], # right
	]
var chairOffset = Vector3(0,-1,0) # account for player height of 1

func spawnChair(player, pos, rotation, zone):
	var rot = Vector3(deg2rad(rotation.x), deg2rad(rotation.y), deg2rad(rotation.z))
	var actorID = utils.spawnPrivateActor(player, "chair", pos, rot)
	print("added " + str(actorID) + " for " + str(player.owner_id))
	playerItems[str(player.owner_id)].actors.append(actorID)	

func spawnJail(player):
	var targetPos = player.global_transform.origin
	var playerZone = player.current_zone
	for location in chairPositions:
		var pos = location[0]
		var rot = location[1]
		spawnChair(player, targetPos + pos + chairOffset, rot, playerZone)
		
func clearPlayerProps(player):
	var actorStorage:Array = playerItems[str(player.owner_id)].actors
	print(len(actorStorage))
	for actorID in actorStorage:
		utils.clearPrivateActor(player, actorID)
	playerItems[str(player.owner_id)].actors = []
