# Draws the pig pen's wooden feed trough in the map's pixel palette.
extends Node2D

func _draw() -> void:
	draw_rect(Rect2(-10, -13, 21, 11), Color("644935"))
	draw_rect(Rect2(-9, -12, 19, 8), Color("b48453"))
	draw_rect(Rect2(-8, -11, 17, 5), Color("74523a"))
	for x in range(-6, 9, 3):
		draw_rect(Rect2(x, -10 + x % 2, 2, 2), Color("d6b668"))
	draw_rect(Rect2(-10, -6, 21, 2), Color("d1a36a"))
	for x in [-8, 7]:
		draw_rect(Rect2(x, -4, 2, 5), Color("6e4c35"))
