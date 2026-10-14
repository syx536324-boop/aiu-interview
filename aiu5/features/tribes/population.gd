# Owns tribal population identity, profession transitions, sex/age and finite level milestone recruits.
extends RefCounted
const Careers := preload("res://features/tribes/profession_catalog.gd")
const Enemy := preload("res://features/combat/enemy.gd")
var runtime: Node
var members: Dictionary={}
var highest_level := 1
var next_child := 0
func start(owner: Node) -> void:
 runtime=owner
 for id: String in runtime.session.combat.enemies:
  var node: Node=runtime.session.combat.enemies[id]
  if node.tribe not in ["forest","barbarian","yunye"]: continue
  register(id,node.tribe,node.role,3 if node.role in ["archer","charger"] else 1,true)
 starters()
func starters() -> void:
 for data: Dictionary in [{"id":"home:initial_male","gender":"male","name":"阿林","at":Vector2(610,340)},{"id":"home:initial_female","gender":"female","name":"小满","at":Vector2(638,340)}]:
  if members.has(data.id): continue
  add(str(data.id),"home","civilian",1,data.at); members[data.id].gender=data.gender; members[data.id].name=data.name; apply(str(data.id))
func register(id: String, tribe: String, career: String, rank: int, fresh := false) -> void:
 var index := members.size()
 members[id]={"tribe":tribe,"career":career,"level":rank,"gender":"female" if index%2 and career!="chief" else "male","child_left":0.0,"name":str(Careers.LABELS.get(career,"村民"))+"·"+str(index+1)}
 apply(id,fresh)
 if career=="archer" and fresh: runtime.session.inventory.exchange("npc:"+id,{}, {"arrow":30})
func node(id: String) -> Node: return runtime.session.combat.enemies.get(id)
func friendly(id: String) -> bool:
 return members.has(id) and runtime.relics.owner(str(members[id].tribe))=="player"
func count(tribe: String, alive_only := true) -> int:
 var result := 0
 for id: String in members:
  if members[id].tribe!=tribe: continue
  var actor: Node=node(id)
  if not alive_only or (is_instance_valid(actor) and actor.hp>0): result+=1
 var chief_id := str(runtime.relics.states.get(tribe,{}).get("chief_id",""))
 var chief: Node=runtime.session.magic._actor(chief_id)
 if is_instance_valid(chief) and (not alive_only or not chief.dead): result+=1
 return result
func current_player_level() -> int:
 var result := 1
 for id: String in ["ali","heya","chief_priest"]: result=maxi(result,int(runtime.session.magic.ensure(id).level))
 return result
func advance(delta: float) -> void:
 for id: String in members:
  if float(members[id].child_left)>0:
   members[id].child_left=maxf(0,float(members[id].child_left)-delta)
   if members[id].child_left<=0: members[id].name=str(members[id].name).replace("幼童","新村民"); members[id]["leave_clinic"]=true; apply(id)
  var member: Node=node(id)
  if members[id].get("leave_clinic",false) and is_instance_valid(member):
   if member.room_id=="": members[id].erase("leave_clinic")
   elif runtime.workers.move(member,runtime.session.interiors.rooms[member.room_id].exit_point(),delta,32):
    var at: Vector2=runtime.session.world.home_data(member.room_id).door+Vector2(0,8)
    runtime.session.interiors.leave(member,runtime.session.world.objects,at); members[id].erase("leave_clinic"); runtime.session._sync_view()
 var now := current_player_level()
 if now<=highest_level: return
 var old := highest_level; highest_level=now
 for tribe: String in ["forest","barbarian","yunye"]:
  for milestone in range(old+1,mini(now,11)+1):
   if count(tribe)+runtime.romance.reserved(tribe)>=30: break
   var id := tribe+":growth:"+str(milestone)
   if members.has(id): continue
   add(id,tribe,"civilian",1,runtime.centers[tribe]+Vector2(50+(milestone%4)*18,80))
  runtime.settlements.match_population(tribe,count(tribe))
func add(id: String, tribe: String, career: String, rank: int, at: Vector2) -> Node:
 var actor := Enemy.new(); actor.combat=runtime.session.combat; actor.enemy_id=id
 var area: Rect2=runtime.session.world.Layout.HOME_LIT if tribe=="home" else runtime.session.combat.TRIBES[tribe].area
 actor.configure_tribe(tribe,career,area,Careers.life(career,rank)); actor.position=at
 runtime.session.world.objects.add_child(actor); runtime.session.combat.enemies[id]=actor
 runtime.session.combat.initial_states[id]={"hp":actor.hp,"at":[at.x,at.y]}
 register(id,tribe,career,rank,true)
 return actor
func apply(id: String, fresh := false) -> void:
 var actor: Node=node(id)
 if not is_instance_valid(actor): return
 var r: Dictionary=members[id]; var previous: float=actor.max_hp
 actor.role=str(r.career); actor.npc_level=int(r.level); actor.resident_id="npc:"+id
 actor.max_hp=Careers.life(str(r.career),int(r.level))
 actor.hp=actor.max_hp if fresh else clampf(actor.hp+maxf(0,actor.max_hp-previous),0,actor.max_hp)
 actor.gender=str(r.gender); actor.npc_runtime=runtime
 actor.friendly=friendly(id); actor.refresh()
 if is_instance_valid(actor.sprite): actor.sprite.modulate=Color("b7d9b1") if actor.friendly else Color("d4a29d"); actor.sprite.scale=Vector2.ONE* (0.65 if r.child_left>0 else 1.0)
 runtime.session.inventory.ensure_bag("npc:"+id)
 # Non-chief units never awaken or receive magic skills.
 if r.career!="chief":
  var state: Dictionary=runtime.session.magic.ensure("npc:"+id)
  state.level=1; state.element=""; state.unlocked=[]; state.branch_unlocked=[]
func upgrade(id: String, career: String) -> bool:
 if not members.has(id) or not friendly(id) or node(id).hp<=0: return false
 var options := Careers.upgrades(members[id]); var choice: Dictionary={}
 for option: Dictionary in options:
  if option.career==career: choice=option
 if choice.is_empty(): return false
 var s: Node=runtime.session; var before: Dictionary=s.inventory.export_data()
 if not s.inventory.exchange(s.world.active_resident.resident_id,choice.cost,{}): s._set_notice("升级材料不足，未扣除物品。"); return false
 members[id].career=choice.career; members[id].level=choice.level; apply(id)
 return s.production.commit(before,"已升级为%d级%s。"%[choice.level,Careers.LABELS[choice.career]])
func specialize(id: String, career: String) -> bool:
 if not members.has(id) or not friendly(id) or members[id].level!=3 or members[id].career!="civilian" or career not in ["archer","charger","civilian"]: return false
 var s: Node=runtime.session; var before: Dictionary=s.inventory.export_data()
 members[id].career=career; apply(id)
 if career=="archer": s.inventory.exchange("npc:"+id,{}, {"arrow":30})
 return s.production.commit(before,"已选择职业："+str(Careers.LABELS[career])+"。")
func child(tribe: String, at: Vector2) -> String:
 if tribe!="home" and count(tribe)>=30: return ""
 var id := tribe+":child:"+str(next_child); next_child+=1
 add(id,tribe,"civilian",1,at); members[id].child_left=300.0; members[id].name="幼童·"+str(next_child); apply(id)
 return id
func export_state() -> Dictionary:
 var records := members.duplicate(true)
 for id: String in records:
  var actor: Node=node(id)
  if is_instance_valid(actor): records[id].hp=actor.hp; records[id].at=[actor.position.x,actor.position.y]; records[id].room=actor.room_id; var outside: Vector2=runtime.session.interiors.outdoor_position(actor); records[id].outside=[outside.x,outside.y]
 return {"members":records,"highest_level":highest_level,"next_child":next_child}
func restore(data: Dictionary) -> void:
 if data.is_empty(): return
 var records: Dictionary=data.get("members",{}).duplicate(true)
 for id: String in members.keys():
  if records.has(id): continue
  var actor: Node=node(id)
  if is_instance_valid(actor):
   runtime.session.world.points.erase("npcunit:"+id)
   runtime.session.combat.enemies.erase(id); runtime.session.combat.initial_states.erase(id)
   if actor.get_parent()!=null: actor.get_parent().remove_child(actor)
   actor.queue_free()
  members.erase(id)
 for id: String in records:
  var r: Dictionary=records[id]
  if not is_instance_valid(node(id)): add(id,str(r.tribe),str(r.career),int(r.level),Vector2(r.at[0],r.at[1]))
  members[id]=r; apply(id)
  if r.has("hp"): node(id).hp=clampf(float(r.hp),0,node(id).max_hp); node(id).refresh()
 highest_level=maxi(1,int(data.get("highest_level",1))); next_child=maxi(0,int(data.get("next_child",0)))
 # Backfill an older save once; persisted dead starters are kept dead instead of respawning.
 starters()
func reapply() -> void:
 for id: String in members:
  apply(id)
  var actor: Node=node(id)
  var r: Dictionary=members[id]
  var room_id := str(r.get("room",""))
  if room_id!="" and not runtime.session.world.home_data(room_id).is_empty():
   runtime.session.interiors.enter(actor,runtime.session.world.home_data(room_id)); actor.position=Vector2(r.at[0],r.at[1]); runtime.session.interiors.outside_positions[actor.resident_id]=Vector2(r.get("outside",[322,224])[0],r.get("outside",[322,224])[1])
  if r.has("hp"): actor.hp=clampf(float(r.hp),0,actor.max_hp); actor.refresh()
