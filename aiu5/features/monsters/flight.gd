# Draws a wood thorn while the monster runtime owns swept impacts and saved flight state.
extends Node2D
var direction:=Vector2.RIGHT
func _draw() -> void:
	draw_line(-direction*6,direction*4,Color("a6bb6b"),2)
	draw_colored_polygon(PackedVector2Array([direction*6,direction.rotated(2.4)*3,direction.rotated(-2.4)*3]),Color("e2d7a3"))
