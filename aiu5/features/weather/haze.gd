# Shrouds the highlands until they are reached, then hazes the outer band of the view and shortens ranged reach.
extends Node2D

const Layout := preload("res://features/village/layout.gd")
# The hazy outer band covers the last thirty percent of the view, which is why ranged reach shrinks.
const BAND := 0.3
const RANGE_SCALE := 0.7
const PRE_VISIT_ALPHA := 0.9
# Opacities are ordered from the outermost band towards the clear center.
const RING_ALPHAS := [0.9, 0.7, 0.4]
const HAZE_COLOUR := Color(0.66, 0.70, 0.74)
var world: Node2D
var visited := false

func start(village: Node2D) -> void:
	world = village
	z_index = 90

func on_highland() -> bool:
	if not is_instance_valid(world) or not is_instance_valid(world.active_resident): return false
	var at: Vector2 = world.active_resident.position
	return Layout.PLATEAU.has_point(at) or Layout.MOUNTAINS_EAST.has_point(at)

func range_scale() -> float:
	return RANGE_SCALE if on_highland() else 1.0

func _process(_delta: float) -> void:
	if on_highland(): visited = true
	queue_redraw()

func _draw() -> void:
	if on_highland(): _draw_ring()
	elif not visited: _draw_regions()

func _draw_regions() -> void:
	# Both highlands stay hidden behind drifting haze until the player actually gets up there.
	for area: Rect2 in [Layout.PLATEAU, Layout.MOUNTAINS_EAST]:
		draw_rect(area, Color(HAZE_COLOUR.r, HAZE_COLOUR.g, HAZE_COLOUR.b, PRE_VISIT_ALPHA))
		for i in range(28):
			var x: float = area.position.x + float(posmod(i * 868211, int(area.size.x)))
			var y: float = area.position.y + float(posmod(i * 15485863, int(area.size.y)))
			draw_rect(Rect2(x, y, 190, 64), Color(0.74, 0.78, 0.82, 0.16))
			draw_rect(Rect2(x + 60, y + 70, 150, 46), Color(0.58, 0.62, 0.66, 0.12))

func _draw_ring() -> void:
	var camera: Camera2D = world.camera
	if not is_instance_valid(camera): return
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / maxf(0.01, camera.zoom.x)
	var view := Rect2(camera.get_screen_center_position() - half, half * 2.0)
	var band := half * BAND
	# Four filled strips per band keep corner opacity exact and give equal relative x/y coverage.
	for step in range(RING_ALPHAS.size()):
		var inset: Vector2 = band * (float(step) / 3.0)
		var inner_inset: Vector2 = band * (float(step + 1) / 3.0)
		var outer := Rect2(view.position + inset, view.size - inset * 2.0)
		var inner := Rect2(view.position + inner_inset, view.size - inner_inset * 2.0)
		var tint := Color(HAZE_COLOUR.r, HAZE_COLOUR.g, HAZE_COLOUR.b, float(RING_ALPHAS[step]))
		draw_rect(Rect2(outer.position, Vector2(outer.size.x, inner.position.y - outer.position.y)), tint)
		draw_rect(Rect2(Vector2(outer.position.x, inner.end.y), Vector2(outer.size.x, outer.end.y - inner.end.y)), tint)
		draw_rect(Rect2(Vector2(outer.position.x, inner.position.y), Vector2(inner.position.x - outer.position.x, inner.size.y)), tint)
		draw_rect(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(outer.end.x - inner.end.x, inner.size.y)), tint)
