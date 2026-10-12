# Paints riverbanks, timber bridges, mountain ridges and the expanded ceremonial grounds.
extends Node2D

const Geography := preload("res://features/landscape/layout.gd")

var render_region := Rect2(0, 0, 2400, 1600)

func _draw() -> void:
	var forest_plaza: Rect2 = preload("res://features/village/layout.gd").FOREST_PLAZA
	_draw_rect(forest_plaza.grow(3), Color("746c4d"))
	_draw_rect(forest_plaza, Color("a59b70"))
	for y in range(int(forest_plaza.position.y),int(forest_plaza.end.y),12):
		_draw_line(Vector2(forest_plaza.position.x,y),Vector2(forest_plaza.end.x,y),Color("8f855d"),1)
	for segment in [Rect2(12, 0, 24, 600), Rect2(12, 600, 88, 1000)]:
		_draw_rect(segment.grow(4), Color("b7ae7d"))
		_draw_rect(segment, Color("518d96"))
		_draw_rect(Rect2(segment.position, Vector2(segment.size.x - 5, segment.size.y)), Color("417985"))
		for y in range(int(segment.position.y + 8), int(segment.end.y), 16):
			for x in range(16, int(segment.end.x - 6), 18): _draw_line(Vector2(x, y), Vector2(x + 10, y), Color("86b9bd"), 1)
	for y: float in Geography.BRIDGES:
		var width := 98 if y > 600 else 34
		_draw_rect(Rect2(8, y - 12, width, 24), Color("654c33"))
		for x in range(10, 8 + width, 5): _draw_rect(Rect2(x, y - 10, 3, 20), Color("bc9460"))
		for side in [-12, 11]: _draw_rect(Rect2(7, y + side, width + 2, 2), Color("e0ba7a"))
	for y in range(-80, 1600, 180):
		_draw_colored_polygon(PackedVector2Array([Vector2(2080, y + 210), Vector2(2160, y + 35), Vector2(2250, y - 10), Vector2(2380, y + 100), Vector2(2400, y + 210)]), Color("8c806b"))
		_draw_colored_polygon(PackedVector2Array([Vector2(2160, y + 35), Vector2(2250, y - 10), Vector2(2290, y + 160), Vector2(2200, y + 100)]), Color("b4a58a"))
		_draw_colored_polygon(PackedVector2Array([Vector2(2250, y - 10), Vector2(2380, y + 100), Vector2(2400, y + 210), Vector2(2290, y + 160)]), Color("706c5e"))
		for offset in [Vector2(20, 80), Vector2(65, 140)]: _draw_line(Vector2(2130, y) + offset, Vector2(2150, y - 12) + offset, Color("c0af8b"), 2)
	var plaza := Geography.PLAZA
	_draw_rect(plaza.grow(3), Color("ae8a60"))
	_draw_rect(plaza, Color("c7ad7a"))
	for y in range(int(plaza.position.y + 3), int(plaza.end.y), 12):
		for x in range(int(plaza.position.x + 3), int(plaza.end.x), 16):
			_draw_rect(Rect2(x, y, 14, 10), Color("cfb889") if (x + y) % 3 else Color("baa078"))
	for x in [490, 606]:
		_draw_rect(Rect2(x - 6, 260, 12, 32), Color("80694b"))
		_draw_rect(Rect2(x - 4, 260, 8, 28), Color("c4a77c"))
		_draw_rect(Rect2(x - 7, 255, 14, 6), Color("e0c18b"))
	_draw_arc(Vector2(548, 317), 27, 0, TAU, 32, Color("a47d55"), 2)

func _draw_rect(rect: Rect2, color: Color) -> void:
	if render_region.intersects(rect): draw_rect(rect, color)

func _draw_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if render_region.intersects(Rect2(a.min(b), (a - b).abs()).grow(width)): draw_line(a, b, color, width)

func _draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	if render_region.intersects(bounds): draw_colored_polygon(points, color)

func _draw_arc(at: Vector2, radius: float, first: float, last: float, count: int, color: Color, width: float) -> void:
	if render_region.intersects(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2)):
		draw_arc(at, radius, first, last, count, color, width)
