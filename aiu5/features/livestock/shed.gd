# Draws the open timber cattle shelter and exposes its protected building footprint.
extends Node2D

const BOUNDS := Rect2(48, 406, 120, 80)
const PASTURE := Rect2(62, 434, 90, 38)
const FEEDING := Vector2(146, 445)

func _draw() -> void:
	draw_rect(Rect2(51, 411, 114, 72), Color("aa915c"))
	for y in range(420, 480, 8):
		for x in range(58 + y % 3, 160, 13): draw_line(Vector2(x, y), Vector2(x + 5, y - 2), Color("c8ad72"), 1)
	draw_rect(Rect2(52, 397, 112, 20), Color("674b32"))
	for y in [399, 405, 411]: draw_rect(Rect2(54, y, 108, 3), Color("a37b4b"))
	for x in [55, 159]:
		draw_rect(Rect2(x, 414, 4, 22), Color("65492f"))
		draw_rect(Rect2(x + 1, 414, 1, 21), Color("d3af72"))
