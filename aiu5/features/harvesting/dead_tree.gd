# Draws a leafless desert tree with a trunk collider, chop marks and an axe impact animation.
extends Node2D

var resource_id := ""
var hits := 0
var variant := 0
var body: StaticBody2D
var hit_time := 0.0
var axe_origin := Vector2.ZERO
var axe_side := 1.0

func _ready() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1 if hits < 4 else 0
	body.collision_mask = 2 | 4
	body.position = Vector2(0, -4.5)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 9)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	visible = hits < 4

func apply_hit(progress: int, actor_position: Vector2) -> void:
	hits = progress
	hit_time = 0.35
	axe_origin = actor_position - global_position + Vector2(0, -9)
	axe_side = 1.0 if axe_origin.x <= 0 else -1.0
	if hits >= 4:
		body.collision_layer = 0
	queue_redraw()

func _process(delta: float) -> void:
	if hit_time > 0:
		hit_time = maxf(0, hit_time - delta)
		visible = hits < 4 or hit_time > 0
		queue_redraw()

func _branch(points: PackedVector2Array, width: float) -> void:
	draw_polyline(points, Color("513c2c"), width + 2)
	draw_polyline(points, Color("97704a"), width)

func _draw() -> void:
	if hits < 4:
		var shake := roundf(sin(hit_time * 60) * 1.5) if hit_time > 0 else 0.0
		draw_ellipse_shadow()
		draw_set_transform(Vector2(shake, 0))
		var lift := variant * 3
		_branch(PackedVector2Array([Vector2(-5, -1), Vector2(-2, -14), Vector2(0, -28), Vector2(3, -44 - lift)]), 6)
		_branch(PackedVector2Array([Vector2(-1, -21), Vector2(-13, -29), Vector2(-20, -39 - lift)]), 4)
		_branch(PackedVector2Array([Vector2(-11, -28), Vector2(-18, -27), Vector2(-24, -32)]), 2)
		_branch(PackedVector2Array([Vector2(0, -16), Vector2(12, -26), Vector2(15, -39)]), 4)
		_branch(PackedVector2Array([Vector2(12, -26), Vector2(21, -25), Vector2(26, -31 - lift)]), 2)
		_branch(PackedVector2Array([Vector2(2, -35), Vector2(-4, -41), Vector2(-5, -48 - lift)]), 2)
		draw_line(Vector2(-4, -5), Vector2(-1, -22), Color("bd9563"), 2)
		for i in range(hits):
			draw_line(Vector2(-5, -8 - i * 3), Vector2(2, -6 - i * 3), Color("e1b776"), 2)
		draw_set_transform(Vector2.ZERO)
	if hit_time > 0:
		var phase := 1.0 - hit_time / 0.35
		for i in range(6):
			var chip := Vector2((i - 2.5) * phase * 9, -10 - sin(phase * PI) * (8 + i % 3 * 4) + phase * 8)
			draw_rect(Rect2(chip.round(), Vector2(3, 2)), Color("e5bf82"))
		draw_set_transform(axe_origin, axe_side * lerpf(-0.95, 0.7, phase))
		draw_line(Vector2(0, 5), Vector2(0, -12), Color("49372b"), 4)
		draw_line(Vector2(0, 4), Vector2(0, -11), Color("bb8953"), 2)
		draw_colored_polygon(PackedVector2Array([Vector2(-2, -12), Vector2(7, -15), Vector2(9, -8), Vector2(6, -5), Vector2(-2, -8)]), Color("40524a"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(6, -13), Vector2(7, -8), Vector2(5, -7), Vector2(0, -9)]), Color("b2c4b5"))
		draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 12, Color(0.25, 0.19, 0.12, 0.2))
	draw_set_transform(Vector2.ZERO)
