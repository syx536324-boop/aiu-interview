# Adds the well's visible water, timber supports, rope and bucket over its stone base.
extends Node2D

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -14), Vector2(-6, -19), Vector2(6, -19), Vector2(10, -14), Vector2(7, -10), Vector2(-7, -10)]), Color("466e6c"))
	draw_rect(Rect2(-7, -16, 14, 4), Color("76aba2"))
	draw_line(Vector2(-5, -14), Vector2(-1, -14), Color("bdd2b5"), 1)
	for x in [-13, 11]:
		draw_rect(Rect2(x, -34, 3, 24), Color("694b35"))
		draw_rect(Rect2(x, -34, 1, 22), Color("c49b66"))
	draw_rect(Rect2(-16, -36, 32, 4), Color("654733"))
	draw_rect(Rect2(-15, -36, 30, 2), Color("c99d66"))
	draw_line(Vector2(1, -32), Vector2(1, -19), Color("ccb483"), 1)
	draw_rect(Rect2(-2, -21, 6, 4), Color("77513b"))
	draw_rect(Rect2(-1, -21, 4, 1), Color("d9b77c"))
