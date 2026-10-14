# Adds branched woodland waterways, walkable bridge gaps and protected native giant trees.
extends Node2D
const Layout := preload("res://features/village/layout.gd")
const RIVERS := [
 [Vector2(-20,800),Vector2(-700,1300),Vector2(-1200,2100),Vector2(-2100,2800)],
 [Vector2(-700,1300),Vector2(-1400,1100),Vector2(-2200,800)],
 [Vector2(-1200,2100),Vector2(-900,3000),Vector2(-400,4000)],
 [Vector2(-1400,1100),Vector2(-1800,200),Vector2(-2100,-800)]]
const GIANTS := [Vector2(-2100,-1300),Vector2(-1700,-600),Vector2(-1950,500),Vector2(-2200,1900),Vector2(-1650,2500),Vector2(-700,2500),Vector2(-1500,3600),Vector2(-2200,4400),Vector2(-500,4500)]
var world: Node
var render_region := Rect2()
func start(village: Node) -> void:
 world=village
 for rect: Rect2 in obstacles(): world._body(self,rect.get_center(),rect.size)
 set_process(true)
func _process(_delta: float) -> void:
 var area := Rect2(world.active_resident.position-Vector2(650,450),Vector2(1300,900))
 if render_region!=area: render_region=area; queue_redraw()
func _draw() -> void:
 for route: Array in RIVERS:
  for i in range(route.size()-1):
   var a: Vector2=route[i]; var b: Vector2=route[i+1]
   if not Rect2(a.min(b),abs(b-a)).grow(40).intersects(render_region): continue
   draw_line(a,b,Color("b5b28a"),26); draw_line(a,b,Color("518d96"),18)
   var mid := a.lerp(b,0.5)
   draw_line(mid-(b-a).normalized()*18,mid+(b-a).normalized()*18,Color("926d43"),28)
   for off in [-8,0,8]: draw_line(mid+(b-a).normalized()*off-(b-a).normalized().orthogonal()*14,mid+(b-a).normalized()*off+(b-a).normalized().orthogonal()*14,Color("c69b66"),2)
 for at: Vector2 in GIANTS:
  if not render_region.has_point(at): continue
  draw_set_transform(at)
  draw_colored_polygon(PackedVector2Array([Vector2(-24,0),Vector2(-10,-35),Vector2(-12,-78),Vector2(10,-85),Vector2(13,-35),Vector2(27,0),Vector2(8,-5),Vector2(-5,-5)]),Color("554334"))
  draw_rect(Rect2(-5,-76,10,66),Color("8d6a48"))
  draw_line(Vector2(0,-60),Vector2(-29,-83),Color("72533a"),8); draw_line(Vector2(3,-53),Vector2(29,-76),Color("72533a"),7)
  for level in range(3):
   var y := -55-level*20; var width := 56-level*9
   draw_colored_polygon(PackedVector2Array([Vector2(-width,y),Vector2(-width+6,y-17),Vector2(-23,y-25),Vector2(13,y-27),Vector2(width-9,y-19),Vector2(width,y-5),Vector2(width-10,y+7),Vector2(19,y+12),Vector2(-19,y+9)]),Color("244c37").lightened(level*0.07))
   for x in [-30,-9,15,29]: draw_rect(Rect2(x,y-13+(x%7),8,3),Color("628550"))
  draw_set_transform(Vector2.ZERO)
static func obstacles() -> Array[Rect2]:
 var result: Array[Rect2]=[]
 for route: Array in RIVERS:
  for i in range(route.size()-1):
   var a: Vector2=route[i]; var b: Vector2=route[i+1]; var length := a.distance_to(b)
   for j in range(ceili(length/14)+1):
    var d := j*14.0
    if abs(d-length/2)<26: continue
    result.append(Rect2(a.move_toward(b,d)-Vector2(9,9),Vector2(18,18)))
 for at: Vector2 in GIANTS: result.append(Rect2(at-Vector2(14,30),Vector2(28,30)))
 return result
static func protected(bounds: Rect2) -> bool:
 for at: Vector2 in GIANTS:
  if Rect2(at-Vector2(56,120),Vector2(112,128)).intersects(bounds): return true
 for route: Array in RIVERS:
  for i in range(route.size()-1):
   var a: Vector2=route[i]; var b: Vector2=route[i+1]
   if Geometry2D.get_closest_point_to_segment(bounds.get_center(),a,b).distance_to(bounds.get_center())<=bounds.size.length()/2+18: return true
 return false
static func nearest_water(at: Vector2) -> Vector2:
 var result := Vector2(46,310); var distance := INF
 for route: Array in RIVERS:
  for i in range(route.size()-1):
   var point := Geometry2D.get_closest_point_to_segment(at,route[i],route[i+1])
   if point.distance_squared_to(at)<distance: distance=point.distance_squared_to(at); result=point
 return result
