# Draws a spinning magical scissors projectile and its colored outgoing/returning trail.
extends Node2D
var record: Dictionary={}
var spin := 0.0
func _process(delta: float) -> void:
	spin+=delta*9; queue_redraw()
func _draw() -> void:
	var c := Color(str({"wood":"8ebc75","water":"72b8ce","fire":"dc9566","earth":"c6ad70"}.get(str(record.get("magic_attribute","")),"a6d4c7")))
	draw_line(Vector2(-17,0),Vector2(-5,0),Color(c,0.45),3)
	draw_arc(Vector2.ZERO,10,0,TAU,20,Color(c,0.5),1)
	draw_set_transform(Vector2.ZERO,spin)
	for x in [-4,4]: draw_arc(Vector2(x,3),3,0,TAU,12,c,2)
	draw_line(Vector2(-4,0),Vector2(5,-9),Color("e4e2cd"),2)
	draw_line(Vector2(4,0),Vector2(-5,-9),Color("e4e2cd"),2)
	draw_set_transform(Vector2.ZERO)
