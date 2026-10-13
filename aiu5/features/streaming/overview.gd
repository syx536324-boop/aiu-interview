# Presents a cached schematic map and a frozen snapshot of actor markers independently of world scenes.
extends CanvasLayer

const Layout := preload("res://features/village/layout.gd")
const Geography := preload("res://features/landscape/layout.gd")
const Land := preload("res://features/homestead/land.gd")
var world: Node2D
var grounds: Node2D
var farming: Node
var texture: ImageTexture
var background: TextureRect
var markers: Control
var captions: Control
var signature := ""
var build_count := 0
const MAP_RECT := Rect2(104, 90, 432, 288)
const SCALE := 0.06
const MAP_OFFSET_Y := 48.0
# Exploration fog: a chunk stays lit for thirty seconds after it was loaded; the home village is always lit.
const FOG_SECONDS := 30
const FOG_CELL := Vector2(320, 200)
var lit: Dictionary = {}
var fog

class Fog extends Control:
	const CELL := Vector2(320, 200)
	const SCALE := 0.06
	const OFFSET_Y := 48.0
	const SECONDS := 30.0
	var lit: Dictionary = {}
	var origin := Vector2.ZERO
	var home := Rect2()
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var now := Time.get_ticks_msec()
		for cy in range(-8, 8):
			for cx in range(-8, 15):
				var id := Vector2i(cx, cy)
				var area := Rect2(Vector2(id) * CELL, CELL)
				if home.intersects(area): continue
				if lit.has(id) and now - int(lit[id]) <= int(SECONDS * 1000.0): continue
				draw_rect(Rect2((area.position - origin) * SCALE + Vector2(0, OFFSET_Y), area.size * SCALE), Color(0.02, 0.02, 0.03, 0.92))


static func project(at: Vector2) -> Vector2:
	# The widened map (7200x3200) fits the 432x288 panel at this scale, centred vertically.
	return (at - Layout.MIN) * SCALE + Vector2(0, MAP_OFFSET_Y)

class Captions extends Control:
	var entries: Array[Dictionary] = []
	var font := SystemFont.new()
	func arrange(records: Array[Dictionary]) -> void:
		for child in get_children(): child.free()
		entries.clear()
		font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
		var occupied: Array[Rect2] = []
		for record: Dictionary in records: occupied.append(record.bounds.grow(2))
		for record: Dictionary in records:
			var label := Label.new()
			label.text = str(record.text)
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", Color("f6e6bf"))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(label)
			var bounds := _place(record.at, label.get_minimum_size() + Vector2(6, 2), occupied)
			occupied.append(bounds.grow(2))
			label.position = bounds.position + Vector2(3, 1)
			entries.append({"id": record.id, "text": record.text, "at": record.at, "bounds": bounds})
		queue_redraw()
	func _place(at: Vector2, extent: Vector2, occupied: Array[Rect2]) -> Rect2:
		var limits := Rect2(2, 2, 428, 284)
		for distance in range(6, 135, 8):
			var offsets := [Vector2(-extent.x / 2, -extent.y - distance), Vector2(distance, -extent.y / 2),
				Vector2(-extent.x / 2, distance), Vector2(-extent.x - distance, -extent.y / 2),
				Vector2(distance, -extent.y - distance), Vector2(-extent.x - distance, -extent.y - distance),
				Vector2(distance, distance), Vector2(-extent.x - distance, distance)]
			for offset: Vector2 in offsets:
				var bounds := Rect2((at + offset).round(), extent)
				if limits.encloses(bounds) and not occupied.any(func(other: Rect2) -> bool: return other.intersects(bounds)):
					return bounds
		# Exhaustive placement is only needed if future settlements become unusually dense.
		var best := Rect2(Vector2(2, 2), extent)
		var score := INF
		for y in range(2, int(286 - extent.y), 6):
			for x in range(2, int(430 - extent.x), 6):
				var bounds := Rect2(Vector2(x, y), extent)
				if occupied.any(func(other: Rect2) -> bool: return other.intersects(bounds)): continue
				var gap := at.distance_squared_to(bounds.get_center())
				if gap < score:
					score = gap
					best = bounds
		return best
	func _draw() -> void:
		for entry: Dictionary in entries:
			var bounds: Rect2 = entry.bounds
			var end := Vector2(clampf(entry.at.x, bounds.position.x, bounds.end.x), clampf(entry.at.y, bounds.position.y, bounds.end.y))
			draw_line(entry.at, end, Color("554531"), 1)
		for entry: Dictionary in entries:
			draw_rect(entry.bounds, Color(0.23, 0.19, 0.14, 0.94))
			draw_rect(entry.bounds, Color("a18455"), false, 1)

class Markers extends Control:
	var entries: Array = []
	func _draw() -> void:
		for entry: Dictionary in entries:
			var color := Color("fff4af") if entry.active else (Color("90d9ae") if entry.playable else Color("f0dbb1"))
			if entry.get("enemy",false): color=Color("ef8565")
			draw_circle(entry.at, 3.5 if entry.active else 1.8, Color("40382e"))
			draw_circle(entry.at, 2.5 if entry.active else 1.2, color)

func start(village: Node2D, outdoor: Node2D, crops: Node) -> void:
	world = village
	grounds = outdoor
	farming = crops
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := ColorRect.new()
	panel.color = Color("2f2c24")
	panel.size = Vector2(640, 400)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	background = TextureRect.new()
	background.position = MAP_RECT.position
	background.size = MAP_RECT.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	fog = Fog.new()
	fog.position = MAP_RECT.position
	fog.origin = Layout.MIN
	fog.home = Layout.HOME_LIT
	add_child(fog)
	captions = Captions.new()
	captions.position = MAP_RECT.position
	captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(captions)
	markers = Markers.new()
	markers.position = MAP_RECT.position
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(markers)
	_label("赤沙村 · 全图", Vector2(104, 59), 15)
	_label("游戏已暂停 · M / Esc 返回", Vector2(335, 64), 11)
	_label("北", Vector2(545, 96), 12)
	_label("红点：外部落敌人",Vector2(104,76),9)
	_label("黑：未探索 · 走过点亮30秒",Vector2(376,76),9)
	_label("西岸森林", Vector2(110, 108), 11)
	_label("沙漠", Vector2(480, 108), 11)
	_label("东山", Vector2(548, 241), 11)
	visible = false

func _label(text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("eadbb9"))
	label.text = text
	label.position = at
	add_child(label)

func mark_loaded() -> void:
	# Every chunk the streamer has loaded counts as explored at this moment.
	var now := Time.get_ticks_msec()
	if not is_instance_valid(world) or not is_instance_valid(world.terrain): return
	for id: Vector2i in world.terrain.chunks.keys(): lit[id] = now
	if fog: fog.lit = lit

func present() -> void:
	# Only static changes invalidate the map; opening it never instantiates distant terrain/rooms.
	mark_loaded()
	var homes: Array = world.homes.map(func(home: Dictionary) -> Array: return [home.id, home.name, home.at, home.region.size, home.door])
	var next := JSON.stringify([homes, grounds.export_layout(), farming.plots.map(func(p: Dictionary) -> Array: return [p.x, p.y, p.w, p.h])])
	if texture == null or signature != next:
		signature = next
		_build()
	var entries: Array = []
	for actor in world.residents:
		if actor.dead: continue
		var at: Vector2 = actor.position if actor.room_id == "" else world.home_data(actor.room_id).door
		entries.append({"at": project(at), "active": actor == world.active_resident, "playable": actor.can_control})
	if is_instance_valid(world.streamer.session.combat):
		for enemy in world.streamer.session.combat.enemies.values():
			if enemy.hp>0: entries.append({"at":project(enemy.position),"active":false,"playable":false,"enemy":true})
	markers.entries = entries
	markers.queue_redraw()
	visible = true

func _fill(image: Image, area: Rect2, color: Color) -> void:
	var scaled := Rect2i(Vector2i(project(area.position).floor()), Vector2i((area.size * SCALE).ceil()))
	image.fill_rect(scaled.intersection(Rect2i(0, 0, 432, 288)), color)

func _build() -> void:
	build_count += 1
	var image := Image.create(432, 288, false, Image.FORMAT_RGBA8)
	image.fill(Color("393e30"))
	_fill(image, Layout.BOUNDS,Color("caaa76"))
	_fill(image, Layout.FOREST,Color("54774d"))
	# The forest continues north of the original map; the schematic map must show woodland there too.
	_fill(image, Layout.FOREST_NORTH,Color("54774d"))
	# Schematic woodland uses seed-stable marks, without loading any distant trees.
	var rng := RandomNumberGenerator.new()
	rng.seed = world.resource_seed
	for i in range(210):
		_fill(image,Rect2(Vector2(rng.randf_range(-2350,-50),rng.randf_range(-1560,1560)),Vector2(20,26)),Color("3b6345"))
	_fill(image, Layout.MOUNTAINS_EAST, Color("4b5259"))
	_fill(image, Rect2(12, 0, 24, 600), Color("518d96"))
	_fill(image, Rect2(12, 600, 88, 1000), Color("518d96"))
	_fill(image, Geography.MOUNTAINS.grow(60), Color("837b67"))
	for y: float in Geography.BRIDGES: _fill(image, Rect2(8, y - 12, 98 if y > 600 else 34, 24), Color("8c633f"))
	for route: Array in Layout.ROADS:
		for i in range(route.size() - 1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i + 1]
			for step in range(ceili(a.distance_to(b) / 5) + 1):
				var point := a.move_toward(b, step * 5)
				_fill(image, Rect2(point - Vector2(6, 6), Vector2(12, 12)), Color("dec18b"))
	_fill(image, Land.LAKE, Color("518d96"))
	_fill(image, Geography.PLAZA, Color("e0c897"))
	_fill(image, Layout.FOREST_PLAZA, Color("c5bd8e"))
	for p: Dictionary in farming.plots: _fill(image, Land.bounds(p), Color("8c784c"))
	for home: Dictionary in world.homes:
		_fill(image, Rect2(home.at, home.region.size), Color("75533d"))
		_fill(image, Rect2(home.door - Vector2(5, 5), Vector2(10, 10)), Color("f4d594"))
	_fill(image, Rect2(384, 211, 96, 63), Color("9d835b"))
	_fill(image, Rect2(48, 406, 120, 80), Color("88754d"))
	_fill(image, Rect2(326, 180, 18, 23), Color("526f75"))
	_fill(image, Rect2(533, 297, 30, 22), Color("9f7658"))
	_fill(image, Rect2(501, 249, 94, 35), Color("b2915d"))
	_fill(image, Rect2(2045, 425, 50, 30), Color("45453c"))
	for fixture in grounds.fixtures: _fill(image, fixture.visual_bounds(), Color("72533b"))
	texture = ImageTexture.create_from_image(image)
	background.texture = texture
	captions.arrange(_building_names())

func _building_names() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for home: Dictionary in world.homes:
		var bounds := Rect2(project(home.at), home.region.size * SCALE)
		records.append({"id": home.id, "text": home.name, "at": bounds.get_center(), "bounds": bounds})
	var facilities := [
		{"id":"forest_altar", "text":"青木祭台", "area":Rect2(Layout.FOREST_ALTAR-Vector2(30,26),Vector2(60,26))},
		{"id": "well", "text": "水井", "area": Rect2(326, 180, 18, 23)},
		{"id": "pig_pen", "text": "猪圈", "area": Rect2(384, 211, 96, 63)},
		{"id": "cow_shed", "text": "牛棚", "area": Rect2(48, 406, 120, 80)},
		{"id": "altar", "text": "祭台", "area": Rect2(533, 297, 30, 22)},
		{"id": "altar_display", "text": "祭坛", "area": Rect2(501, 249, 94, 35)},
		{"id": "mine", "text": "矿洞", "area": Rect2(2045, 425, 50, 30)}]
	for facility: Dictionary in facilities:
		var bounds := Rect2(project(facility.area.position), facility.area.size * SCALE)
		records.append({"id": facility.id, "text": facility.text, "at": bounds.get_center(), "bounds": bounds})
	return records
