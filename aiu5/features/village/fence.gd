# Renders a timber fence segment, including the swinging pen gate.
extends Node2D

var length := 16.0
var vertical := false
var is_gate := false
var open := false

func _draw() -> void:
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
