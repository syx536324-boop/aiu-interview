# Draws distinguishable constructed houses, tower and rubble, including remaining health.
extends Node2D
var record: Dictionary
func _draw() -> void:
	var hp := float(record.hp)
	var kind := str(record.kind)
	var color := Color("ac7c48") if kind == "wood_house" else (Color("979786") if kind == "stone_house" else Color("71838e"))
	if hp <= 0:
		for i in range(7): draw_rect(Rect2(-36 + i * 10, -12 - (i % 3) * 5, 12, 9), color.darkened(0.2))
		return
	draw_rect(Rect2(-46, -73, 92, 74), Color("41382d"))
	draw_rect(Rect2(-42, -67, 84, 64), color)
	if kind == "arrow_tower":
		draw_rect(Rect2(-30, -64, 60, 62), Color("93734d"))
		for x in [-25, 20]: draw_rect(Rect2(x, -71, 5, 70), Color("523f2c"))
		draw_rect(Rect2(-44, -74, 88, 28), Color("b09b78"))
		for x in range(-44, 44, 13): draw_rect(Rect2(x, -79, 8, 10), Color("d0bb93"))
		for y in range(-43, 0, 8): draw_line(Vector2(-5, y), Vector2(5, y), Color("d5af76"), 2)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-48,-49), Vector2(0,-80), Vector2(48,-49)]), color.darkened(0.35))
		for y in range(-42, -3, 8): draw_line(Vector2(-40,y), Vector2(40,y), color.darkened(0.2), 1)
		for x in [-29, 20]:
			draw_rect(Rect2(x, -38, 12, 12), Color("323e3c"))
			draw_line(Vector2(x+6,-38),Vector2(x+6,-26),Color("d6c18f"),1)
		draw_rect(Rect2(-9, -24, 18, 25), Color("47372a"))
		draw_rect(Rect2(-6, -21, 12, 22), Color("936b43"))
		if kind == "iron_house":
			for x in [-39, 36]:
				for y in [-43, -22, -5]: draw_rect(Rect2(x,y,3,3),Color("d8dfd7"))
	draw_rect(Rect2(-36, -90, 72, 4), Color("392a23"))
	draw_rect(Rect2(-36, -90, 72 * hp / float(record.max_hp), 4), Color("a0bc76"))
	var job: Dictionary=record.get("job",{})
	if not job.is_empty():
		for x in [-40,40]: draw_line(Vector2(x,-75),Vector2(x,1),Color("d6ba88"),2)
		for y in [-60,-35,-10]: draw_line(Vector2(-44,y),Vector2(44,y),Color("d6ba88"),2)
		draw_rect(Rect2(-36,-84,72*(1.0-float(job.remaining)/float(job.duration)),3),Color("83cbd1"))
	draw_string(ThemeDB.fallback_font,Vector2(-14,-96),"Lv.%d" % int(record.get("level",1)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ead9af"))
