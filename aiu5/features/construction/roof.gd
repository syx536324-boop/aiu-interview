# Places a walkable tower roof in world space so its camera can see and attack the surrounding desert.
extends "res://features/interiors/room.gd"
func nearby(local_position: Vector2) -> Dictionary:
	var result := super.nearby(local_position)
	if result.get("id","")=="exit":
		result.label="箭楼阶梯"
		result.action="下楼"
	return result
func _draw() -> void:
	draw_rect(Rect2(0,0,size.x,size.y),Color("68553c"))
	draw_rect(Rect2(7,7,size.x-14,size.y-14),Color("b29a72"))
	for y in range(8, int(size.y)-8, 8): draw_line(Vector2(7,y), Vector2(size.x-7,y), Color("947951"), 1)
	for x in range(0,int(size.x),14):
		draw_rect(Rect2(x,0,8,9),Color("ddc49a"))
		draw_rect(Rect2(x,size.y-7,8,7),Color("ddc49a"))
	draw_rect(Rect2(size.x/2-10,size.y-24,20,17),Color("473b2a"))
	for y in range(int(size.y)-23,int(size.y)-6,5): draw_line(Vector2(size.x/2-6,y), Vector2(size.x/2+6,y),Color("c8a77a"),2)
