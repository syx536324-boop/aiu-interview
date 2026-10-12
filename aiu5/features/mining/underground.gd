# Provides a walkable underground room through the existing interior/camera/exit contract.
extends "res://features/interiors/room.gd"

const Ore := preload("res://features/mining/ore.gd")
var mining: Node

func _ready() -> void:
	super._ready()
	for record: Dictionary in mining.UNDERGROUND:
		var ore: Node2D = mining.create_ore(record)
		objects.add_child(ore)
	camera.position = size / 2

func _process(_delta: float) -> void:
	for actor in objects.get_children():
		if actor is CharacterBody2D and actor.controlled:
			camera.position = actor.position
			return

func nearby(local_position: Vector2) -> Dictionary:
	if local_position.distance_to(exit_point()) < 23:
		return {"id": "exit", "label": "返回地表的阶梯", "action": "离开矿洞", "description": ""}
	var nearest: Dictionary = {}
	var gap := 26.0
	for ore in objects.get_children():
		if not ore is Ore or not ore.visible: continue
		var distance := local_position.distance_to(ore.position)
		if distance < gap:
			gap = distance
			nearest = {"id": "ore", "ore": ore, "label": "铁矿脉" if ore.kind == "iron_ore" else "石矿", "action": "镐子采集 %d/%d" % [ore.hits, ore.strikes], "description": "采尽获得" + ("铁矿×2" if ore.kind == "iron_ore" else "石头×3")}
	return nearest

func _draw() -> void:
	draw_rect(Rect2(-5, -5, size.x + 10, size.y + 10), Color("171916"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("4a4b40"))
	draw_rect(Rect2(10, 28, size.x - 20, size.y - 36), Color("66634f"))
	for y in range(30, int(size.y - 10), 8):
		for x in range(12, int(size.x - 12), 8):
			var shade := Color("75715a") if (x * 7 + y * 3) % 19 < 8 else Color("595a49")
			draw_rect(Rect2(x, y, 3, 2), shade)
	for x in range(12, int(size.x - 20), 29):
		draw_rect(Rect2(x, 6, 25, 16), Color("686a5d"))
		draw_line(Vector2(x + 2, 7), Vector2(x + 20, 7), Color("8a8874"), 2)
	for x in [17, int(size.x - 23)]:
		draw_rect(Rect2(x, 23, 6, 18), Color("795536"))
		draw_rect(Rect2(x - 3, 20, 12, 4), Color("b1834b"))
		draw_rect(Rect2(x + 1, 25, 4, 5), Color("edb468"))
	for y in range(int(size.y - 32), int(size.y - 6), 5):
		draw_rect(Rect2(size.x / 2 - 14, y, 28, 3), Color("b2a17b"))
	draw_colored_polygon(PackedVector2Array([Vector2(size.x / 2 - 3, size.y - 14), Vector2(size.x / 2 + 3, size.y - 14), Vector2(size.x / 2, size.y - 9)]), Color("f3dfac"))
