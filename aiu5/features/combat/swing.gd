# Displays a short melee arc without owning damage or input rules.
extends Node2D
const Rune := preload("res://features/magic/rune_art.gd")
var weapon := ""
var record: Dictionary={}
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
	if weapon=="magic_scissors":
		var at := direction*24
		var c := Rune.color(str(record.get("magic_attribute","")))
		for x in [-4,4]: draw_arc(at+Vector2(x,3),3,0,TAU,12,c,2)
		draw_line(at+Vector2(-4,0),at+Vector2(5,-9),Color("e4e2cd"),2)
		draw_line(at+Vector2(4,0),at+Vector2(-5,-9),Color("e4e2cd"),2)
		draw_arc(Vector2.ZERO,35,direction.angle()-0.7,direction.angle()+0.7,10,Color(c,0.6),2)
		return
	draw_arc(Vector2.ZERO,20,direction.angle()-0.7,direction.angle()+0.7,10,Color("eee2b6"),2)
