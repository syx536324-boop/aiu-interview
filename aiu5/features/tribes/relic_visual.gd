# Renders a floating elemental sacred crystal, construction runes and its 200-point health bar.
extends Node2D
var runtime: Node
var tribe := "home"
var body: StaticBody2D
var elapsed := 0.0
func _ready() -> void:
 body=StaticBody2D.new(); body.collision_layer=16; body.collision_mask=2|8
 var shape := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size=Vector2(14,18); shape.shape=rect
 body.add_child(shape); add_child(body); body.add_to_group("relic_targets"); body.set_meta("tribe",tribe)
func _process(delta: float) -> void: elapsed+=delta; queue_redraw()
func _draw() -> void:
 var r: Dictionary=runtime.relics.states[tribe]
 var element: String=runtime.elements.get(tribe,"earth")
 var c: Color=preload("res://features/magic/rune_art.gd").color(element)
 var y := -6.0+sin(elapsed*2)*2
 draw_ellipse_shadow()
 if float(r.hp)>0 or float(r.remaining)>0:
  var points := PackedVector2Array([Vector2(0,y-18),Vector2(9,y-5),Vector2(0,y+8),Vector2(-9,y-5)])
  draw_colored_polygon(points,c.darkened(0.15)); draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),c.lightened(0.5),1)
  draw_line(Vector2(0,y-18),Vector2(0,y+8),c.lightened(0.4),1)
  draw_colored_polygon(PackedVector2Array([points[0],points[3],Vector2(0,y-5)]),c.lightened(0.25))
  preload("res://features/magic/rune_art.gd").draw(self,element,Vector2(0,y-5),0.55)
 if float(r.remaining)>0:
  draw_arc(Vector2(0,8),18,0,TAU,24,Color(c,0.7),2)
  for i in range(8): draw_line(Vector2(0,8)+Vector2.RIGHT.rotated(i*TAU/8+elapsed)*18,Vector2(0,8)+Vector2.RIGHT.rotated(i*TAU/8+elapsed)*22,c,1)
 draw_rect(Rect2(-17,-36,34,3),Color("342d28")); draw_rect(Rect2(-17,-36,34*float(r.hp)/200,3),c)
func draw_ellipse_shadow() -> void:
 draw_set_transform(Vector2(0,10),0,Vector2(1,0.3)); draw_circle(Vector2.ZERO,15,Color(0.1,0.1,0.05,0.3)); draw_set_transform(Vector2.ZERO)
 draw_rect(Rect2(-20,6,40,9),Color("665348")); draw_rect(Rect2(-22,3,44,5),Color("af9779"))
 for x in [-14,-2,10]: draw_line(Vector2(x,8),Vector2(x,15),Color("8f7763"),1)
