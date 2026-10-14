# Renders a timber fence segment, including the swinging pen gate.
extends Node2D

var hp := 10.0
var body: StaticBody2D
var world: Node
var length := 16.0
var vertical := false
var is_gate := false
var open := false

func _draw() -> void:
	if hp<=0: return
	if vertical or (is_gate and open):
		for y in range(0, int(length), 4):
			draw_rect(Rect2(-2, y - 8, 4, 4), Color("90603e"))
			draw_rect(Rect2(-1, y - 8, 1, 4), Color("d5a56e"))
		_post(Vector2.ZERO)
		_post(Vector2(0, length))
	else:
		draw_rect(Rect2(0, -9, length, 3), Color("6a4733"))
		draw_rect(Rect2(0, -10, length, 2), Color("c18d59"))
		draw_rect(Rect2(0, -4, length, 2), Color("9d6f47"))
		if is_gate:
			draw_line(Vector2(2, -3), Vector2(length - 2, -9), Color("d7a76c"), 2)
		_post(Vector2.ZERO)
		_post(Vector2(length, 0))

func _post(point: Vector2) -> void:
	draw_rect(Rect2(point + Vector2(-2, -13), Vector2(5, 15)), Color("684834"))
	draw_rect(Rect2(point + Vector2(-1, -13), Vector2(3, 13)), Color("b68350"))
	draw_rect(Rect2(point + Vector2(-1, -13), Vector2(3, 2)), Color("e6bc7f"))
func visual_bounds() -> Rect2:
	return Rect2(position+Vector2(-4,-14),Vector2(10,length+18) if vertical or (is_gate and open) else Vector2(length+8,18))
func damage(raw: float) -> void:
	hp=maxf(0,hp-raw)
	if is_instance_valid(body): body.collision_layer=0 if hp<=0 or (is_gate and open) else 1
	queue_redraw(); world.refresh_obstacles()
