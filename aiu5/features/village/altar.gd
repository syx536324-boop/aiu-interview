# Draws a small ceremonial stone altar and its brief offering animation.
extends Node2D

var ceremony_time := 0.0

func perform() -> void:
	ceremony_time = 4.0
	queue_redraw()

func _process(delta: float) -> void:
	if ceremony_time > 0:
		ceremony_time = maxf(0, ceremony_time - delta)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-34, -5, 68, 6), Color("b18c60"))
	draw_rect(Rect2(-30, -14, 60, 12), Color("806548"))
	draw_rect(Rect2(-29, -14, 58, 9), Color("c5a071"))
	draw_rect(Rect2(-25, -23, 50, 12), Color("e1bf8b"))
	draw_rect(Rect2(-25, -23, 50, 2), Color("f0d3a0"))
	draw_rect(Rect2(-6, -20, 12, 13), Color("a36346"))
	draw_line(Vector2(-4, -17), Vector2(3, -10), Color("e4bd7e"), 1)
	draw_line(Vector2(3, -17), Vector2(-4, -10), Color("e4bd7e"), 1)
	draw_rect(Rect2(-2, -40, 4, 20), Color("79573b"))
	draw_rect(Rect2(-11, -37, 22, 3), Color("b08150"))
	draw_rect(Rect2(-5, -43, 10, 8), Color("f0d5a5"))
	draw_rect(Rect2(-3, -40, 2, 2), Color("75573e"))
	draw_rect(Rect2(2, -40, 2, 2), Color("75573e"))
	for x in [-13, 10]:
		draw_rect(Rect2(x, -22, 5, 3), Color("90603f"))
		draw_rect(Rect2(x + 1, -23, 3, 1), Color("d7bc73"))
	if ceremony_time > 0:
		for i in range(7):
			var angle := float(i) / 7 * TAU + ceremony_time * 0.5
			var point := Vector2(cos(angle) * 25, -19 + sin(angle) * 9 - (4 - ceremony_time) * 3).round()
			draw_rect(Rect2(point, Vector2(2, 2)), Color("f3dfa3"))
