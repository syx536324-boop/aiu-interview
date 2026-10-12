# Renders primitive wooden furniture with plank joints, wooden pegs and distinct shapes.
extends Node2D

const NAMES := {"building_bench":"建筑台", "workbench": "工作台", "fence": "围栏", "stove": "灶台", "bed": "木床", "table": "木桌", "chair": "木椅", "cabinet": "木柜", "chest": "木箱"}
var gift_origin: Dictionary = {}
var public_fixture := false
var kind := "table"
var fixture_id := ""
var orientation := 0
var base_size := Vector2(32, 24)
var preview := false
var preview_valid := true
var variant := 0
var size := Vector2(32, 24)
var wood := Color("bb8953")
var edge := Color("62452f")
var light := Color("dbb27a")
var grain := Color("996b41")

func configure(data: Array) -> void:
	kind = data[0]
	size = data[2]
	base_size = size
	variant = data[3]
	position = data[1] + Vector2(size.x / 2, size.y - 1)
	wood = [Color("bb8953"), Color("ad7d4e"), Color("c3975f")][variant % 3]
	light = wood.lightened(0.20)
	grain = wood.darkened(0.17)

func configure_record(record: Dictionary) -> void:
	configure([record["kind"], Vector2(record["at"][0], record["at"][1]), Vector2(record["size"][0], record["size"][1]), int(record.get("variant", 0))])
	gift_origin = record.get("gift_origin", {}).duplicate(true)
	public_fixture = bool(record.get("public_fixture",false))
	fixture_id = record["id"]
	orientation = int(record.get("orientation", 0)) % 4
	set_placement(Vector2(record["at"][0], record["at"][1]), orientation)

func set_placement(top_left: Vector2, direction: int) -> void:
	orientation = posmod(direction, 4)
	size = base_size if orientation % 2 == 0 else Vector2(base_size.y, base_size.x)
	position = top_left + Vector2(size.x / 2, size.y - 1)
	queue_redraw()

func visual_bounds() -> Rect2:
	return Rect2(position - Vector2(size.x / 2, size.y - 1), size)

func record() -> Dictionary:
	var at := visual_bounds().position
	return {"public_fixture":public_fixture,"gift_origin":gift_origin.duplicate(true), "id": fixture_id, "kind": kind, "at": [at.x, at.y], "size": [base_size.x, base_size.y], "variant": variant, "orientation": orientation}

func is_storage() -> bool:
	return kind == "cabinet" or kind == "chest"

func collision_bounds() -> Rect2:
	return Rect2(position + Vector2(-size.x / 2 + 2, -size.y + 5), Vector2(size.x - 4, maxf(4, size.y - 6)))

func _board(rect: Rect2, horizontal := true) -> void:
	draw_rect(rect, edge)
	draw_rect(rect.grow(-1), wood)
	draw_line(rect.position + Vector2(1, 1), rect.position + Vector2(rect.size.x - 2, 1), light, 1)
	if horizontal:
		for y in range(int(rect.position.y + 5), int(rect.end.y - 1), 5):
			draw_line(Vector2(rect.position.x + 1, y), Vector2(rect.end.x - 2, y), grain, 1)
	else:
		for x in range(int(rect.position.x + 5), int(rect.end.x - 1), 6):
			draw_line(Vector2(x, rect.position.y + 2), Vector2(x, rect.end.y - 2), grain, 1)
	draw_line(rect.position + Vector2(4, 3), rect.position + Vector2(minf(10, rect.size.x - 3), 3), grain, 1)

func _leg(at: Vector2, height: float) -> void:
	draw_rect(Rect2(at, Vector2(3, height)), edge)
	draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, height - 1)), grain)

func _draw() -> void:
	var x := -size.x / 2
	var y := -size.y
	if preview:
		draw_rect(Rect2(x - 1, y - 1, size.x + 2, size.y + 2), Color(0.25, 0.8, 0.4, 0.35) if preview_valid else Color(0.95, 0.25, 0.2, 0.45))
	draw_rect(Rect2(x, -3, size.x, 4), Color(0.18, 0.11, 0.07, 0.25))
	match kind:
		"building_bench":
			draw_rect(Rect2(x,y,size.x,size.y),Color("a78b62"),false,1)
			for corner in [Vector2(x,y),Vector2(-x-5,y),Vector2(x,-5),Vector2(-x-5,-5)]: _board(Rect2(corner,Vector2(5,5)))
			_board(Rect2(-18,-21,36,18))
			_leg(Vector2(-16,-5),5)
			_leg(Vector2(13,-5),5)
			draw_rect(Rect2(-12,-19,23,12),Color("d8c594"))
			draw_line(Vector2(-7,-14),Vector2(5,-14),edge,1)
		"workbench":
			_leg(Vector2(x + 3, y + 8), size.y - 8)
			_leg(Vector2(-x - 6, y + 8), size.y - 8)
			_board(Rect2(x, y, size.x, size.y - 7))
			draw_line(Vector2(x + 8, y + 5), Vector2(x + 15, y + 12), edge, 3)
			draw_rect(Rect2(x + 5, y + 3, 9, 4), Color("a6aaa0"))
			_board(Rect2(x + size.x - 12, y - 2, 8, 6))
		"fence":
			if orientation % 2 == 0:
				_board(Rect2(x, y + 3, size.x, 4))
				for offset in [1, int(size.x - 5)]: _board(Rect2(x + offset, y - 3, 4, size.y + 3), false)
			else:
				_board(Rect2(-2, y, 4, size.y), false)
				for offset in [0, int(size.y - 6)]: _board(Rect2(x, y + offset, size.x, 5))
		"stove":
			draw_rect(Rect2(x, y, size.x, size.y), Color("665248"))
			draw_rect(Rect2(x + 2, y + 2, size.x - 4, size.y - 4), Color("a28462"))
			for row in range(int(y + 5), -2, 7): draw_line(Vector2(x + 2, row), Vector2(-x - 3, row), Color("76624b"), 1)
			draw_rect(Rect2(x + 7, -12, size.x - 14, 10), Color("352d26"))
			draw_rect(Rect2(x + 12, -9, size.x - 24, 5), Color("c57538"))
			draw_circle(Vector2(0, y + 5), 10, Color("302f2a"))
			draw_circle(Vector2(0, y + 5), 7, Color("53574b"))
			draw_rect(Rect2(8, y + 3, 11, 3), Color("292b26"))
		"table", "chair":
			_leg(Vector2(x + 3, y + 6), size.y - 6)
			_leg(Vector2(x + size.x - 6, y + 6), size.y - 6)
			var top_height := size.y - 6 if kind == "table" else size.y - 4
			_board(Rect2(x, y, size.x, top_height), variant != 1)
			if kind == "table" and variant == 2:
				for offset in [7, int(size.x - 9)]:
					draw_rect(Rect2(x + offset, y + 2, 2, top_height - 4), grain)
			if kind == "chair":
				match orientation:
					0: _board(Rect2(x, y - 4, size.x, 7))
					1: _board(Rect2(-x - 4, y - 2, 4, size.y - 3), false)
					2: _board(Rect2(x, -7, size.x, 6))
					3: _board(Rect2(x, y - 2, 4, size.y - 3), false)
		"bed":
			_board(Rect2(x, y, size.x, size.y - 2), false)
			draw_rect(Rect2(x + 3, y + 4, size.x - 6, size.y - 10), Color("cdb279"))
			for row in range(int(y + 6), -7, 3):
				draw_line(Vector2(x + 4, row), Vector2(-x - 5, row), Color("b2965e"), 1)
			match orientation:
				0: _board(Rect2(x - 1, y - 2, size.x + 2, 6))
				1: _board(Rect2(-x - 5, y - 1, 6, size.y), false)
				2: _board(Rect2(x - 1, -6, size.x + 2, 6))
				3: _board(Rect2(x - 1, y - 1, 6, size.y), false)
			_leg(Vector2(x + 2, -4), 4)
			_leg(Vector2(-x - 5, -4), 4)
		"cabinet":
			_board(Rect2(x, y, size.x, size.y - 2), false)
			if variant == 1:
				for offset in [2, int(size.x / 2 + 1)]:
					_board(Rect2(x + offset, y + 6, size.x / 2 - 3, size.y - 11), false)
					draw_rect(Rect2(x + offset + size.x / 4, y + size.y / 2, 2, 2), edge)
			else:
				for offset in range(6, int(size.y - 4), 7):
					_board(Rect2(x + 2, y + offset, size.x - 4, 6))
					draw_rect(Rect2(-1, y + offset + 2, 3, 2), edge)
		"chest":
			_board(Rect2(x, y + 3, size.x, size.y - 4))
			_board(Rect2(x + 1, y, size.x - 2, 8), false)
			for offset in [5, int(size.x - 8)]:
				draw_rect(Rect2(x + offset, y, 3, size.y - 2), grain)
				draw_rect(Rect2(x + offset + 1, y + 2, 1, 2), light)
			draw_rect(Rect2(-2, y + 8, 4, 3), edge)
	if preview:
		draw_rect(Rect2(x - 1, y - 1, size.x + 2, size.y + 2), Color("91df98") if preview_valid else Color("f07865"), false, 1)

func display_name() -> String:
	return ("魔法·" if gift_origin.get("is_magical", false) else "") + str(NAMES.get(kind, "木家具"))
