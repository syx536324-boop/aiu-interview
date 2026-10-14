# Draws a celebratory red curtain with layered vertical folds; animation phase is owned by romance state.
extends CanvasLayer
var romance: RefCounted
var elapsed := 0.0
var drawing: Control
func _ready() -> void:
 layer=30; process_mode=Node.PROCESS_MODE_ALWAYS
 drawing=Cloth.new(); drawing.owner_view=self; add_child(drawing)
func _process(delta: float) -> void:
 if romance.ceremony.is_empty(): queue_free(); return
 elapsed=float(romance.ceremony.get("elapsed",0))+delta; romance.ceremony.elapsed=elapsed
 drawing.queue_redraw()
 if elapsed>=2.3: romance.finish_ceremony(); queue_free()
class Cloth extends Control:
 var owner_view: Node
 func _ready() -> void:
  size=Vector2(640,400); mouse_filter=Control.MOUSE_FILTER_STOP
 func _draw() -> void:
  var time: float=owner_view.elapsed
  var amount := clampf(time/0.65,0,1) if time<0.65 else (1.0 if time<1.65 else clampf((2.3-time)/0.65,0,1))
  amount=amount*amount*(3-2*amount)
  var width := 322.0*amount
  for side in [0,1]:
   var start := 0.0 if side==0 else 640.0-width
   draw_rect(Rect2(start,0,width,400),Color("971728"))
   for x in range(int(start),int(start+width),2):
    var distance := x-start
    var fold := (sin(distance*TAU/24.0)+sin(distance*TAU/12.0)*0.17)*0.5+0.5
    var c := Color("5d0a17").lerp(Color("ca2b3c"),fold)
    draw_rect(Rect2(x,16,2,384),c)
    if int(distance)%24==2: draw_line(Vector2(x,18),Vector2(x,400),Color(0.98,0.46,0.33,0.18),1)
   draw_rect(Rect2(start,0,width,20),Color("70111f"))
   draw_line(Vector2(start,18),Vector2(start+width,18),Color("d2a55c"),3)
   for x in range(int(start+4),int(start+width),18):
    draw_colored_polygon(PackedVector2Array([Vector2(x,18),Vector2(x+12,18),Vector2(x+6,26)]),Color("b58443"))
   var seam := start+width-3 if side==0 else start+1
   draw_line(Vector2(seam,0),Vector2(seam,400),Color("e9b967"),3)
   draw_line(Vector2(seam-3 if side==0 else seam+3,0),Vector2(seam-3 if side==0 else seam+3,400),Color("480a15"),2)
  if amount>0.95:
   draw_circle(Vector2(320,194),28,Color("771220")); draw_arc(Vector2(320,194),27,0,TAU,32,Color("edc37d"),2)
   # Pixel strokes keep the wedding emblem legible even without a system CJK font.
   for left in [302.0,321.0]:
    for stroke: Rect2 in [Rect2(0,0,17,2),Rect2(7,-3,2,9),Rect2(2,7,13,2),Rect2(2,12,13,2),Rect2(2,7,2,7),Rect2(13,7,2,7),Rect2(4,16,2,3),Rect2(10,16,2,3),Rect2(0,20,17,2),Rect2(3,25,11,2),Rect2(3,31,11,2),Rect2(3,25,2,8),Rect2(12,25,2,8)]:
     draw_rect(Rect2(stroke.position+Vector2(left,177),stroke.size),Color("f3ce83"))
