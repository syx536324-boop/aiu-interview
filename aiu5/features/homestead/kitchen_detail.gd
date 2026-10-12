# Adds a mud-brick chimney and drifting pixel smoke to the kitchen exterior.
extends Node2D

var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(13, -53, 10, 24), Color("74523b"))
	draw_rect(Rect2(14, -52, 8, 22), Color("b58b5d"))
	for y in [-49, -43, -37]: draw_line(Vector2(14, y), Vector2(21, y), Color("8b6446"), 1)
	draw_rect(Rect2(11, -55, 14, 5), Color("795b42"))
	for i in range(3):
		var phase := fmod(elapsed * 0.28 + i / 3.0, 1.0)
		var point := Vector2(15 + floorf(sin(phase * 7) * 3), -59 - floorf(phase * 23))
		draw_rect(Rect2(point, Vector2(6, 4)), Color(0.84, 0.80, 0.68, (1 - phase) * 0.5))
