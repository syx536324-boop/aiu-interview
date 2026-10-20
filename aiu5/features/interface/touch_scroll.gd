# Adds direct one-finger dragging and momentum to a scroll pane without requiring its scrollbar.
extends Node
var scroll: ScrollContainer
var finger := -1
var origin := Vector2.ZERO
var previous := Vector2.ZERO
var previous_time := 0
var dragging := false
var speed := 0.0
var suppress_until := 0

static func attach(container: ScrollContainer) -> Node:
	var gesture: Node=load("res://features/interface/touch_scroll.gd").new()
	gesture.scroll=container;container.add_child(gesture)
	return gesture

func blocks_click() -> bool:
	return dragging or Time.get_ticks_msec()<suppress_until

func _move(amount: float) -> void:
	var bar: VScrollBar=scroll.get_v_scroll_bar()
	scroll.scroll_vertical=int(clampf(float(scroll.scroll_vertical)+amount,0,maxf(0,bar.max_value-bar.page)))

func _input(event: InputEvent) -> void:
	if not is_instance_valid(scroll) or not scroll.is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed and finger<0 and scroll.get_global_rect().has_point(event.position):
			finger=event.index;origin=event.position;previous=origin;previous_time=Time.get_ticks_msec();speed=0;dragging=false
		elif not event.pressed and event.index==finger:
			finger=-1
			if dragging:
				suppress_until=Time.get_ticks_msec()+180;dragging=false;get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==finger:
		if not dragging and event.position.distance_to(origin)>=8:dragging=true
		if dragging:
			var now:=Time.get_ticks_msec()
			var elapsed: float=clampf(float(now-previous_time)/1000.0,0.008,0.1)
			var distance: float=event.position.y-previous.y
			_move(-distance);speed=clampf(-distance/elapsed,-1800,1800)
			suppress_until=now+180;get_viewport().set_input_as_handled()
		previous=event.position;previous_time=Time.get_ticks_msec()

func _process(delta: float) -> void:
	if not is_instance_valid(scroll) or not scroll.is_visible_in_tree():finger=-1;dragging=false;speed=0;return
	if finger<0 and absf(speed)>5:
		var before: int=scroll.scroll_vertical
		_move(speed*delta)
		speed=move_toward(speed,0,1800*delta)
		if scroll.scroll_vertical==before:speed=0
