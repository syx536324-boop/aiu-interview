# Renders farm soil, living/dead crops and an oasis from homestead state.
extends Node2D

var plots: Array = []
var focus_index := -1
var render_region := Rect2(-2400, -1600, 7200, 3200)
const LAKE := Rect2(64, 170, 84, 70)

func focus(index: int) -> void:
	if focus_index == index: return
	focus_index = index
	queue_redraw()

func _draw() -> void:
	_lake_shape(LAKE.grow(6), Color("bfad7b"))
	_lake_shape(LAKE.grow(2), Color("78a89a"))
	_lake_shape(LAKE, Color("528a8e"))
	_lake_shape(LAKE.grow(-7), Color("417e85"))
	for y in range(180, 235, 12):
		for x in range(72 + y % 7, 140, 22):
			draw_line(Vector2(x, y), Vector2(x + 10, y), Color("91bdb0"), 1)
	for p: Dictionary in plots:
		var rect := bounds(p)
		if not rect.grow(16).intersects(render_region): continue
		var moist: bool = not p.dry
		draw_rect(rect.grow(1), Color("b78b59"))
		draw_rect(rect, Color("70543d") if moist else Color("a8794d"))
		for y in range(int(rect.position.y + 5), int(rect.end.y - 1), 8):
			draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y), Color("564330") if moist else Color("805a3c"), 2)
		if p.crop != "":
			for y in range(int(rect.position.y + 12), int(rect.end.y - 1), 14):
				for x in range(int(rect.position.x + 6), int(rect.end.x - 1), 12):
					_draw_crop(Vector2(x, y), p)
		if moist:
			draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(5, 1)), Color("88aba0"))
		draw_rect(rect, Color("493d2d"), false, 1)
	if focus_index >= 0 and focus_index < plots.size():
		draw_rect(bounds(plots[focus_index]).grow(-1), Color("f4d77d"), false, 1)

static func bounds(p: Dictionary) -> Rect2:
	return Rect2(float(p.x), float(p.y), float(p.w), float(p.h))

func _draw_crop(at: Vector2, p: Dictionary) -> void:
	if p.crop == "dead":
		draw_line(at, at + Vector2(0, -7), Color("b29161"), 2)
		draw_line(at + Vector2(0, -3), at + Vector2(4, -6), Color("b29161"), 1)
		return
	var stage := int(p.get("stage", 1))
	var rice: bool = p.crop == "rice"
	var ripe: bool = p.get("mature", false)
	var stem := Color("a08a43") if ripe else (Color("66975c") if rice else Color("7c9a43"))
	var leaf := Color("c3a64d") if ripe else (Color("91b76e") if rice else Color("a4ba58"))
	var height: int = [3, 5, 8, 10][stage - 1]
	draw_line(at, at + Vector2(0, -height), stem, 1)
	draw_line(at + Vector2(0, -1), at + Vector2(-3, -mini(height, 4)), leaf, 1)
	if stage >= 2:
		draw_line(at + Vector2(0, -2), at + Vector2(3, -mini(height, 5)), leaf, 1)
	if rice:
		draw_line(at + Vector2(2, 0), at + Vector2(2, -maxi(2, height - 2)), stem, 1)
	if stage >= 3:
		draw_line(at + Vector2(0, -4), at + Vector2(-3, -7), leaf, 1)
	if stage == 4:
		var grain := Color("e4d197") if rice and ripe else (Color("e1b84f") if ripe else Color("a8b66a"))
		if rice:
			draw_line(at + Vector2(0, -10), at + Vector2(3, -9), stem, 1)
			draw_line(at + Vector2(3, -9), at + Vector2(4, -5), stem, 1)
			for offset in [Vector2(1, -10), Vector2(3, -8), Vector2(4, -6)]:
				draw_rect(Rect2(at + offset, Vector2(2, 2)), grain)
		else:
			for y in [-10, -8, -6]:
				draw_rect(Rect2(at + Vector2(-2, y), Vector2(2, 2)), grain)
				draw_rect(Rect2(at + Vector2(1, y - 1), Vector2(2, 2)), grain)
		if ripe: draw_rect(Rect2(at + Vector2(0, -12), Vector2(1, 1)), Color("f3e2a2"))

func _lake_shape(rect: Rect2, color: Color) -> void:
	var a := rect.position
	var b := rect.end
	draw_colored_polygon(PackedVector2Array([
		Vector2(a.x + 18, a.y), Vector2(b.x - 12, a.y), Vector2(b.x - 12, a.y + 5),
		Vector2(b.x - 4, a.y + 5), Vector2(b.x - 4, a.y + 13), Vector2(b.x, a.y + 13),
		Vector2(b.x, b.y - 12), Vector2(b.x - 10, b.y - 12), Vector2(b.x - 10, b.y - 5),
		Vector2(b.x - 24, b.y - 5), Vector2(b.x - 24, b.y), Vector2(a.x + 12, b.y),
		Vector2(a.x + 12, b.y - 7), Vector2(a.x, b.y - 7), Vector2(a.x, a.y + 16),
		Vector2(a.x + 9, a.y + 16), Vector2(a.x + 9, a.y + 6), Vector2(a.x + 18, a.y + 6)
	]), color)
