# Draws ten discrete HUD cells for a 0–10 resident status without theme-driven sizing.
extends Control

var tint := Color("b6a274")
var maximum := 10.0
var value := 10.0:
	set(next):
		var normalized := clampf(next, 0, maximum)
		if value != normalized:
			value = normalized
			queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var cells := int(maximum)
	var width := size.x / cells
	for i in range(cells):
		var cell := Rect2(i * width, 0, width - 1, size.y)
		draw_rect(cell, Color("51483a"))
		if value > i:
			var filled := cell
			filled.size.x *= minf(1, value - i)
			draw_rect(filled, tint)
