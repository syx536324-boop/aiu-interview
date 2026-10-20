# Provides independent finger ownership for simultaneous joystick and action touches.
extends Control
signal down
signal up
signal activated
var caption := ""
var finger := -1
var held := false
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): release())

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and is_visible_in_tree() and finger == -1 and get_global_rect().has_point(event.position):
			finger = event.index; held = true; down.emit(); queue_redraw(); get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			var activate := get_global_rect().has_point(event.position)
			release()
			if activate: activated.emit()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and finger == -1:
		if event.pressed: held = true; down.emit(); queue_redraw()
		else:
			var activate := held
			release()
			if activate: activated.emit()
		accept_event()

func release() -> void:
	var previous := held
	finger = -1; held = false; queue_redraw()
	if previous: up.emit()

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.47,0.39,0.24,0.95) if held else Color(0.16,0.14,0.11,0.78)
	style.border_color = Color("d9bf82"); style.set_border_width_all(1); style.set_corner_radius_all(7)
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	if is_instance_valid(font):
		var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_string(font,Vector2((size.x-width)/2,(size.y+font.get_ascent(12)-font.get_descent(12))/2),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f8e5b9"))
