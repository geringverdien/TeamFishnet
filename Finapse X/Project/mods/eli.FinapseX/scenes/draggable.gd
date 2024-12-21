extends Panel

var isDragging = false
var lastPos

func _gui_input(event):
	var mousePos = get_global_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				if get_global_rect().has_point(mousePos):
					isDragging = true
					lastPos = mousePos
			else:
				isDragging = false

	elif event is InputEventMouseMotion and isDragging:
		var offset = mousePos - lastPos
		rect_position = rect_position + offset
		lastPos = mousePos
