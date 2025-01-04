extends Panel

var resizing = false
var lastMousePos = Vector2()
var lastSize = Vector2()

onready var panel = get_parent()

func _gui_input(event):
	var mousePos = get_global_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				resizing = true
				lastMousePos = mousePos
			else:
				resizing = false
	elif event is InputEventMouseMotion and resizing:
		var delta = mousePos - lastMousePos
		var newSize = panel.rect_size + delta
		panel.rect_size = newSize
		panel.rect_size.x = max(panel.rect_size.x, 350)
		panel.rect_size.y = max(panel.rect_size.y, 350)
		lastMousePos = mousePos
