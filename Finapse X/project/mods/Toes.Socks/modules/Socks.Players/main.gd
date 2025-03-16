# class_name Players

extends Node
## The Players module is borrowed from BlueberryWolf's but with performance and developer-experience improvements at the cost of being backward-compatible.
## Nonetheless, you should find Socks.Players will suit your existing needs without many changes.
## In addition, our modules introduce convenient utilities to make mod building more straightforward.
## @experimental

signal player_added(player)
signal player_removed(player)
signal ingame

var by_steam_id := {}
var in_game = false
var local_player
var entities


func _ready():
	get_tree().connect("node_added", self, "_player_ready")


func _player_ready(node: Node):
	var map: Node = get_tree().current_scene
	in_game = map.name == "world"

	if node.name != "main_map":
		return
	if not in_game:
		return

	entities = get_tree().current_scene.get_node("Viewport/main/entities")
	entities.connect("child_entered_tree", self, "_player_added")
	entities.connect("child_exiting_tree", self, "_player_removed")


func is_player(node: Node) -> bool:
	var actor_type = node.get("actor_type")
	return actor_type == "player"


func _add_player(node: Node):
	by_steam_id[node.owner_id] = node

func _remove_player(node: Node):
	by_steam_id.erase(node.owner_id)


func _player_removed(node):
	if !is_player(node):
		return
	if node.name == "player":
		local_player = null
	else:
		_remove_player(node)
	emit_signal("player_removed", node)


func _player_added(node):
	if node.name == "player":
		local_player = node
		_add_player(node)
		yield(get_tree().create_timer(0.5), "timeout")
		emit_signal("ingame")
	elif node.name.begins_with("@player@"):
		_add_player(node)
	else:
		return

	connect("tree_exited", node, "_player_removed")

	yield(get_tree().create_timer(0.5), "timeout")
	emit_signal("player_added", node)


############
## Public ##
############


##  Check whether a given Actor exists as a valid player currently
func is_player_valid(player: Actor) -> bool:
	return is_instance_valid(player) and is_player(player)


## Check whether a player exists and is valid for the given Steam ID
func check(steamid: String) -> bool:
	var id = int(steamid)
	if not id in by_steam_id:
		return false
	return is_player_valid(by_steam_id[id])


## Get a Player by their Steam ID
func get_player(steamid: String) -> Actor:
	assert(
		check(steamid), "No player found with id: " + steamid + "! Check if player exists first!"
	)
	return by_steam_id[int(steamid)]


## Get player's username, either by id or by actor
func get_username(player) -> String:
	var id: int
	if typeof(player) == TYPE_STRING:
		id = int(player)
		assert(
			check(String(id)),
			"No player found with id: " + String(id) + "! Check if player exists first!"
		)
	else:
		if !is_instance_valid(player):
			return ""
		id = player.owner_id
	return Steam.getFriendPersonaName(id)


## Get player's title
## (Convenience method)
func get_title(player: Actor) -> String:
	assert(
		is_player_valid(player),
		"Argument error - Invalid Actor received - check id & validate player object first!"
	)
	return player.get_node("Viewport/player_label").title


## Get player's Steam ID
## *ensures that the ID is a String rather than an int*
## Always use this rather than directly referencing owner_id property
## (Convenience method)
func get_id(player: Actor) -> String:
	assert(
		is_player_valid(player),
		"Argument error - Invalid Actor received - check id & validate player object first!"
	)
	return String(player.owner_id)


## Get player's cosmetics (Dictionary\<String\>)
## (Convenience method)
## `accessory`, `bobber`, `eye`, `hat`, `legs`, `mouth`, `nose`, `overshirt`, `pattern`, `primary_color`
## `secondary_color`, `species`, `tail`, `title`, `undershirt`
func get_cosmetics(player: Actor = local_player) -> Dictionary:
	return player.cosmetic_data


## Set player's cosmetic
## (Convenience method)
## Unstable/TODO
func set_cosmetic(type: String, to: String) -> void:
	if !is_player_valid(local_player):
		return
	assert(
		(
			type
			in [
				"eye",
				"legs",
				"hat",
				"mouth",
				"nose",
				"overshirt",
				"pattern",
				"primary_color",
				"secondary_color",
				"species",
				"tail",
				"title",
				"undershirt"
			]
		),
		"Argument error - Invalid cosmetic type"
	)
	local_player.call_deferred("_change_cosmetics")
	PlayerData._change_cosmetic(type, to)


## Get player's chat color
## (Convenience method)
func get_chat_color(player) -> String:
	var target: Actor
	if typeof(player) == TYPE_STRING:
		target = get_player(player)
	else:
		target = player
	print("Player is {type}".format({"type": str(typeof(player))}))
	return get_cosmetics(player).get("primary_color")


## Get player's current Vector3 position
## (Convenience method)
func get_position(player: Actor) -> Vector3:
	return player.global_transform.origin


## Retrieves the player closet to position
## If omitted, position will be nearest to the local player
func get_nearest_player(at: Vector3 = local_player.global_transform.origin) -> Node:
	if Network.PLAYING_OFFLINE or Network.STEAM_LOBBY_ID <= 0:
		return null

	var all_current_players = get_players()
	if all_current_players.size() == 0:
		return null

	var closest_player: Node
	var min_distance: float = INF

	for player in all_current_players:
		var dist = at.distance_to(get_position(player))
		if dist < min_distance:
			min_distance = dist
			closest_player = player
	return closest_player


## Get a list of (active) player names
func get_names(include_self = false) -> Array:
	var res = []
	for p in get_players(include_self):
		res.append(get_username(p))
	res.sort_custom(self, "sort_by_length")
	return res


## Find player by username
func find(username: String) -> Actor:
	username = username.to_lower()
	for p in get_players():
		var name = get_username(p)
		var name_unstylized = name.to_lower().replacen(" ", "")
		if username == name.to_lower():
			return p
		if username.replacen(" ", "") == name_unstylized:
			return p
	return null


## Get an Array of all currently active players
func get_players(include_self = false) -> Array:
	var res = []
	for p in by_steam_id.values():
		if is_instance_valid(p):
			if local_player.owner_id == p.owner_id and not include_self:
				continue
			res.append(p)
	return res


## Get a Dictionary of all currently active players
func get_players_dict(include_self = false) -> Dictionary:
	var res = {}
	for p in by_steam_id.values():
		if is_instance_valid(p):
			if local_player.owner_id == p.owner_id and not include_self:
				continue
			res[p.owner_id] = p
	return res


## Check if the player is busy
func is_busy(player = local_player):
	return player.busy


static func sort_by_length(a: String, b: String) -> bool:
	return a.length() < b.length()
