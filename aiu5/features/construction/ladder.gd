# Draws a wooden cloud ladder leaning against the plateau cliff.
extends Node2D

func _draw() -> void:
	for x in [-15, 11]: draw_rect(Rect2(x, -52, 4, 52), Color("8a6a41"))
	for y in range(-46, -2, 8): draw_rect(Rect2(-15, y, 30, 3), Color("c49a63"))
	draw_rect(Rect2(-20, -56, 40, 5), Color("6f5535"))
	draw_rect(Rect2(4, -12, 8, 6), Color("a98650"))
