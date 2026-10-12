# Renders forty small durability cells in the equipped weapon frame.
extends Control
var value := 40
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	for i in range(40):
		draw_rect(Rect2(i,0,0.75,3), Color("87b774") if i<value else Color("635142"))
