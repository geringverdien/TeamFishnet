extends Node

var in_game = false
var local_player
var entities

func _ready():
	get_tree().connect("node_added", self, "_on_node_added")
	
func cast_ray(from: Vector3, to: Vector3):
	var space_state = local_player.get_world().get_direct_space_state()
	var result = space_state.intersect_ray(from, to, [])
	if not result:
		return null
	
	if not result.collider:
		return null
		
	return result.collider.get_parent().name

func _on_node_added(node: Node):
	var map: Node = get_tree().current_scene
	in_game = map.name == "world"
	if node.name != "main_map": return
	if not in_game: return
	entities = get_tree().current_scene.get_node("Viewport/main/entities")
	entities.connect("child_entered_tree", self, "player_added")
	
func player_added(node: Node):
	if node.name == "player":
		local_player = node
		yield(get_tree().create_timer(0.5), "timeout")
	else: return
	
	yield(get_tree().create_timer(0.5), "timeout")
	
func _physics_process(delta):
	if not in_game:
		return
	
	if local_player.in_air:
		if local_player.current_zone != "main_zone":
			return
			
		var ray = cast_ray(local_player.global_transform.origin, local_player.global_transform.origin - Vector3(0, 1, 0))
		if ray:
			if "water" in ray:
				local_player.global_transform.origin = local_player.last_valid_pos
				local_player.diving = false
