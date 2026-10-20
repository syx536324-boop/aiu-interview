# Resolves NPC movement and online farm/mining steps with finite deposits and nine-slot bags.
extends RefCounted
const Movement := preload("res://features/tribes/movement.gd")
var movement := Movement.new()
const Careers := preload("res://features/tribes/profession_catalog.gd")
const Land := preload("res://features/homestead/land.gd")
const Frontier := preload("res://features/landscape/frontier.gd")
var runtime: Node
var jobs: Dictionary={}
func job(id: String) -> Dictionary:
 if not jobs.has(id): jobs[id]={"kind":"","left":0.0,"status":"待命","retry":0.0}
 return jobs[id]
func assign(id: String, kind: String) -> bool:
 if not runtime.population.friendly(id) or runtime.population.members[id].career!="miner" or kind not in ["stone","coal","iron_ore"] or not runtime.mine_marked: return false
 var s: Node=runtime.session; var before: Dictionary=s.inventory.export_data()
 jobs[id]={"kind":kind,"left":0.0,"status":"前往已标记矿洞","retry":0.0}
 return s.production.commit(before,"矿工任务已分配。")
func move(actor: Node, at: Vector2, delta: float, speed := 42.0, purpose := "work") -> bool:
 if purpose in ["work","routine"]:
  var id: String=str(actor.enemy_id) if "enemy_id" in actor else str(actor.resident_id)
  speed*=runtime.session.magic.branches.speed_rate(id)
 if actor.position.distance_to(at)<=14:
  movement.stop(actor); return true
 # Active bodies execute in physics frames; parked/manual simulation retains its synchronous contract.
 if actor.is_inside_tree() and actor.is_physics_processing():
  movement.submit(actor,at,speed,purpose); return false
 return move_step(actor,at,delta,speed)
func move_step(actor: Node, at: Vector2, delta: float, speed: float, smooth := false) -> bool:
 var gap: float=actor.position.distance_to(at)
 if gap<=14: actor.velocity=Vector2.ZERO; return true
 var nav=runtime.session.world.navigation
 if actor.room_id!="" and runtime.session.interiors.rooms.has(actor.room_id): nav=runtime.session.interiors.rooms[actor.room_id].navigation
 var previous: Vector2=actor.get_meta("work_destination",at)
 if previous.distance_to(at)>24 or int(actor.get_meta("work_revision",-1))!=nav.revision:
  actor.navigation=PackedVector2Array(); actor.set_meta("work_retry",0.0)
 actor.set_meta("work_destination",at); actor.set_meta("work_revision",nav.revision)
 actor.set_meta("work_retry",maxf(0,float(actor.get_meta("work_retry",0.0))-delta))
 if actor.navigation.is_empty():
  if float(actor.get_meta("work_retry",0))>0: return false
  actor.navigation=runtime.session.monsters.path_to(actor,at) if actor.get_meta("monster_engaged",false) and is_instance_valid(runtime.session.monsters) else nav.find_path(actor.position,at)
  if actor.navigation.is_empty(): actor.set_meta("work_retry",2.0); return false
 while not actor.navigation.is_empty() and actor.position.distance_to(actor.navigation[0])<5: actor.navigation.remove_at(0)
 if actor.navigation.is_empty(): return false
 var old_at: Vector2=actor.position
 var direction: Vector2=actor.position.direction_to(actor.navigation[0])
 var travel_speed := speed
 if smooth: travel_speed=minf(speed,sqrt(2.0*speed*8.0*maxf(0.0,gap-14.0)))
 var wanted: Vector2=direction*travel_speed
 actor.velocity=actor.velocity.move_toward(wanted,speed*8.0*delta) if smooth else wanted
 var motion: Vector2=actor.velocity*delta
 if motion.length()>actor.position.distance_to(actor.navigation[0]): motion=actor.navigation[0]-actor.position
 var next: Vector2=actor.position+motion
 if actor.is_inside_tree():
  var collision: KinematicCollision2D=actor.move_and_collide(motion)
  if collision!=null and smooth:
   actor.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
 else: actor.position=next
 if actor.position.distance_to(old_at)<speed*delta*0.1:
  var stalled: float=float(actor.get_meta("work_stall",0))+delta
  actor.set_meta("work_stall",stalled)
  if stalled>=1.0: actor.navigation=PackedVector2Array(); actor.set_meta("work_retry",2.0); actor.set_meta("work_stall",0.0)
 else: actor.set_meta("work_stall",0.0)
 if not smooth and is_instance_valid(actor.sprite):
  actor.sprite.flip_h=next.x<old_at.x
  actor.sprite.frame=int(Time.get_ticks_msec()/180)%mini(2,actor.sprite.hframes)
 return actor.position.distance_to(at)<=14
func advance(delta: float) -> void:
 var s: Node=runtime.session
 for id: String in runtime.population.members:
  var r: Dictionary=runtime.population.members[id]; var actor: Node=runtime.population.node(id)
  if not is_instance_valid(actor) or actor.hp<=0 or not runtime.population.friendly(id) or float(r.child_left)>0: continue
  if is_instance_valid(s.monsters) and s.monsters.blocks_work(actor): continue
  if runtime.romance.busy(actor.resident_id) or (runtime.encounters.in_combat(actor) and not (is_instance_valid(s.monsters) and s.monsters.is_protected(actor))): continue
  var task := job(id); task.left=maxf(0,float(task.left)-delta)
  if float(task.left)>0.000001: continue
  if r.career=="farmer": _farmer(id,actor,task,delta)
  elif r.career=="miner": _miner(id,actor,task,delta)
func _farm_owned(p: Dictionary) -> bool:
 return runtime.relics.owner(str(p.get("tribe","home")))=="player"
func _farmer(id: String, actor: Node, task: Dictionary, delta: float) -> void:
 var s: Node=runtime.session; var h: Node=s.homestead; h.settle()
 var candidates: Array=[]
 for i in range(h.plots.size()):
  var p: Dictionary=h.plots[i]
  if _farm_owned(p) and (bool(p.mature) or bool(p.dry) or str(p.crop) in ["","dead"]): candidates.append(i)
 if candidates.is_empty(): task.status="等待作物成熟或分配农田"; task.left=1.0; return
 candidates.sort_custom(func(a: int,b: int)->bool:return actor.position.distance_squared_to(Land.bounds(h.plots[a]).get_center())<actor.position.distance_squared_to(Land.bounds(h.plots[b]).get_center()))
 var p: Dictionary=h.plots[candidates[0]]
 if p.dry and not s.inventory.has_item(actor.resident_id,"water_bucket"):
  var has_vessel: bool= s.inventory.has_item(actor.resident_id,"bucket") or s.inventory.has_item(actor.resident_id,"water_bucket_1") or s.inventory.has_item(actor.resident_id,"water_bucket_2") or s.inventory.has_item(actor.resident_id,"water_bucket_3")
  if not has_vessel: task.status="需要水桶，可打开背包补给"; task.left=1.0; return
  var water_at := Vector2(157,205)
  var river_at: Vector2=Frontier.nearest_water(actor.position)
  if actor.position.distance_to(river_at)<actor.position.distance_to(water_at): water_at=river_at+(actor.position-river_at).normalized()*23
  task.status="前往水源补水"
  if move(actor,water_at,delta):
   if h.fill_bucket(actor): task.left=Careers.work_interval("farmer",int(runtime.population.members[id].level))
   else: task.left=1.0
  return
 task.status="前往农田"
 var at: Vector2=Land.bounds(p).get_center()
 if not move(actor,at,delta): return
 var result := false
 if p.mature: result=h.harvest(actor); task.status="收获"
 elif p.dry: result=h.water(actor); task.status="灌溉"
 else:
  var seed := "seeds" if s.inventory.has_item(actor.resident_id,"seeds") else "rice_seeds"
  if not s.inventory.has_item(actor.resident_id,seed): task.status="缺少种子，可打开背包补给"; task.left=1.0; return
  h.selected_seeds[actor.resident_id]=seed; result=h.plant(actor); task.status="播种"
 if result: task.left=Careers.work_interval("farmer",int(runtime.population.members[id].level)); actor.navigation=PackedVector2Array()
 else: task.status="材料不足或背包已满"; task.left=1.0
func _miner(id: String, actor: Node, task: Dictionary, delta: float) -> void:
 var s: Node=runtime.session
 if not runtime.mine_marked: task.status="矿洞尚未标记"; task.left=1.0; return
 if task.kind=="": task.status="待分配：石头／煤矿／铁矿"; task.left=1.0; return
 if actor.room_id=="":
  task.status="前往已标记矿洞"
  if move(actor,s.mining.DOOR+Vector2(0,10),delta):
   s.interiors.enter(actor,s.world.home_data("mine")); s._sync_view()
  return
 if actor.room_id!="mine": task.status="矿工需要在矿洞工作"; task.left=1.0; return
 var records: Array=[]
 for r: Dictionary in s.mining.underground_records:
  if r.kind==task.kind and int(s.mining.progress.get(r.id,0))<(4 if r.kind=="iron_ore" else 3): records.append(r)
 if records.is_empty(): task.status="该矿物已经采尽"; task.left=1.0; return
 records.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return actor.position.distance_squared_to(a.at)<actor.position.distance_squared_to(b.at))
 var ore: Dictionary=records[0]
 if not move(actor,ore.at+Vector2(0,15),delta): task.status="前往矿脉"; return
 # First arrival starts a full interval; resource production never occurs on the same instant as arrival.
 if str(task.get("ore",""))!=str(ore.id):
  task.ore=ore.id; task.left=Careers.work_interval("miner",int(runtime.population.members[id].level),str(task.kind)); task.status="开采中（护卫掩护）" if is_instance_valid(s.monsters) and s.monsters.is_protected(actor) else "开采中"; return
 if s.mining.worker_take(ore,actor.resident_id):
  task.left=Careers.work_interval("miner",int(runtime.population.members[id].level),str(task.kind)); task.status="开采中（护卫掩护）" if is_instance_valid(s.monsters) and s.monsters.is_protected(actor) else "开采中"
 else: task.status="背包已满，等待取出"; task.left=1.0
func export_state() -> Dictionary: return jobs.duplicate(true)
func restore(data: Dictionary) -> void:
 movement.begin_step(); jobs=data.duplicate(true)
