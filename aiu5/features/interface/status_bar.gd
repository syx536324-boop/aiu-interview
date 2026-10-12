# Draws up to ten proportional HUD segments for resident stats with variable limits.
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
	var cells := mini(10, maxi(1, ceili(maximum)))
	var filled_cells := clampf(value / maxf(1, maximum), 0, 1) * cells
	var width := size.x / cells
	for i in range(cells):
		var cell := Rect2(i * width, 0, width - 1, size.y)
		draw_rect(cell, Color("51483a"))
		if filled_cells > i:
			var filled := cell
			filled.size.x *= minf(1, filled_cells - i)
			draw_rect(filled, tint)
