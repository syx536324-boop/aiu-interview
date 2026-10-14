# Adds western river/bridges, eastern mountains, extended trails and a protected altar plaza.
extends Node

const LandscapeView := preload("res://features/landscape/view.gd")
const Layout := preload("res://features/landscape/layout.gd")
const BRIDGES := Layout.BRIDGES
const MOUNTAINS := Layout.MOUNTAINS
const PLAZA := Layout.PLAZA
var world: Node2D
var view: Node2D

func start(village: Node2D) -> void:
	world = village
	view = LandscapeView.new()
	world.add_child(view)
	world.move_child(view, 2)
	for span in [Vector2(8, 300), Vector2(320, 540), Vector2(560, 600), Vector2(600, 890), Vector2(910, 1290), Vector2(1310, 1592)]:
		var width := 24.0 if span.x < 600 else 88.0
		world._body(view, Vector2(12 + width / 2, (span.x + span.y) / 2), Vector2(width, span.y - span.x))
	world._body(view, MOUNTAINS.get_center(), MOUNTAINS.size)
	for y in [100, 700, 1050, 1400]: world._body(view, Vector2(2110, y), Vector2(80, 100))
	for x in [490, 606]: world._body(view, Vector2(x, 285), Vector2(12, 18))
	world.points.river = {"position": Vector2(46, 310), "radius": 22.0, "label": "西侧河流", "action": "装满桶与杯"}
	world._label("西河", Vector2(110, 920))
	world._label("东侧高山", Vector2(2160, 380))
	world._label("南部荒野", Vector2(1060, 1160))
	var frontier := preload("res://features/landscape/frontier.gd").new()
	world.add_child(frontier); frontier.start(world)
	world.refresh_obstacles()

func water_target(at: Vector2) -> void:
	var edge := 36.0 if at.y < 600 else 100.0
	world.points.river.position = Vector2(2 if at.x < 12 else edge + 10, clampf(at.y, 20, 1580))

static func protected(bounds: Rect2) -> bool:
	if preload("res://features/landscape/frontier.gd").protected(bounds): return true
	if bounds.intersects(Rect2(8, 0, 32, 600)) or bounds.intersects(Rect2(8, 600, 96, 1000)): return true
	if bounds.intersects(preload("res://features/village/layout.gd").FOREST_PLAZA): return true
	if bounds.intersects(MOUNTAINS.grow(4)) or bounds.intersects(PLAZA): return true
	for y: float in BRIDGES:
		if bounds.intersects(Rect2(8, y - 15, 104 if y > 600 else 40, 30)): return true
	return false
