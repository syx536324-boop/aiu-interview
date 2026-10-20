# Draws a pixel-style apple sapling or fruiting tree; the orchard owns all timers and rewards.
extends Node2D
var record: Dictionary = {}
var body: StaticBody2D

func _draw() -> void:
	if float(record.get("growth",0)) > 0:
		draw_rect(Rect2(-1,-13,3,14),Color("8e6443"))
		draw_rect(Rect2(-9,-17,9,6),Color("578d44"))
		draw_rect(Rect2(1,-21,9,7),Color("78a752"))
		draw_rect(Rect2(-5,-4,12,3),Color("786046"))
		return
	draw_rect(Rect2(-12,-2,25,5),Color(0.14,0.18,0.10,0.25))
	draw_rect(Rect2(-5,-34,10,35),Color("65452d"))
	draw_rect(Rect2(-1,-29,4,29),Color("a87d4c"))
	draw_rect(Rect2(-12,-29,14,5),Color("795735"))
	for layer in range(3):
		var y: int = -25-layer*10
		var width: int = 24-layer*4
		var crown := PackedVector2Array([Vector2(-width,y+4),Vector2(-width,y-7),Vector2(-width+6,y-7),Vector2(-width+6,y-14),Vector2(-8,y-14),Vector2(-8,y-18),Vector2(10,y-18),Vector2(10,y-14),Vector2(width-3,y-14),Vector2(width-3,y-7),Vector2(width,y-7),Vector2(width,y+3),Vector2(12,y+3),Vector2(12,y+7),Vector2(-12,y+7),Vector2(-12,y+4)])
		draw_colored_polygon(crown,Color("3e7540").lightened(layer*0.09))
		for x in [-13,0,10]: draw_rect(Rect2(x,y-9,5,3),Color("8eaf59"))
	if int(record.get("fruit",0)) > 0:
		for at: Vector2 in [Vector2(-15,-30),Vector2(10,-41),Vector2(-4,-53)]:
			draw_rect(Rect2(at+Vector2(1,-2),Vector2(2,3)),Color("66502d"))
			draw_rect(Rect2(at,Vector2(6,5)),Color("c84639"))
			draw_rect(Rect2(at+Vector2(1,1),Vector2(2,2)),Color("f8b173"))
