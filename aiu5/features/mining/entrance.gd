# Draws the timber-supported cave mouth at the eastern mountain foot.
extends Node2D

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-38, 7), Vector2(-32, -18), Vector2(-18, -33), Vector2(14, -35), Vector2(33, -19), Vector2(39, 7)]), Color("8d806c"))
	draw_colored_polygon(PackedVector2Array([Vector2(-29, -17), Vector2(-16, -30), Vector2(12, -31), Vector2(27, -15)]), Color("b1a38a"))
	draw_rect(Rect2(-15, -18, 30, 25), Color("211e1b"))
	for x in [-20, 16]:
		draw_rect(Rect2(x, -20, 5, 29), Color("60452d"))
		draw_rect(Rect2(x + 1, -20, 2, 27), Color("bb8d56"))
	draw_rect(Rect2(-23, -24, 46, 6), Color("a77c4d"))
	for y in [8, 14, 20]: draw_rect(Rect2(-12, y, 24, 3), Color("b29870"))
	draw_rect(Rect2(27, -4, 2, 11), Color("725235"))
	draw_rect(Rect2(25, -9, 6, 5), Color("e6a158"))
	draw_rect(Rect2(27, -11, 2, 5), Color("ffe3a1"))
