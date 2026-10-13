# Shrouds the highlands until they are reached, then hazes the outer band of the view and shortens ranged reach.
extends Node2D

const Layout := preload("res://features/village/layout.gd")
# The hazy outer band covers the last thirty percent of the view, which is why ranged reach shrinks.
const BAND := 0.3
const RANGE_SCALE := 0.7
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
		draw_rect(area, Color(HAZE_COLOUR.r, HAZE_COLOUR.g, HAZE_COLOUR.b, 0.52))
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
	for step in range(3):
		var inset: Vector2 = band * (float(step) / 3.0)
		var frame := Rect2(view.position + inset, view.size - inset * 2.0)
		draw_rect(frame, Color(HAZE_COLOUR.r, HAZE_COLOUR.g, HAZE_COLOUR.b, 0.12 + 0.12 * float(step)), false, band.x / 3.0)
