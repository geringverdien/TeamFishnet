extends Node

onready var Socks = get_node_or_null("/root/ToesSocks/Players")

var playerActorStorage = {}

func sendPrivateMessage(player:Actor, message, local = false):
	var steamID = player.owner_id  
	Network._send_P2P_Packet({
		"type": "message", 
		"message": message, 
		"color": "ffffffff", 
		"local": local, 
		"position": player.global_transform.origin, 
		"zone": Network.MESSAGE_ZONE, 
		"zone_owner": player.current_zone_owner
	}, str(steamID), 2, Network.CHANNELS.GAME_STATE)
	
func sendPrivatePosUpdate(player:Actor, actorID, pos, rot = Vector3(0,0,0)):
	Network._send_P2P_Packet({
		"type": "actor_update", 
		"actor_id": actorID, 
		"pos": pos, 
		"rot": rot
	}, str(player.owner_id), Network.CHANNELS.ACTOR_UPDATE)

func spawnPrivateActor(player:Actor, actorType, pos, rot = Vector3.ZERO, id = - 1):
	randomize()
	if id == - 1: id = randi()
	var dict = {
		"actor_type": actorType, 
		"at": pos, 
		"zone": player.current_zone, 
		"actor_id": id, 
		"creator_id": Network.STEAM_ID, 
		"rot": rot, 
		"zone_owner": player.current_zone_owner
	}
	Network._send_P2P_Packet({
		"type": "instance_actor", 
		"params": dict
	}, str(player.owner_id), 2, Network.CHANNELS.GAME_STATE)
	Network.emit_signal("_instance_actor", dict)
	print(get_tree())
	for node in get_tree().get_nodes_in_group("actor"):
		if node.actor_id != id: continue
		#player._wipe_actor(node.actor_id)
		
	return id
	
func clearPrivateActor(player:Actor, actorID):
	sendPrivateActorAction(player, actorID, "_wipe_actor", [actorID])
	for node in get_tree().get_nodes_in_group("actor"):
		if node.actor_id != actorID: continue
		player._wipe_actor(actorID)
	print("cleared " + str(actorID) + " for " + str(player.owner_id))
		
func sendPrivateActorAction(player:Actor, actorID, actionName, params = [], channel = Network.CHANNELS.ACTOR_ACTION):
	Network._send_P2P_Packet({
		"type": "actor_action", 
		"actor_id": actorID, 
		"action": actionName, 
		"params": params
	}, str(player.owner_id), 2, channel)
