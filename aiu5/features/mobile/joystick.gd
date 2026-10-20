# Converts a captured touch into the existing movement actions and releases on interruption.
extends Control
var finger := -1
var stick := Vector2.ZERO
const RADIUS := 43.0
const DEADZONE := 0.15

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): release())

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and is_visible_in_tree() and get_global_rect().has_point(event.position):
			finger = event.index; move_stick(event.position); get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			release(); get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		move_stick(event.position); get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and finger in [-1,-2]:
		if event.pressed: finger = -2; move_stick(event.position+global_position)
		else: release()
		accept_event()
	elif event is InputEventMouseMotion and finger == -2:
		move_stick(event.position+global_position); accept_event()

func move_stick(point: Vector2) -> void:
	stick = ((point-get_global_rect().get_center())/RADIUS).limit_length()
	var strength := (stick.length()-DEADZONE)/(1.0-DEADZONE) if stick.length()>DEADZONE else 0.0
	var direction := stick.normalized()*strength
	for pair: Array in [["move_left",-direction.x],["move_right",direction.x],["move_up",-direction.y],["move_down",direction.y]]:
		if float(pair[1])>0: Input.action_press(pair[0],float(pair[1]))
		else: Input.action_release(pair[0])
	queue_redraw()

func release() -> void:
	finger = -1; stick = Vector2.ZERO
	for action: String in ["move_left","move_right","move_up","move_down"]:
		if InputMap.has_action(action): Input.action_release(action)
	queue_redraw()

func _draw() -> void:
	draw_circle(size/2,RADIUS+7,Color(0.12,0.11,0.08,0.6))
	draw_arc(size/2,RADIUS+7,0,TAU,48,Color(0.8,0.69,0.45,0.8),1)
	draw_circle(size/2+stick*RADIUS,18,Color(0.7,0.58,0.35,0.85))
	draw_arc(size/2+stick*RADIUS,18,0,TAU,24,Color("f5dc9c"),1)
