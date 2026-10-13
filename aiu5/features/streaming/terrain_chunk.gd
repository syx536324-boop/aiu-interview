# Draws one deterministic screen-sized patch; no geometry is generated for distant patches.
extends Node2D

const FLOOR := preload("res://assets/ninja_adventure/Backgrounds/Tilesets/TilesetFloor.png")
const Layout := preload("res://features/village/layout.gd")
var area: Rect2
var paths: Array[Vector2] = []
var grains: Array[Vector2] = []
var stones: Array[Vector2] = []
var dunes: Array = []
var plateau := false

func configure(bounds: Rect2) -> void:
	area = bounds
	position = area.position
	plateau = Layout.PLATEAU.intersects(area)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5109 + int(area.position.x) * 7919 + int(area.position.y) * 104729
	var seen: Dictionary = {}
	for route: Array in Layout.ROADS:
		for i in range(route.size() - 1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i + 1]
			var overlap := Rect2(a.min(b), (a - b).abs()).grow(16).intersection(area)
			if not overlap.has_area(): continue
			for y in range(ceili(overlap.position.y / 4) * 4, ceili(overlap.end.y), 4):
				for x in range(ceili(overlap.position.x / 4) * 4, ceili(overlap.end.x), 4):
					var point := Vector2(x, y)
					if seen.has(point): continue
					# Coordinate-based jitter stays identical across unloading/reloading and chunk edges.
					var jitter := float(posmod(x * 73856093 ^ y * 19349663, 601)) / 100.0 - 3.0
					if point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) < 11 + jitter:
						seen[point] = true
						paths.append(point)
	for i in range(roundi(area.get_area() * 17000.0 / Layout.SIZE.x / Layout.SIZE.y)):
		grains.append(Vector2(rng.randi_range(int(area.position.x), int(area.end.x) - 1), rng.randi_range(int(area.position.y), int(area.end.y) - 1)))
	for i in range(roundi(area.get_area() * 1100.0 / Layout.SIZE.x / Layout.SIZE.y)):
		stones.append(Vector2(rng.randi_range(int(area.position.x), int(area.end.x) - 1), rng.randi_range(int(area.position.y), int(area.end.y) - 1)))
	if area.end.x <= 0: return
	for entry in [[Vector2(20, 52), 185, 14], [Vector2(370, 55), 218, 18], [Vector2(18, 298), 95, 10], [Vector2(640, 51), 218, 18], [Vector2(738, 555), 150, 14], [Vector2(298, 553), 195, 10], [Vector2(858, 280), 85, 12]]:
		_add_dune(entry[0], entry[1], entry[2])
	for y in range(650, 1580, 150):
		for x in range(180 + y % 130, 2080, 290): _add_dune(Vector2(x, y), 120 + (x + y) % 80, 10 + y % 13)

func _add_dune(origin: Vector2, width: int, depth: int) -> void:
	if not area.intersects(Rect2(origin - Vector2(0, depth), Vector2(width, depth + 9))): return
	var ridge := PackedVector2Array()
	for x in range(0, width + 1, 4):
		ridge.append(origin + Vector2(x, -floorf(sin(float(x) / width * PI) * depth / 2) * 2))
	var shadow := ridge.duplicate()
	shadow.append(origin + Vector2(width, 8))
	shadow.append(origin + Vector2(0, 8))
	var clip := PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	var pieces := Geometry2D.intersect_polygons(shadow, clip)
	dunes.append({"shadow": pieces, "ridges": Geometry2D.intersect_polyline_with_polygon(ridge, clip)})

func _draw() -> void:
	draw_set_transform(-area.position)
	if area.end.x <= 0:
		draw_rect(area,Color("57794d"))
		for point in grains: draw_rect(Rect2(point,Vector2(2,2)),Color("718b53") if int(point.x)%3==0 else Color("496c46"))
		for point in stones: draw_rect(Rect2(point,Vector2(2,2)),Color("a5ae69"))
		for point in paths: draw_rect(Rect2(point,Vector2(4,4)),Color("a39160"))
		return
	for y in range(floori(area.position.y / 16) * 16, ceili(area.end.y), 16):
		for x in range(floori(area.position.x / 16) * 16, ceili(area.end.x), 16):
			var tile := Rect2(x, y, 16, 16)
			var clipped := tile.intersection(area)
			draw_texture_rect_region(FLOOR, clipped, Rect2(Vector2(16, 16) + clipped.position - tile.position, clipped.size), Color(0.90, 0.91, 0.90))
	for dune: Dictionary in dunes:
		for piece: PackedVector2Array in dune.shadow: draw_colored_polygon(piece, Color("ddb174"))
		for ridge: PackedVector2Array in dune.ridges:
			if ridge.size() > 1: draw_polyline(ridge, Color("f1ce94"), 2)
	for point in paths: draw_rect(Rect2(point, Vector2(4, 4)), Color("d8aa70"))
	for i in range(grains.size()): draw_rect(Rect2(grains[i], Vector2(2 if i % 5 == 0 else 1, 1)), Color("eec98e") if i % 3 == 0 else Color("cba269"))
	for point in stones:
		if Rect2(212, 224, 92, 60).has_point(point): continue
		draw_rect(Rect2(point, Vector2(3, 2)), Color("c39a64"))
		draw_rect(Rect2(point, Vector2(2, 1)), Color("efd09a"))
	if plateau:
		# Cool grey highland rock instead of desert sand; the southern cliff is drawn by landscape/view.
		for y in range(floori(area.position.y / 16) * 16, ceili(area.end.y), 16):
			for x in range(floori(area.position.x / 16) * 16, ceili(area.end.x), 16):
				var rock := Rect2(x, y, 16, 16)
				var solid := rock.intersection(area)
				draw_texture_rect_region(FLOOR, solid, Rect2(Vector2(16, 16) + solid.position - rock.position, solid.size), Color(0.70, 0.73, 0.78))
		for i in range(grains.size()): draw_rect(Rect2(grains[i], Vector2(2 if i % 4 == 0 else 1, 1)), Color("9aa0a6") if i % 3 == 0 else Color("6d6f72"))
		for point in stones:
			draw_rect(Rect2(point, Vector2(3, 2)), Color("8b8f93"))
			draw_rect(Rect2(point, Vector2(2, 1)), Color("c3c8cc"))
		return
	var pen := Rect2(386, 211, 92, 60).intersection(area)
	if pen.has_area():
		draw_rect(pen, Color("c49b6c"))
		for row in range(4):
			for col in range(7):
				var p := Vector2(390 + col * 12 + row % 2 * 3, 222 + row * 12)
				if area.has_point(p): draw_line(p, p + Vector2(3, -1), Color("e3c182"), 1)
