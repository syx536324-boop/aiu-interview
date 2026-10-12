# Paints a quiet pixel desert and village silhouettes behind the start-screen controls.
extends Control

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 400), Color("302d29"))
	for y in range(0, 220, 4):
		draw_rect(Rect2(0, y, 640, 4), Color("302d29").lerp(Color("9a7553"), y / 220.0))
	draw_circle(Vector2(520, 85), 28, Color("ddbd80"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 223), Vector2(100, 180), Vector2(244, 244), Vector2(400, 200), Vector2(640, 240), Vector2(640, 400), Vector2(0, 400)]), Color("ac8757"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 302), Vector2(130, 262), Vector2(335, 307), Vector2(540, 255), Vector2(640, 286), Vector2(640, 400), Vector2(0, 400)]), Color("c5a16a"))
	for p in [Vector2(70, 230), Vector2(124, 246), Vector2(550, 237)]:
		draw_rect(Rect2(p, Vector2(36, 30)), Color("68523c"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 1), p + Vector2(18, -16), p + Vector2(40, 1)]), Color("8a6744"))
		draw_rect(Rect2(p + Vector2(14, 14), Vector2(9, 16)), Color("382e26"))
	for x in [24, 592]:
		draw_rect(Rect2(x, 283, 4, 36), Color("6a7150"))
		draw_line(Vector2(x + 2, 299), Vector2(x - 7, 293), Color("6a7150"), 4)
	for i in range(80):
		var p := Vector2(posmod(i * 173, 640), 326 + posmod(i * 37, 72))
		draw_rect(Rect2(p, Vector2(2, 1)), Color("9d7c50"))
