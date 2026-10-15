# Paints exposed rock faces, uneven highland rims and contact shadows without changing world collision.
extends Node2D

const Layout := preload("res://features/village/layout.gd")
const SEGMENT := 40.0
var world: Node2D
var landscape_view: Node2D
var render_region := Rect2()
var last_open := 0

func start(village: Node2D, source_view: Node2D) -> void:
	world = village
	landscape_view = source_view
	_update_region()

func _process(_delta: float) -> void:
	_update_region()

func _update_region() -> void:
	if not is_instance_valid(world) or not is_instance_valid(landscape_view): return
	var region: Rect2 = landscape_view.render_region
	var opened: int = hash([world.cliff_open, world.ridge_open])
	if region != render_region or opened != last_open:
		render_region = region
		last_open = opened
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world): return
	_draw_wall(Layout.CLIFF, world.cliff_open, false, 37)
	_draw_wall(Layout.PLATEAU_WALL, {}, true, 73)
	_draw_wall(Layout.RIDGE, world.ridge_open, true, 109)
	draw_set_transform(Vector2.ZERO)

func _draw_wall(area: Rect2, opened: Dictionary, vertical: bool, salt: int) -> void:
	if not render_region.intersects(area.grow(12)): return
	var along := area.size.y if vertical else area.size.x
	var depth := area.size.x if vertical else area.size.y
	var start := area.position.y if vertical else area.position.x
	var visible_start := render_region.position.y if vertical else render_region.position.x
	var visible_end := render_region.end.y if vertical else render_region.end.x
	var first := maxi(0, floori((visible_start - start - 12) / SEGMENT))
	var last := mini(ceili(along / SEGMENT), ceili((visible_end - start + 12) / SEGMENT))
	for index in range(first, last):
		if opened.has(index): continue
		var offset := float(index) * SEGMENT
		var width := minf(SEGMENT, along - offset)
		var origin := Vector2(area.position.x, area.position.y + offset) if vertical else Vector2(area.position.x + offset, area.end.y)
		draw_set_transform(origin, PI / 2 if vertical else 0.0)
		_paint_face(width, depth, index * 15485863 + salt)
	draw_set_transform(Vector2.ZERO)

func _paint_face(width: float, depth: float, key: int) -> void:
	# The three shadow bands fall onto the low ground; actors remain above this terrain layer.
	draw_rect(Rect2(0, 0, width, 3), Color(0.22, 0.16, 0.12, 0.40))
	draw_rect(Rect2(0, 3, width, 3), Color(0.24, 0.18, 0.13, 0.24))
	draw_rect(Rect2(0, 6, width, 3), Color(0.26, 0.20, 0.14, 0.10))
	var cut := minf(width - 4.0, 8.0 + float(posmod(key, 9)))
	var ledge := -depth + float(posmod(key / 7, 3))
	draw_rect(Rect2(0, -depth, width, depth), Color("7d786b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -depth + 2), Vector2(cut, -depth + 4),
		Vector2(cut + 3, -depth * 0.42), Vector2(0, -depth * 0.56)]), Color("a29a82"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(width - 11, -depth * 0.63), Vector2(width, -depth * 0.54),
		Vector2(width, 0), Vector2(width - 5, -2)]), Color("635f57"))
	draw_rect(Rect2(0, -depth * 0.38, width, depth * 0.38), Color(0.30, 0.23, 0.20, 0.21))
	var seam := floorf(depth * 0.54) + float(posmod(key / 13, 3))
	draw_line(Vector2(2, -seam), Vector2(minf(width - 3, cut + 12), -seam - 1), Color("b7ad8f"), 1)
	draw_polyline(PackedVector2Array([Vector2(cut + 2, -seam + 2), Vector2(cut + 7, -seam + 4), Vector2(width - 4, -seam + 3)]), Color("5c584e"), 1)
	var crack := minf(width - 5, cut + 8)
	draw_polyline(PackedVector2Array([
		Vector2(crack, -depth * 0.65), Vector2(crack - 2, -depth * 0.52),
		Vector2(crack + 1, -depth * 0.35), Vector2(crack - 2, -3)]), Color("49473f"), 1)
	draw_line(Vector2(crack + 2, -depth * 0.49), Vector2(crack + 1, -4), Color("a49b83"), 1)
	# Broken rock lips read as a horizontal surface above a darker vertical face.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -depth - 3), Vector2(7, -depth - 5),
		Vector2(minf(width, cut + 9), -depth - 3), Vector2(width, -depth - 4),
		Vector2(width, ledge + 2), Vector2(cut + 2, -depth + 3), Vector2(0, -depth + 1)]), Color("c7c1a8"))
	draw_line(Vector2(0, -depth - 3), Vector2(7, -depth - 5), Color("ece6cc"), 1)
	draw_line(Vector2(7, -depth - 5), Vector2(minf(width, cut + 9), -depth - 3), Color("e4dfcc"), 1)
	draw_rect(Rect2(0, -depth + 3, width, 2), Color(0.29, 0.23, 0.18, 0.36))
	draw_line(Vector2(0, -2), Vector2(width, -1), Color("4b4940"), 2)
