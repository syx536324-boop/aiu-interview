# Draws readable pixel icons for tools, food and gathered materials without modifying source assets.
extends Control

const Water := preload("res://features/inventory/water_catalog.gd")

var item := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_item(id: String) -> void:
	item = id
	queue_redraw()

func _draw() -> void:
	var wood := Color("bb8953")
	var edge := Color("49372b")
	var steel := Color("adc1bd")
	var art_item := item
	var armor_color := Color("a48c65")
	var armor_light := Color("d9bc80")
	var armor_dark := Color("70543c")
	if item.begins_with("leather_") or item.begins_with("iron_"):
		var part := item.get_slice("_",1)
		if part in ["armor","leggings","helmet","boots"]:
			art_item="hood" if part=="helmet" else part
			if item.begins_with("iron_"):
				armor_color=steel; armor_light=Color("e4e9da"); armor_dark=Color("617773")
			else:
				armor_color=Color("ac7548"); armor_light=Color("d2a16a"); armor_dark=Color("725038")
	if item=="iron_knife": art_item="knife"
	if item in ["beef","mutton"]: art_item="pork"
	if item in ["cooked_beef","cooked_mutton"]: art_item="cooked_pork"
	match art_item:
		"bed":
			draw_rect(Rect2(3,2,18,20),edge)
			draw_rect(Rect2(4,3,16,6),Color("ead7b3"))
			draw_rect(Rect2(4,10,16,10),Color("91778a"))
			draw_rect(Rect2(3,20,3,4),wood)
			draw_rect(Rect2(18,20,3,4),wood)
		"apple":
			draw_circle(Vector2(8,14),7,Color("b94e3e"))
			draw_circle(Vector2(15,14),7,Color("d36148"))
			draw_line(Vector2(12,9),Vector2(13,3),edge,2)
			draw_line(Vector2(14,5),Vector2(20,3),Color("7eac5a"),3)
			draw_rect(Rect2(5,11,3,4),Color("ecae78"))
		"carrot":
			draw_colored_polygon(PackedVector2Array([Vector2(7,7),Vector2(19,12),Vector2(4,23)]),Color("df883f"))
			for x in [10,15,20]: draw_line(Vector2(13,9),Vector2(x,2),Color("82a955"),2)
			draw_line(Vector2(8,13),Vector2(12,15),Color("b46b31"),2)
		"wool":
			for at in [Vector2(7,9),Vector2(15,8),Vector2(10,16),Vector2(18,16)]: draw_circle(at,6,Color("ece9d8"))
			draw_arc(Vector2(11,12),6,0,PI,8,Color("bfbba8"),1)
		"cabinet", "chest", "table", "chair":
			draw_rect(Rect2(3,5,18,15),edge)
			draw_rect(Rect2(4,6,16,12),wood)
			for x in [5,18]: draw_rect(Rect2(x,18,2,5),edge)
			if item in ["cabinet","chest"]: draw_line(Vector2(12,6),Vector2(12,18),edge,1)
			if item=="chair": draw_rect(Rect2(5,1,14,6),wood)
		"knife":
			draw_line(Vector2(4,22),Vector2(10,15),wood,4)
			draw_colored_polygon(PackedVector2Array([Vector2(9,15),Vector2(19,2),Vector2(22,7),Vector2(13,18)]),steel if item=="iron_knife" else Color("93988c"))
		"bowl":
			draw_colored_polygon(PackedVector2Array([Vector2(2,8),Vector2(23,8),Vector2(19,21),Vector2(7,21)]),wood)
			draw_line(Vector2(3,8),Vector2(22,8),edge,3)
			draw_line(Vector2(7,17),Vector2(18,17),Color("d8b37c"),2)
		"scissors":
			for x in [6,17]: draw_arc(Vector2(x,18),4,0,TAU,12,Color("bb7858"),2)
			draw_line(Vector2(7,15),Vector2(18,2),steel,2)
			draw_line(Vector2(16,15),Vector2(6,2),steel,2)
			draw_rect(Rect2(10,10,3,3),edge)
		"ginseng":
			draw_line(Vector2(12,6),Vector2(11,18),Color("dac298"),5)
			for x in [5,18]: draw_line(Vector2(11,14),Vector2(x,22),Color("dac298"),2)
			for x in [5,17]: draw_line(Vector2(12,7),Vector2(x,2),Color("719c52"),3)
		"reishi":
			draw_rect(Rect2(11,11,4,12),Color("d1b58b"))
			draw_rect(Rect2(3,6,20,8),Color("b65840"))
			draw_line(Vector2(5,7),Vector2(21,7),Color("e6b276"),2)
		"goji", "mulberry_leaf":
			draw_line(Vector2(5,22),Vector2(18,3),Color("718e4d"),2)
			for at in [Vector2(5,8),Vector2(13,13),Vector2(10,3)]: draw_rect(Rect2(at,Vector2(7,4)),Color("8fb65d"))
			if item == "goji":
				for at in [Vector2(5,11),Vector2(15,6),Vector2(10,17)]: draw_rect(Rect2(at,Vector2(3,5)),Color("dc6750"))
		"restorative_soup", "qi_soup":
			draw_rect(Rect2(3,9,19,5),Color("dfbc7c"))
			draw_colored_polygon(PackedVector2Array([Vector2(3,12),Vector2(22,12),Vector2(18,22),Vector2(7,22)]),Color("9b6a43"))
			draw_rect(Rect2(5,9,15,3),Color("bf8351") if item=="restorative_soup" else Color("8a9a50"))
			for x in [9,16]: draw_line(Vector2(x,6),Vector2(x-1,2),Color("e6d8ad"),1)
		"iron_bucket", "sand_bucket":
			draw_arc(Vector2(12,8),7,PI,TAU,12,steel,2)
			draw_colored_polygon(PackedVector2Array([Vector2(4,8),Vector2(21,8),Vector2(18,22),Vector2(7,22)]),steel.darkened(0.25))
			draw_rect(Rect2(6,9,13,4),Color("d7ba76") if item=="sand_bucket" else edge)
			draw_line(Vector2(8,13),Vector2(9,20),steel,2)
		"leather":
			draw_colored_polygon(PackedVector2Array([Vector2(4,3),Vector2(10,6),Vector2(20,2),Vector2(23,8),Vector2(19,14),Vector2(22,22),Vector2(13,20),Vector2(4,23),Vector2(2,16),Vector2(6,10)]),Color("a57349"))
			draw_line(Vector2(7,9),Vector2(16,17),Color("d2a56e"),2)
		"crude_iron":
			draw_rect(Rect2(3,9,19,11),edge)
			draw_rect(Rect2(5,7,15,10),steel.darkened(0.3))
			draw_line(Vector2(5,7),Vector2(19,7),steel,2)
		"wood_sword", "stone_sword", "iron_sword":
			var blade := wood if item=="wood_sword" else (Color("96998b") if item=="stone_sword" else steel)
			draw_line(Vector2(5,21),Vector2(20,4),edge,5)
			draw_line(Vector2(9,16),Vector2(20,4),blade,3)
			draw_line(Vector2(5,12),Vector2(13,19),Color("b48d52"),3)
		"arrow":
			for shift in [0,6]:
				draw_line(Vector2(4+shift,22),Vector2(15+shift,3),wood,2)
				draw_colored_polygon(PackedVector2Array([Vector2(13+shift,7),Vector2(15+shift,2),Vector2(18+shift,7)]),steel)
		"bow":
			draw_arc(Vector2(8,12),10,-PI/2,PI/2,12,wood,3)
			draw_line(Vector2(8,2),Vector2(8,22),Color("e7d8af"),1)
			draw_line(Vector2(3,12),Vector2(23,12),steel,1)
		"building_bench":
			draw_rect(Rect2(2,6,21,13),wood)
			draw_rect(Rect2(5,8,15,8),Color("d8c594"))
			for x in [4,19]: draw_rect(Rect2(x,19,3,4),edge)
		"armor":
			draw_colored_polygon(PackedVector2Array([Vector2(7, 3), Vector2(3, 7), Vector2(5, 12), Vector2(7, 11), Vector2(7, 21), Vector2(18, 21), Vector2(18, 11), Vector2(20, 12), Vector2(22, 7), Vector2(17, 3)]), edge)
			draw_rect(Rect2(8, 6, 9, 14), armor_color)
			draw_rect(Rect2(10, 3, 5, 4), Color("65513c"))
			draw_line(Vector2(12, 8), Vector2(12, 19), armor_light, 2)
		"leggings":
			draw_rect(Rect2(5, 3, 15, 8), edge)
			for x in [5, 14]:
				draw_rect(Rect2(x, 8, 6, 14), edge)
				draw_rect(Rect2(x + 1, 9, 4, 11), armor_color)
			draw_rect(Rect2(6, 4, 13, 4), armor_light)
		"hood":
			draw_circle(Vector2(12, 11), 9, edge)
			draw_circle(Vector2(12, 10), 7, armor_color)
			draw_rect(Rect2(6, 10, 12, 11), edge)
			draw_rect(Rect2(8, 9, 8, 9), armor_dark)
			draw_line(Vector2(6, 20), Vector2(18, 20), armor_color, 2)
		"boots":
			for x in [2, 13]:
				draw_rect(Rect2(x + 2, 3, 6, 17), edge)
				draw_rect(Rect2(x, 16, 9, 6), edge)
				draw_rect(Rect2(x + 3, 5, 4, 13), armor_color)
				draw_rect(Rect2(x + 1, 17, 7, 3), armor_light)
		"stone", "iron_ore":
			draw_colored_polygon(PackedVector2Array([Vector2(3, 20), Vector2(2, 11), Vector2(8, 4), Vector2(16, 3), Vector2(22, 13), Vector2(20, 21)]), Color("53564d"))
			draw_colored_polygon(PackedVector2Array([Vector2(4, 11), Vector2(9, 6), Vector2(15, 5), Vector2(19, 12), Vector2(11, 15)]), Color("aaac95"))
			if item == "iron_ore":
				for p in [Vector2(7, 10), Vector2(14, 14), Vector2(5, 17)]: draw_rect(Rect2(p, Vector2(5, 3)), Color("c48659"))
		"bucket", "water_bucket", "water_bucket_3", "water_bucket_2", "water_bucket_1":
			draw_arc(Vector2(12, 8), 7, PI, TAU, 10, edge, 2)
			draw_rect(Rect2(4, 7, 16, 15), edge)
			draw_rect(Rect2(6, 9, 12, 11), wood)
			draw_line(Vector2(7, 14), Vector2(17, 14), Color("69665b"), 2)
			draw_rect(Rect2(6, 8, 12, 4), Color("665039"))
			var level := Water.units(item)
			if level > 0: draw_rect(Rect2(6, 12 - level, 12, level), Color("73b2b8"))
			for i in range(4):
				draw_rect(Rect2(6 + i * 3, 19, 2, 2), Color("9acece") if i < level else Color("665039"))
		"wooden_cup", "water_cup":
			draw_rect(Rect2(4, 6, 13, 16), edge)
			draw_rect(Rect2(6, 8, 9, 12), wood)
			draw_rect(Rect2(16, 9, 6, 10), edge)
			draw_rect(Rect2(17, 11, 3, 6), wood)
			draw_rect(Rect2(6, 7, 9, 4), Color("73b2b8") if item == "water_cup" else Color("665039"))
			draw_line(Vector2(9, 13), Vector2(9, 19), Color("8b603d"), 1)
		"workbench":
			draw_rect(Rect2(3, 6, 18, 8), edge)
			draw_rect(Rect2(4, 7, 16, 5), wood)
			draw_rect(Rect2(5, 14, 3, 8), wood)
			draw_rect(Rect2(16, 14, 3, 8), wood)
			draw_line(Vector2(9, 8), Vector2(14, 12), steel, 2)
		"fence":
			for x in [4, 17]: draw_rect(Rect2(x, 3, 3, 19), wood)
			for y in [7, 15]: draw_rect(Rect2(2, y, 20, 3), wood)
		"seeds", "rice_seeds":
			draw_rect(Rect2(6, 6, 13, 16), Color("ad9764"))
			draw_rect(Rect2(6, 6, 13, 3), Color("698d69") if item == "rice_seeds" else Color("c4a653"))
			for p in [Vector2(9, 11), Vector2(15, 13), Vector2(10, 18)]:
				draw_rect(Rect2(p, Vector2(2, 3) if item == "rice_seeds" else Vector2(3, 2)), Color("e8e2be") if item == "rice_seeds" else Color("e9bf5c"))
		"wheat", "rice":
			for x in [7, 12, 17]:
				draw_line(Vector2(x, 22), Vector2(x, 5), Color("a8904b"), 1)
				for y in [7, 11, 15]:
					var shift := 2 if item == "rice" else 0
					draw_rect(Rect2(x - 3 + shift, y, 3, 2), Color("e6d390") if item == "rice" else Color("dbb44f"))
					draw_rect(Rect2(x + 1 + shift, y - 1, 3, 2), Color("e6d390") if item == "rice" else Color("dbb44f"))
		"cooked_pork":
			draw_circle(Vector2(12, 13), 9, Color("80502c"))
			draw_circle(Vector2(12, 12), 7, Color("b87e43"))
			for x in [8, 12, 16]: draw_line(Vector2(x, 8), Vector2(x - 2, 16), Color("694328"), 2)
		"wood":
			draw_colored_polygon(PackedVector2Array([Vector2(3, 12), Vector2(12, 4), Vector2(21, 6), Vector2(22, 14), Vector2(12, 22), Vector2(4, 20)]), edge)
			draw_colored_polygon(PackedVector2Array([Vector2(5, 12), Vector2(13, 6), Vector2(20, 8), Vector2(20, 13), Vector2(11, 20), Vector2(5, 19)]), wood)
			draw_line(Vector2(9, 13), Vector2(17, 7), Color("dec08a"), 2)
			draw_rect(Rect2(4, 13, 8, 7), Color("e2bd7e"))
			draw_rect(Rect2(6, 15, 4, 3), Color("a87946"))
		"pickaxe":
			draw_line(Vector2(6, 20), Vector2(15, 4), edge, 5)
			draw_line(Vector2(6, 19), Vector2(14, 5), wood, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(2, 11), Vector2(5, 3), Vector2(16, 2), Vector2(23, 9), Vector2(15, 6), Vector2(7, 6)]), edge)
			draw_line(Vector2(5, 5), Vector2(16, 4), steel, 3)
			draw_line(Vector2(5, 5), Vector2(3, 9), steel, 2)
		"hoe":
			draw_line(Vector2(16, 21), Vector2(11, 3), edge, 5)
			draw_line(Vector2(16, 20), Vector2(11, 4), wood, 3)
			draw_rect(Rect2(3, 4, 11, 10), edge)
			draw_rect(Rect2(4, 5, 8, 8), steel)
			draw_rect(Rect2(4, 11, 8, 2), Color("dce3cc"))
		"stone_axe", "iron_axe":
			draw_line(Vector2(5, 21), Vector2(16, 3), edge, 5)
			draw_line(Vector2(5, 20), Vector2(16, 4), wood, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(13, 4), Vector2(21, 2), Vector2(23, 10), Vector2(20, 14), Vector2(12, 9)]), edge)
			draw_colored_polygon(PackedVector2Array([Vector2(14, 5), Vector2(20, 4), Vector2(21, 10), Vector2(19, 12), Vector2(14, 8)]), (Color("91aba5") if item=="iron_axe" else Color("959382")))
			draw_line(Vector2(21, 4), Vector2(22, 10), Color("d3dac3"), 2)
		"watering_can":
			draw_rect(Rect2(5, 3, 11, 10), edge)
			draw_rect(Rect2(7, 5, 7, 6), Color("8bafad"))
			draw_colored_polygon(PackedVector2Array([Vector2(15, 15), Vector2(21, 6), Vector2(23, 7), Vector2(20, 18)]), Color("90b2a5"))
			draw_rect(Rect2(3, 10, 15, 12), edge)
			draw_rect(Rect2(4, 10, 12, 10), Color("739f99"))
			draw_rect(Rect2(6, 12, 3, 7), Color("acc9ae"))
		"bread":
			draw_rect(Rect2(3, 8, 19, 13), edge)
			draw_rect(Rect2(5, 4, 15, 16), Color("b77d3f"))
			draw_rect(Rect2(4, 8, 17, 11), Color("dca962"))
			for x in [7, 12, 17]:
				draw_line(Vector2(x, 6), Vector2(x - 2, 10), Color("f3d39a"), 2)
		"book":
			draw_rect(Rect2(4, 3, 16, 20), edge)
			draw_rect(Rect2(6, 5, 14, 17), Color("e1cba1"))
			draw_rect(Rect2(4, 2, 15, 17), Color("7d9272"))
			draw_rect(Rect2(5, 3, 2, 15), Color("b2bf89"))
			draw_rect(Rect2(10, 7, 6, 2), Color("dfcf9c"))
		"pork":
			draw_colored_polygon(PackedVector2Array([Vector2(2, 10), Vector2(6, 5), Vector2(16, 6), Vector2(22, 12), Vector2(19, 20), Vector2(8, 22), Vector2(3, 17)]), Color("703f38"))
			draw_rect(Rect2(5, 10, 14, 9), Color("d08472"))
			draw_rect(Rect2(8, 7, 8, 4), Color("df9d89"))
			draw_rect(Rect2(12, 11, 5, 5), Color("edd8b1"))
			draw_rect(Rect2(13, 12, 3, 3), Color("b87965"))
