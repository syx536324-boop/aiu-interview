# Displays a short melee arc without owning damage or input rules.
extends Node2D
var direction := Vector2.RIGHT
var remaining := 0.16
func _ready() -> void:
	set_meta("procedural_resource",true)
	queue_redraw()
func _process(delta: float) -> void:
	remaining -= delta
	modulate.a = clampf(remaining/0.16,0,1)
	if remaining <= 0: queue_free()
func _draw() -> void:
	draw_arc(Vector2.ZERO,20,direction.angle()-0.7,direction.angle()+0.7,10,Color("eee2b6"),2)
