# Draws a finite mineable rock, with distinct iron seams and strike feedback.
extends Node2D

var resource_id := ""
var kind := "stone"
var hits := 0
var strikes := 3
var body: StaticBody2D
var flash := 0.0

func _ready() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2 | 4
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 10)
	collision.shape = shape
	collision.position = Vector2.ZERO
	body.position = Vector2(0, -5)
	body.add_child(collision)
	add_child(body)
	refresh()

func refresh() -> void:
	visible = hits < strikes
	if is_instance_valid(body): body.collision_layer = 1 if visible else 0
	queue_redraw()

func _process(delta: float) -> void:
	if flash > 0:
		flash = maxf(0, flash - delta)
		queue_redraw()

func _draw() -> void:
	draw_ellipse_shadow()
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -1), Vector2(-11, -12), Vector2(-4, -20), Vector2(7, -18), Vector2(13, -9), Vector2(11, 0)]), Color("524d47"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -10), Vector2(-4, -18), Vector2(6, -16), Vector2(10, -8), Vector2(2, -5)]), Color("b7b7a2") if flash > 0 else Color("979785"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -10), Vector2(2, -5), Vector2(10, -8), Vector2(9, -2), Vector2(-10, -3)]), Color("74776d"))
	if kind == "iron_ore":
		for p in [Vector2(-5, -14), Vector2(4, -11), Vector2(-2, -5)]:
			draw_rect(Rect2(p, Vector2(5, 3)), Color("bc7752"))
			draw_rect(Rect2(p + Vector2(1, 0), Vector2(2, 1)), Color("e6a473"))
	if kind=="coal":
		for at in [Vector2(-5,-14),Vector2(4,-11),Vector2(-2,-5)]: draw_rect(Rect2(at,Vector2(6,4)),Color("292f31"))
	if hits > 0:
		draw_line(Vector2(-3, -17), Vector2(0, -9), Color("49483f"), 1)
		draw_line(Vector2(0, -9), Vector2(-5, -4), Color("49483f"), 1)
		draw_rect(Rect2(-9, 3, 18, 2), Color("493f32"))
		draw_rect(Rect2(-9, 3, 18 * float(hits) / strikes, 2), Color("d3bd7c"))

func draw_ellipse_shadow() -> void:
	draw_rect(Rect2(-13, 0, 26, 3), Color(0.12, 0.1, 0.08, 0.24))
