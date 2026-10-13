# Draws native pixel-style branch structures, auras and targeting effects.
extends Node2D
const Rune := preload("res://features/magic/rune_art.gd")
var kind := ""
var record: Dictionary={}
var runtime: Node
const COLORS := {"wood":"8cba69","water":"77c4da","fire":"e99853","earth":"c7af7b"}
func _draw() -> void:
	var c := Rune.color(str(record.get("element","earth")))
	match kind:
		"cast","enchant_rune":
			var element := str(record.get("element","earth"))
			var color := Rune.color(element)
			for radius in range(12,16+int(record.get("rank",1))*3,4): draw_arc(Vector2.ZERO,radius,0,TAU,24,Color(color,0.5),1)
			Rune.draw(self,element,Vector2.ZERO,1.5)
			if record.get("branch","")=="build": draw_rect(Rect2(-14,-14,28,28),Color(color,0.6),false,1)
			if record.get("branch","")=="guard": draw_arc(Vector2.ZERO,22,PI,TAU,16,color,2)
		"facility":
			draw_arc(Vector2.ZERO,80,0,TAU,48,Color(c,0.2),1)
			draw_circle(Vector2.ZERO,12,Color(c,0.25))
			match str(record.element):
				"wood":
					draw_rect(Rect2(-3,-25,6,25),Color("866347"))
					for at in [Vector2(-8,-26),Vector2(6,-29),Vector2(0,-38)]: draw_rect(Rect2(at-Vector2(9,6),Vector2(18,12)),c)
					draw_rect(Rect2(-1,-34,3,4),Color("ecedb4"))
				"water":
					draw_rect(Rect2(-13,-6,26,12),Color("817969"))
					draw_rect(Rect2(-10,-5,20,8),c)
					draw_line(Vector2(-4,-4),Vector2(2,-19),c.lightened(0.3),3)
					draw_line(Vector2(2,-19),Vector2(8,-5),c,2)
				"fire":
					draw_rect(Rect2(-12,-11,24,15),Color("826c53"))
					draw_rect(Rect2(-8,-6,16,9),Color("453c30"))
					draw_colored_polygon(PackedVector2Array([Vector2(-6,2),Vector2(-4,-10),Vector2(0,-5),Vector2(4,-17),Vector2(8,2)]),c)
				"earth":
					draw_rect(Rect2(-13,-7,26,10),Color("77684e"))
					draw_colored_polygon(PackedVector2Array([Vector2(-7,-7),Vector2(-4,-20),Vector2(3,-25),Vector2(9,-8)]),c)
					draw_line(Vector2(0,-20),Vector2(0,-10),Color("f2dc9c"),2)
		"bush":
			for x in [-10,-5,0,5,10]:
				draw_line(Vector2(x,3),Vector2(x-3,-14-abs(x)/2),Color("699c59"),3)
			draw_arc(Vector2(0,-5),14,0,TAU,16,Color("c2cd78"),1)
			var offset := -8
			for herb: String in record.get("ready",{}):
				draw_rect(Rect2(offset,-20,4,4),Color("d5a1c4") if herb=="reishi" else Color("f0d281")); offset+=8
		"orb": draw_circle(Vector2.ZERO,5,Color("ec965b")); draw_rect(Rect2(-2,-2,4,4),Color("f5dea3"))
		"mark":
			if record.get("passive",false):
				Rune.draw(self,str(record.element),Vector2(0,3),0.65)
				return
			draw_arc(Vector2.ZERO,11,0,TAU,20,c,1)
			if record.has("enchantment"): Rune.draw(self,str(record.element),Vector2(0,13),0.8)
			if record.get("stone",false): draw_rect(Rect2(-7,-9,14,18),Color(0.7,0.68,0.57,0.65))
			if float(record.get("shield",0))>0: draw_arc(Vector2.ZERO,14,0,TAU,24,Color("aadbed"),2)
		"survey": draw_rect(Rect2(-9,-14,18,18),Color("e7d27e"),false,2); draw_line(Vector2(0,-23),Vector2(0,-17),Color("e7d27e"),2)
		"pit","canal","array","wall","firewall","wind":
			var extent := Vector2(record.size[0],record.size[1])
			draw_set_transform(Vector2.ZERO,float(record.get("angle",0)))
			var area := Rect2(-extent/2,extent)
			var fill := Color("58684d") if kind=="canal" else (Color("846f51") if kind in ["array","wall"] else Color("a05032"))
			draw_rect(area,Color(fill,0.7 if kind!="wind" else 0.35))
			draw_rect(area,Color("82c6d2") if kind=="canal" else fill.lightened(0.3),false,1)
			if kind=="canal":
				for x in range(-25,30,10): draw_line(Vector2(x,-2),Vector2(x+5,2),Color("87cbd7"),2)
			elif kind=="wall":
				for x in range(-55,60,15): draw_line(Vector2(x,-13),Vector2(x,13),Color("c1b28b"),1)
			elif kind=="array":
				for x in [-16,0,16]:
					for y in [-16,0,16]: draw_rect(Rect2(x-3,y-4,6,8),Color("ceb987"))
				draw_rect(Rect2(-20,-30,40*maxf(0,float(record.hp))/200,3),Color("a6be78"))
			else:
				for x in range(int(-extent.x/2)+5,int(extent.x/2),12): draw_colored_polygon(PackedVector2Array([Vector2(x,4),Vector2(x+3,-8),Vector2(x+7,4)]),Color("eea14f"))
			Rune.draw(self,str(record.get("element","earth")),Vector2.ZERO,1.0)
			draw_set_transform(Vector2.ZERO)
