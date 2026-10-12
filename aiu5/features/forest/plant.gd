# Draws forest trees and gatherable herbs; all progress belongs to the forest domain.
extends Node2D
var forest: Node
var record: Dictionary
var body: StaticBody2D
var available := true
func configure(owner_module: Node, data: Dictionary) -> void:
	forest = owner_module
	record = data
	position = data.at
	set_meta("procedural_resource", true)
func _ready() -> void:
	if record.kind in ["tree", "mulberry"]:
		body = forest.session.world._body(self, Vector2(0, -4), Vector2(10, 8))
	queue_redraw()
func _draw() -> void:
	var kind: String = record.kind
	if kind=="grass":
		for x in [-7,-3,2,6]: draw_line(Vector2(x,1),Vector2(x-2,-8-abs(x)/2),Color("638e48"),2)
		if available:
			for x in [-4,2,5]: draw_rect(Rect2(x,-5,3,2),Color("dac18b"))
		return
	if kind in ["tree", "mulberry"]:
		draw_rect(Rect2(-5, -30, 10, 31), Color("5b4434"))
		draw_rect(Rect2(-2, -27, 4, 27), Color("997052"))
		var green := Color("397449") if kind == "mulberry" else Color("2c5d43")
		for layer in range(3):
			var y := -18 - layer * 11
			var width := 23 - layer * 3
			draw_colored_polygon(PackedVector2Array([Vector2(-width, y), Vector2(-width + 4, y - 12), Vector2(-7, y - 17), Vector2(8, y - 18), Vector2(width - 3, y - 11), Vector2(width, y), Vector2(10, y + 5), Vector2(-12, y + 5)]), green.lightened(layer * 0.065))
			for x in [-12, 2, 12]: draw_rect(Rect2(x, y - 10, 4, 2), Color("66935a"))
		if kind == "mulberry" and available:
			for at in [Vector2(-12,-22),Vector2(10,-30),Vector2(-5,-40)]: draw_rect(Rect2(at,Vector2(4,3)),Color("b6cb6e"))
		return
	if not available:
		draw_rect(Rect2(-3,-2,6,2),Color("655440"))
		return
	if kind == "reishi":
		draw_rect(Rect2(-8,-7,16,8),Color("66503a"))
		for offset in [-5,3]:
			draw_rect(Rect2(offset,-12,3,8),Color("d2b28c"))
			draw_rect(Rect2(offset-4,-14,11,4),Color("c16b48"))
			draw_line(Vector2(offset-3,-14),Vector2(offset+5,-14),Color("e0ae66"),1)
	else:
		for x in [-6,0,6]:
			draw_line(Vector2(0,0),Vector2(x,-11-abs(x)/2),Color("567f40"),2)
			draw_rect(Rect2(x-3,-12-abs(x)/2,6,4),Color("8da85c"))
		if kind == "goji":
			for at in [Vector2(-5,-8),Vector2(3,-12),Vector2(0,-5)]: draw_rect(Rect2(at,Vector2(3,3)),Color("db6650"))
		else:
			draw_rect(Rect2(-2,-17,4,3),Color("d8b780"))
