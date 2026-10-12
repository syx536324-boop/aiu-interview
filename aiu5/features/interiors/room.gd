# Builds one walkable room, its straw mats, wooden fixtures, walls and exit point.
extends Node2D

const Furniture := preload("res://features/interiors/furniture.gd")
const Navigation := preload("res://features/village/navigation.gd")
const Catalog := preload("res://features/interiors/furniture_catalog.gd")
var room_id := ""
var room_name := ""
var definition: Dictionary
var size := Vector2(208, 144)
var objects: Node2D
var camera: Camera2D
var fixtures: Array[Node2D] = []
var collision_rects: Array[Rect2] = []
var wall_rects: Array[Rect2] = []
var saved_layout: Array = []
var next_id := 0
var navigation := Navigation.new()
var assembling := true

func configure(home: Dictionary, layout: Dictionary, saved: Array = [{"missing": true}]) -> void:
	room_id = home["id"]
	room_name = home["name"]
	definition = layout.duplicate(true)
	saved_layout = saved
	size = definition["size"]

func _ready() -> void:
	objects = Node2D.new()
	objects.name = "RoomObjects"
	objects.y_sort_enabled = true
	add_child(objects)
	_wall(Rect2(0, 0, size.x, 28))
	_wall(Rect2(0, 0, 10, size.y))
	_wall(Rect2(size.x - 10, 0, 10, size.y))
	_wall(Rect2(0, size.y - 8, size.x, 8))
	if _valid_saved_layout(saved_layout):
		for record: Dictionary in saved_layout:
			add_fixture(record)
	else:
		for data: Array in definition["furniture"]:
			add_fixture({"id": allocate_id(), "kind": data[0], "at": [data[1].x, data[1].y], "size": [data[2].x, data[2].y], "variant": data[3], "orientation": 0})
	assembling = false
	rebuild_navigation()
	camera = Camera2D.new()
	camera.name = "RoomCamera"
	camera.position = size / 2 + Vector2(0, -3)
	camera.zoom = Vector2(2, 2)
	camera.enabled = false
	add_child(camera)

func _valid_saved_layout(records: Array) -> bool:
	# A saved empty room is valid; an absent save is represented by a sentinel record.
	var ids: Dictionary = {}
	for data: Variant in records:
		if not data is Dictionary or not Catalog.TYPES.has(data.get("kind", "")):
			return false
		var id := str(data.get("id", ""))
		if not id.begins_with(room_id + ":") or ids.has(id):
			return false
		for key in ["at", "size"]:
			if not data.get(key) is Array or data[key].size() != 2:
				return false
			for value: Variant in data[key]:
				if not (value is int or value is float) or not is_finite(float(value)):
					return false
		if float(data["size"][0]) < 8 or float(data["size"][1]) < 8 or float(data["size"][0]) > 120 or float(data["size"][1]) > 120:
			return false
		ids[id] = true
	return true

func allocate_id() -> String:
	var id := room_id + ":f" + str(next_id)
	next_id += 1
	while fixtures.any(func(fixture: Node2D) -> bool: return fixture.fixture_id == id):
		id = room_id + ":f" + str(next_id)
		next_id += 1
	return id

func add_fixture(record: Dictionary) -> Node2D:
	var fixture := Furniture.new()
	fixture.configure_record(record)
	objects.add_child(fixture)
	fixtures.append(fixture)
	_refresh_collider(fixture)
	return fixture

func _refresh_collider(fixture: Node2D) -> void:
	var old := fixture.get_node_or_null("FurnitureBody")
	if old != null:
		fixture.remove_child(old)
		old.queue_free()
	var bounds: Rect2 = fixture.collision_bounds()
	var body := _collision(bounds.position + bounds.size / 2 - fixture.position, bounds.size)
	body.name = "FurnitureBody"
	fixture.add_child(body)
	if not assembling: rebuild_navigation()

func rebuild_navigation() -> void:
	collision_rects = wall_rects.duplicate()
	for fixture in fixtures:
		collision_rects.append(fixture.collision_bounds())
	navigation.rebuild(collision_rects, size)

func relocate(fixture: Node2D, at: Vector2, direction: int) -> void:
	fixture.set_placement(at, direction)
	_refresh_collider(fixture)

func remove_fixture(fixture: Node2D) -> void:
	fixtures.erase(fixture)
	objects.remove_child(fixture)
	fixture.queue_free()
	rebuild_navigation()

func export_layout() -> Array:
	var result: Array = []
	for fixture in fixtures:
		result.append(fixture.record())
	return result

func furniture_at(point: Vector2) -> Node2D:
	var ordered := fixtures.duplicate()
	ordered.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.y > b.position.y)
	for fixture: Node2D in ordered:
		if fixture.visual_bounds().has_point(point):
			return fixture
	return null

func placement_error(ghost: Node2D, original: Node2D = null) -> String:
	var bounds: Rect2 = ghost.visual_bounds()
	if not Rect2(12, 30, size.x - 24, size.y - 40).encloses(bounds):
		return "家具需要放在屋内地板上。"
	if bounds.intersects(Rect2(size.x / 2 - 20, size.y - 44, 40, 36)):
		return "请为门口留出通道。"
	var obstacles: Array[Rect2] = wall_rects.duplicate()
	for fixture in fixtures:
		if fixture == original:
			continue
		if bounds.grow(1).intersects(fixture.visual_bounds()):
			return "这里已有家具。"
		obstacles.append(fixture.collision_bounds())
	obstacles.append(ghost.collision_bounds())
	var routes := Navigation.new()
	routes.rebuild(obstacles, size)
	for actor in objects.get_children():
		if actor is CharacterBody2D:
			if ghost.collision_bounds().grow(5).has_point(actor.position + Vector2(0, -3)):
				return "这里有村民，请换一个位置。"
			var path := routes.find_path(exit_point(), actor.position)
			if path.is_empty() or path[path.size() - 1].distance_to(actor.position) > 12:
				return "请保留村民通往门口的通路。"
	return ""

func _collision(at: Vector2, dimensions: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	return body

func _wall(bounds: Rect2) -> void:
	add_child(_collision(bounds.position + bounds.size / 2, bounds.size))
	wall_rects.append(bounds)
	collision_rects.append(bounds)

func exit_point() -> Vector2:
	return Vector2(size.x / 2, size.y - 16)

func safe_spawn() -> Vector2:
	var initial := Vector2(size.x / 2, size.y - 32)
	for offset in [Vector2.ZERO, Vector2(-12, -2), Vector2(12, -2), Vector2(-24, -2), Vector2(24, -2), Vector2(0, -16)]:
		var point: Vector2 = initial + offset
		var free := true
		for child in objects.get_children():
			if child is CharacterBody2D and child.position.distance_to(point) < 9:
				free = false
		for bounds in collision_rects:
			if bounds.grow(4).has_point(point + Vector2(0, -3)):
				free = false
		if free:
			return point
	return initial

func nearby(local_position: Vector2) -> Dictionary:
	if local_position.distance_to(exit_point()) < 24:
		return {"id": "exit", "label": "门口", "action": "出门", "description": ""}
	var nearest: Dictionary = {}
	var distance := INF
	for fixture in fixtures:
		var bounds: Rect2 = fixture.collision_bounds()
		var edge := Vector2(clampf(local_position.x, bounds.position.x, bounds.end.x), clampf(local_position.y - 3, bounds.position.y, bounds.end.y))
		var candidate := (local_position + Vector2(0, -3)).distance_to(edge)
		if candidate < 22 and candidate < distance:
			distance = candidate
			nearest = {"id": "storage" if fixture.is_storage() else "furniture", "fixture": fixture, "label": fixture.display_name(), "action": "打开 · 21 格" if fixture.is_storage() else "查看", "description": "用木板、木杆与木榫做成的" + fixture.display_name() + "，表面留着手工修整的纹路。"}
	if not nearest.is_empty() and nearest.has("fixture") and nearest.fixture.kind == "stove":
		nearest.id = "stove"
		nearest.action = "煎肉 / 领取"
	if not nearest.is_empty() and nearest.has("fixture") and nearest.fixture.kind == "workbench":
		nearest.id = "workbench"
		nearest.action = "分类合成"
		nearest.description = "E打开分类界面 → 选择物品 → 确认合成；制作需60秒"
	for mat: Rect2 in definition["mats"]:
		if mat.grow(5).has_point(local_position) and nearest.is_empty():
			nearest = {"id": "mat", "label": "草席", "action": "查看", "description": "干草与苇叶编成的草席，铺在木地板上供村民歇息。"}
	return nearest

func _draw() -> void:
	var floor_color: Color = definition["floor"]
	draw_rect(Rect2(-4, -4, size.x + 8, size.y + 10), Color("241c15"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("60432e"))
	draw_rect(Rect2(10, 24, size.x - 20, size.y - 32), floor_color)
	for row in range(26, int(size.y - 8), 9):
		draw_line(Vector2(10, row), Vector2(size.x - 11, row), floor_color.darkened(0.18), 1)
		draw_line(Vector2(10, row + 1), Vector2(size.x - 11, row + 1), floor_color.lightened(0.09), 1)
		for column in range(24 + (row % 2) * 20, int(size.x - 14), 40):
			draw_line(Vector2(column, row + 2), Vector2(column, minf(size.y - 10, row + 8)), floor_color.darkened(0.19), 1)
			draw_line(Vector2(column + 7, row + 5), Vector2(minf(size.x - 12, column + 16), row + 5), floor_color.darkened(0.08), 1)
	draw_rect(Rect2(2, 2, size.x - 4, 21), Color("805b3c"))
	for y in [7, 15, 21]:
		draw_line(Vector2(4, y), Vector2(size.x - 5, y), Color("62442e"), 1)
	for x in range(14, int(size.x - 10), 54):
		draw_rect(Rect2(x, 1, 6, 26), Color("513b2a"))
		draw_rect(Rect2(x + 1, 1, 2, 25), Color("ad8051"))
	for x in [2, int(size.x - 8)]:
		draw_rect(Rect2(x, 22, 6, size.y - 25), Color("6d4d33"))
		draw_rect(Rect2(x + 1, 23, 1, size.y - 27), Color("b28a59"))
	for i in range(definition["mats"].size()):
		_draw_mat(definition["mats"][i], i + int(size.x) % 3)
	var door_x := size.x / 2 - 15
	draw_rect(Rect2(door_x, size.y - 17, 30, 13), Color("684b32"))
	for x in range(int(door_x + 2), int(door_x + 29), 6):
		draw_line(Vector2(x, size.y - 16), Vector2(x, size.y - 5), Color("b99463"), 1)
	draw_rect(Rect2(door_x - 3, size.y - 18, 3, 16), Color("493525"))
	draw_rect(Rect2(door_x + 30, size.y - 18, 3, 16), Color("493525"))
	draw_colored_polygon(PackedVector2Array([Vector2(size.x / 2 - 3, size.y - 12), Vector2(size.x / 2 + 3, size.y - 12), Vector2(size.x / 2, size.y - 8)]), Color("efdbac"))

func _draw_mat(bounds: Rect2, pattern: int) -> void:
	draw_rect(bounds.grow(1), Color("725938"))
	draw_rect(bounds, Color("d0b77b"))
	for y in range(int(bounds.position.y + 2), int(bounds.end.y - 1), 3):
		draw_line(Vector2(bounds.position.x + 1, y), Vector2(bounds.end.x - 2, y), Color("b1955c"), 1)
	for x in range(int(bounds.position.x + 2), int(bounds.end.x - 1), 4):
		for y in range(int(bounds.position.y + 2), int(bounds.end.y - 2), 6):
			draw_rect(Rect2(x, y + (x + pattern * 2) % 3, 1, 2), Color("e2ca8d"))
	for x in range(int(bounds.position.x + 1), int(bounds.end.x), 3):
		draw_line(Vector2(x, bounds.end.y), Vector2(x, bounds.end.y + 2 + pattern % 2), Color("c7ae73"), 1)
