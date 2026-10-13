# Draws four distinct glyphs with the user's exact elemental rune colors.
extends RefCounted
const COLORS := {"wood":"8ebc75","water":"72b8ce","fire":"dc9566","earth":"c6ad70"}
static func color(element: String) -> Color:
	return Color(str(COLORS.get(element,"a6d4c7")))
static func draw(canvas: CanvasItem, element: String, center: Vector2, scale := 1.0) -> void:
	var c := color(element)
	match element:
		"wood":
			canvas.draw_line(center+Vector2(0,5)*scale,center+Vector2(0,-5)*scale,c,maxf(1,scale))
			for side in [-1,1]:
				canvas.draw_line(center+Vector2(0,-1)*scale,center+Vector2(side*4,-4)*scale,c,maxf(1,scale))
				canvas.draw_line(center+Vector2(0,2)*scale,center+Vector2(side*4,-1)*scale,c,maxf(1,scale))
		"water":
			for y in [-2,2]:
				canvas.draw_polyline(PackedVector2Array([center+Vector2(-5,y)*scale,center+Vector2(-2,y-2)*scale,center+Vector2(2,y+1)*scale,center+Vector2(5,y-1)*scale]),c,maxf(1,scale))
		"fire":
			canvas.draw_polyline(PackedVector2Array([center+Vector2(-4,4)*scale,center+Vector2(-2,-1)*scale,center+Vector2(0,1)*scale,center+Vector2(2,-5)*scale,center+Vector2(5,4)*scale,center+Vector2(-4,4)*scale]),c,maxf(1,scale))
		"earth":
			canvas.draw_rect(Rect2(center-Vector2(4,4)*scale,Vector2(8,8)*scale),c,false,maxf(1,scale))
			canvas.draw_line(center+Vector2(-3,0)*scale,center+Vector2(3,0)*scale,c,maxf(1,scale))
			canvas.draw_line(center+Vector2(0,-3)*scale,center+Vector2(0,3)*scale,c,maxf(1,scale))
