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
var mountain := false
var patches: Array[Vector2] = []
var scree: Array[Vector2] = []

func configure(bounds: Rect2) -> void:
	area = bounds
	position = area.position
	plateau = Layout.PLATEAU.intersects(area)
	mountain = Layout.MOUNTAINS_EAST.intersects(area)
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
	if plateau or mountain:
		# Tundra patches and scree keep their positions across unloading because the seed is positional.
		for i in range(12):
			patches.append(Vector2(rng.randi_range(int(area.position.x), int(area.end.x) - 1), rng.randi_range(int(area.position.y), int(area.end.y) - 1)))
		for i in range(110):
			scree.append(Vector2(rng.randi_range(int(area.position.x), int(area.end.x) - 1), rng.randi_range(int(area.position.y), int(area.end.y) - 1)))

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
	if mountain:
		# Dark slate mountain rock: layered strata, snow fields and heavy scree, colder than the plateau.
		draw_rect(area, Color("474e55"))
		for gy in range(floori(area.position.y / 32) * 32, ceili(area.end.y), 32):
			var band := Rect2(area.position.x, gy, area.size.x, 32).intersection(area)
			if not band.has_area(): continue
			var shade := float(posmod(gy * 19349663, 9)) / 9.0
			draw_rect(band, Color("525a61").lerp(Color("3f464c"), shade))
			draw_rect(Rect2(band.position, Vector2(band.size.x, 2)), Color("69717a"))
			for x in range(int(area.position.x) - 64, int(area.end.x) + 32, 26):
				var lean := float(posmod(x * 73856093 ^ gy * 19349663, 13))
				draw_line(Vector2(x + lean, gy + 4), Vector2(x + lean + 20, gy + 30), Color("5d656d"), 1)
		for point in scree:
			draw_rect(Rect2(point, Vector2(3, 2)), Color("7d858d") if int(point.x) % 3 == 0 else Color("343a40"))
		for point in patches:
			var snow: bool = area.position.y < -400.0 or int(point.y) % 3 == 0
			var base := Color("c3cfd8") if snow else Color("57616a")
			var top := Color("e9f1f6") if snow else Color("66707a")
			# Stepped, dithered fields read as snow or moss instead of solid white blocks.
			for row in range(3):
				var wide: float = float(20 - row * 5)
				var ox := float(posmod(int(point.x) + row * 7919, 5))
				draw_rect(Rect2(point + Vector2(ox + float(row) * 2.0, float(row) * 4.0), Vector2(wide, 4.0)), base)
			draw_rect(Rect2(point + Vector2(4, 1), Vector2(9, 2)), top)
			for i in range(6):
				var fx: float = point.x + float(posmod(int(point.y) + i * 2654435761, 24))
				draw_rect(Rect2(fx, point.y + float(i % 3) * 5.0, 2, 2), top)
		for i in range(grains.size()): draw_rect(Rect2(grains[i], Vector2(2 if i % 4 == 0 else 1, 1)), Color("9fb0bb") if i % 3 == 0 else Color("3c4249"))
		for point in stones:
			draw_rect(Rect2(point, Vector2(3, 2)), Color("6f7780"))
			draw_rect(Rect2(point, Vector2(2, 1)), Color("c8d3da"))
		return
	if plateau:
		# Cold grey highland rock: plates with strata cracks, tundra patches, scree and a rim snow line.
		draw_rect(area, Color("5c6167"))
		for gy in range(floori(area.position.y / 24) * 24, ceili(area.end.y), 24):
			for gx in range(floori(area.position.x / 32) * 32, ceili(area.end.x), 32):
				var plate := Rect2(gx, gy, 32, 24).intersection(area)
				if not plate.has_area(): continue
				var tone := float(posmod(gx * 73856093 ^ gy * 19349663, 7)) / 7.0
				draw_rect(plate, Color("696f75").lerp(Color("545a60"), tone))
				draw_rect(Rect2(plate.position, Vector2(plate.size.x, 1)), Color("81878d"))
				draw_rect(Rect2(plate.position + Vector2(0, plate.size.y - 1), Vector2(plate.size.x, 1)), Color("474c51"))
		for cy in range(floori(area.position.y / 16) * 16, ceili(area.end.y), 16):
			for cx in range(floori(area.position.x / 8) * 8, ceili(area.end.x), 8):
				var grain := posmod(cx * 73856093 ^ cy * 19349663, 401)
				if grain % 97 >= 22: continue
				var at := Vector2(cx + float(grain % 5) * 2.0, cy + float(grain % 3) * 3.0)
				if not area.has_point(at): continue
				draw_rect(Rect2(at, Vector2(8, 1 + grain % 2)), Color("43484d"))
		for point in patches:
			draw_rect(Rect2(point, Vector2(18, 12)), Color("5d6a57"))
			draw_rect(Rect2(point + Vector2(2, 2), Vector2(12, 8)), Color("68765f"))
			draw_rect(Rect2(point + Vector2(5, 4), Vector2(5, 3)), Color("79866d"))
		for point in scree:
			draw_rect(Rect2(point, Vector2(3, 2)), Color("8d9399") if int(point.x) % 3 == 0 else Color("4b5055"))
		for i in range(grains.size()): draw_rect(Rect2(grains[i], Vector2(2 if i % 4 == 0 else 1, 1)), Color("9aa0a6") if i % 3 == 0 else Color("6d6f72"))
		for point in stones:
			draw_rect(Rect2(point, Vector2(3, 2)), Color("868c92"))
			draw_rect(Rect2(point, Vector2(2, 1)), Color("c3c8cc"))
		if area.end.y >= -40:
			# Frost band and drifting flakes just north of the southern cliff.
			draw_rect(Rect2(area.position.x, -46, area.size.x, 5), Color(0.88, 0.91, 0.95, 0.72))
			for i in range(30):
				var fx: float = area.position.x + float(posmod(i * 2654435761, int(area.size.x)))
				draw_rect(Rect2(fx, -53.0 - float(i % 3) * 4.0, 3, 2), Color(0.93, 0.95, 0.98, 0.8))
		return
	var pen := Rect2(386, 211, 92, 60).intersection(area)
	if pen.has_area():
		draw_rect(pen, Color("c49b6c"))
		for row in range(4):
			for col in range(7):
				var p := Vector2(390 + col * 12 + row % 2 * 3, 222 + row * 12)
				if area.has_point(p): draw_line(p, p + Vector2(3, -1), Color("e3c182"), 1)
