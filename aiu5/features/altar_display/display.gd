# Adds a 21-slot altar display table whose visible icons mirror persistent inventory storage.
extends Node

const Icon := preload("res://features/interface/item_icon.gd")
const STORAGE_ID := "altar:display"
var inventory: Node
var table: Node2D
var icons: Array[Control] = []

class Table extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-47, -31, 94, 35), Color("604b35"))
		draw_rect(Rect2(-45, -30, 90, 30), Color("d0ae76"))
		draw_rect(Rect2(-45, 0, 90, 4), Color("8f704a"))
		for y in range(3):
			for x in range(7): draw_rect(Rect2(-42 + x * 12, -28 + y * 9, 11, 8), Color("b99862"))
		for x in [-42, 38]: draw_rect(Rect2(x, 4, 4, 5), Color("8f704a"))

func start(world: Node2D, items: Node) -> void:
	inventory = items
	table = Table.new()
	table.name = "AltarDisplay"
	table.position = Vector2(548, 280)
	world.objects.add_child(table)
	world._body(table, Vector2(0, -14), Vector2(94, 28))
	# The northern approach keeps the existing save point and the side pillars unobstructed.
	world.points.altar_display = {"position": Vector2(548, 244), "radius": 18.0, "label": "祭坛", "action": "存取物品 / 献祭复活"}
	world._label("祭坛", Vector2(536, 246))
	world.refresh_obstacles()
	for i in range(21):
		var icon := Icon.new()
		icon.position = Vector2(-42 + (i % 7) * 12, -28 + floori(i / 7.0) * 9)
		icon.scale = Vector2(0.36, 0.32)
		icon.size = Vector2(24, 24)
		table.add_child(icon)
		icons.append(icon)
	inventory.changed.connect(refresh)
	refresh()

func refresh() -> void:
	var slots: Array = inventory.ensure_container(STORAGE_ID)
	for i in range(21):
		var item := str(slots[i].get("item", ""))
		if icons[i].item != item: icons[i].set_item(item)
