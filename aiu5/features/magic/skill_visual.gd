# Draws native pixel-style campfires, temporary earth houses and elemental target effects.
extends Node2D
var kind := ""
var active := false
var actor_id := ""
var runtime: Node
func _draw() -> void:
	match kind:
		"campfire":
			_draw_hearth()
			draw_line(Vector2(-6,-2),Vector2(6,2),Color("886147"),3)
			draw_line(Vector2(-6,2),Vector2(6,-2),Color("886147"),3)
			if active:
				draw_colored_polygon(PackedVector2Array([Vector2(-5,-3),Vector2(-2,-10),Vector2(0,-7),Vector2(3,-15),Vector2(6,-3)]),Color("ed893e"))
				draw_colored_polygon(PackedVector2Array([Vector2(-2,-3),Vector2(1,-10),Vector2(3,-3)]),Color("f5d777"))
		"hut":
			draw_rect(Rect2(-16,-26,32,26),Color("b88f63"))
			draw_rect(Rect2(-16,-26,32,26),Color("5e4b35"),false,1)
			draw_colored_polygon(PackedVector2Array([Vector2(-19,-26),Vector2(0,-38),Vector2(19,-26)]),Color("8c714b"))
			draw_rect(Rect2(-4,-13,8,13),Color("4a3c2e"))
			draw_rect(Rect2(7,-20,6,6),Color("685838"))
		"fireball":
			draw_circle(Vector2.ZERO,5,Color("ea7042"))
			draw_circle(Vector2.ZERO,3,Color("f7da86"))
		"wood", "water", "fire":
			var color := Color("86ba62") if kind=="wood" else (Color("72c4e4") if kind=="water" else Color("ed854d"))
			draw_arc(Vector2(0,-8),10,0,TAU,20,color,2)
			if kind=="wood":
				for x in [-7,0,7]: draw_line(Vector2(x,0),Vector2(x,-18),color,1)
func _draw_hearth() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.5))
	draw_circle(Vector2.ZERO,9,Color("665c4e"))
	draw_set_transform(Vector2.ZERO)
