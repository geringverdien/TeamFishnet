extends Node

const MOD_ID = "eli.Mousefish"

var config = {
	"enabled": true,
	"url": "http://www.rw-designer.com/cursor-view/114789.png",
	"hotspot_x": 0,
	"hotspot_y": 0
}


onready var TackleBox := $"/root/TackleBox"

func update_cursor():
	if not config.enabled: 
		print("set cursor to default")
		Input.set_custom_mouse_cursor(load("res://Assets/Textures/UI/cursor.png"))
		return
	
	
	var url = config.url
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", self, "_http_request_completed")

	var error = http_request.request(config.url)
	if error != OK:
		push_error("cursor http request failed")
	print("updated custom cursor")

func _ready() -> void:
	_init_config()
	update_cursor()

func _init_config() -> void:
	var saved_config = TackleBox.get_mod_config(MOD_ID)

	for key in config.keys():
		if not saved_config.has(key):
			saved_config[key] = config[key]
	
	config = saved_config.duplicate()
	TackleBox.set_mod_config(MOD_ID, config)
	TackleBox.connect("mod_config_updated", self, "_on_config_update")

func _on_config_update(mod_id: String, new_config: Dictionary) -> void:
	if mod_id != MOD_ID: return
	config = new_config.duplicate()
	update_cursor()
	

func _http_request_completed(result, response_code, headers, body):
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("cursor image failed to load")
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	Input.set_custom_mouse_cursor(texture , 0, Vector2(config.hotspot_x, config.hotspot_y))
