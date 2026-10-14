# Generates each wild herd cell once and owns transactional two-rope animal following.
extends Node2D
const CELL := Vector2(256,256)
const Layout := preload("res://features/village/layout.gd")
const Frontier := preload("res://features/landscape/frontier.gd")
var session: Node
var generated: Dictionary={}
var tethers: Dictionary={}
var refresh_left := 0.0
func start(controller: Node) -> void: session=controller
func focus() -> void:
 var actor: Node=session.world.active_resident
 if actor.room_id!="": return
 var cell := Vector2i((actor.position/CELL).floor())
 for y in range(cell.y-1,cell.y+2):
  for x in range(cell.x-1,cell.x+2): _generate(Vector2i(x,y))
func _generate(cell: Vector2i) -> void:
 var area := Rect2(Vector2(cell)*CELL,CELL).intersection(Layout.BOUNDS.grow(-12))
 var key := str(cell.x)+":"+str(cell.y)
 if generated.has(key) or not area.has_area(): return
 generated[key]=true
 var rng := RandomNumberGenerator.new(); rng.seed=session.world.resource_seed^((cell.x+131)*73856093)^((cell.y+131)*19349663)
 if rng.randf()>=0.3: return
 for i in range(rng.randi_range(1,2)):
  var at := area.position+Vector2(rng.randf_range(20,maxf(20,area.size.x-20)),rng.randf_range(20,maxf(20,area.size.y-20)))
  for attempt in range(8):
   if safe(at): break
   at=area.position+Vector2(rng.randf()*area.size.x,rng.randf()*area.size.y)
  if not safe(at): continue
  var id := "wild:"+key+":"+str(i)
  var kind: String=["cow","pig","sheep"][rng.randi_range(0,2)]
  session.livestock._spawn(id,kind,"male" if rng.randf()<0.5 else "female",300,at,area)
 session.livestock._refresh_points()
func safe(at: Vector2) -> bool:
 if Frontier.protected(Rect2(at-Vector2(5,5),Vector2(10,10))): return false
 if preload("res://features/landscape/landscape.gd").protected(Rect2(at-Vector2(5,5),Vector2(10,10))): return false
 for rect: Rect2 in session.world.logical_obstacles(session.gate_open):
  if rect.grow(8).has_point(at): return false
 return true
func advance(delta: float) -> void:
 refresh_left-=delta
 if refresh_left<=0: refresh_left=0.5; focus()
 for id: String in tethers.keys():
  var animal: Node=session.livestock.find_animal(id)
  var actor: Node=session.magic._actor(str(tethers[id]))
  if not is_instance_valid(animal) or animal.hp<=0:
   # Keep a refundable rope credit until its owner has inventory room.
   if is_instance_valid(actor) and session.inventory.exchange(actor.resident_id,{}, {"rope":1}): tethers.erase(id)
   continue
  if not is_instance_valid(actor) or actor.dead:
   animal.remove_meta("tether_target")
   if is_instance_valid(actor) and session.inventory.exchange(actor.resident_id,{}, {"rope":1}):
    tethers.erase(id); _release(animal)
   continue
  var at: Vector2=actor.position if actor.room_id=="" else session.interiors.outdoor_position(actor)
  var previous: Vector2=animal.get_meta("rope_destination",at)
  var retry: float=maxf(0,float(animal.get_meta("rope_retry",0))-delta)
  var path: PackedVector2Array=animal.get_meta("rope_path",PackedVector2Array())
  if retry<=0 or previous.distance_to(at)>24:
   path=session.world.navigation.find_path(animal.position,at); retry=1.0; animal.set_meta("rope_destination",at)
  while not path.is_empty() and animal.position.distance_to(path[0])<6: path.remove_at(0)
  animal.set_meta("rope_path",path); animal.set_meta("rope_retry",retry)
  var waypoint: Vector2=path[0] if not path.is_empty() else animal.position
  if animal.position.distance_to(at)<=18: waypoint=animal.position
  animal.set_meta("tether_target",waypoint)
  if animal.get_parent()==null and animal.position.distance_to(at)>18:
   animal.position=animal.position.move_toward(waypoint,96*delta)
 queue_redraw()
func tie(animal: Node) -> bool:
 var actor: Node=session.world.active_resident
 if not session.production.allowed(actor) or animal.hp<=0 or animal.species not in ["cow","pig","sheep"] or actor.room_id!="" or actor.position.distance_to(animal.position)>26: return false
 var id: String=animal.animal_id
 var before: Dictionary=session.inventory.export_data()
 if tethers.has(id):
  if str(tethers[id])!=actor.resident_id: session._set_notice("这只牲畜正由另一名角色牵引。"); return false
  if not session.inventory.exchange(actor.resident_id,{}, {"rope":1}): session._set_notice("背包满，无法收回绳子。"); return false
  tethers.erase(id); animal.remove_meta("tether_target")
  # Once released, wander locally rather than snapping back to a former spawning cell.
  _release(animal)
 else:
  if tethers.size()>=2: session._set_notice("同时最多使用两根绳子。"); return false
  if not session.inventory.exchange(actor.resident_id,{"rope":1},{}): session._set_notice("需要绳子1（工作台布3合成）。"); return false
  tethers[id]=actor.resident_id; animal.set_meta("tether_target",actor.position)
 return session.production.commit(before,"牵绳状态已保存。")
func _release(animal: Node) -> void:
 animal.pen_bounds=Rect2(animal.position-Vector2(56,40),Vector2(112,80)).intersection(Layout.BOUNDS.grow(-12))
 animal.set_meta("wild_bounds",[animal.pen_bounds.position.x,animal.pen_bounds.position.y,animal.pen_bounds.size.x,animal.pen_bounds.size.y]); animal._choose_target()
func export_state() -> Dictionary: return {"generated":generated.duplicate(),"tethers":tethers.duplicate()}
func restore(data: Dictionary) -> void:
 generated=data.get("generated",{}).duplicate(); tethers=data.get("tethers",{}).duplicate()
 for animal: Node in session.livestock.animals: animal.remove_meta("tether_target")
 advance(0)
func _draw() -> void:
 if not is_instance_valid(session) or not session.world.visible: return
 for id: String in tethers:
  var animal: Node=session.livestock.find_animal(id); var actor: Node=session.magic._actor(str(tethers[id]))
  if is_instance_valid(animal) and is_instance_valid(actor) and actor.room_id=="" and animal.get_parent()!=null and actor.get_parent()!=null: draw_line(actor.global_position-Vector2(0,8),animal.global_position-Vector2(0,7),Color("d1b280"),1)
