# Provides a walkable underground room through the existing interior/camera/exit contract.
extends "res://features/interiors/room.gd"

const Ore := preload("res://features/mining/ore.gd")
var mining: Node

func _ready() -> void:
	super._ready()
	for record: Dictionary in mining.underground_records:
		var ore: Node2D = mining.create_ore(record)
		objects.add_child(ore)
	camera.position = size / 2
	rebuild_navigation()

func _process(_delta: float) -> void:
	for actor in objects.get_children():
		if actor is CharacterBody2D and actor.controlled:
			if camera.position.distance_to(actor.position)>0.1:
				camera.position = actor.position
				queue_redraw()
			return

func nearby(local_position: Vector2) -> Dictionary:
	if local_position.distance_to(exit_point()) < 23:
		return {"id": "exit", "label": "返回地表的阶梯", "action": "离开矿洞", "description": ""}
	var fixture := super.nearby(local_position)
	if fixture.get("id","")=="campfire": return fixture
	var nearest: Dictionary = {}
	var gap := 26.0
	for ore in objects.get_children():
		if not ore is Ore or not ore.visible: continue
		var distance := local_position.distance_to(ore.position)
		if distance < gap:
			gap = distance
			nearest = {"id": "ore", "ore": ore, "label": str(mining.inventory.Catalog.ITEMS[ore.kind].name)+"脉", "action": "镐子采集 %d/%d" % [ore.hits, ore.strikes], "description": "采尽获得" + str(mining.inventory.Catalog.ITEMS[ore.kind].name)+("×2" if ore.kind=="iron_ore" else "×3")}
	return nearest

func rebuild_navigation() -> void:
	super.rebuild_navigation()
	if not is_instance_valid(objects): return
	for ore in objects.get_children():
		if ore is Ore and ore.hits<ore.strikes: collision_rects.append(Rect2(ore.position+Vector2(-10,-10),Vector2(20,10)))
	navigation.rebuild(collision_rects,size)
func _draw() -> void:
	draw_rect(Rect2(-5, -5, size.x + 10, size.y + 10), Color("171916"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("4a4b40"))
	draw_rect(Rect2(10, 28, size.x - 20, size.y - 36), Color("66634f"))
	var region := Rect2(camera.position-Vector2(192,132),Vector2(384,264)) if is_instance_valid(camera) else Rect2(Vector2.ZERO,Vector2(384,264))
	for y in range(maxi(30,floori(region.position.y/8)*8), mini(int(size.y-10),ceili(region.end.y/8)*8),8):
		for x in range(maxi(12,floori(region.position.x/8)*8), mini(int(size.x-12),ceili(region.end.x/8)*8),8):
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
