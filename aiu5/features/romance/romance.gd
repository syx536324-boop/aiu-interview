# Owns per-pair affinity, marriage homes, partner escort, pregnancy, delivery and online child growth requests.
extends RefCounted
const Curtain := preload("res://features/romance/curtain.gd")
const Layout := preload("res://features/interiors/layout.gd")
const Weddings := preload("res://features/romance/weddings.gd")
var weddings := Weddings.new()
var runtime: Node
var affinity: Dictionary={}
var marriages: Dictionary={}
var pregnancies: Dictionary={}
var escorts: Dictionary={}
var departures: Dictionary={}
var ceremony: Dictionary={}
var birth_counter := 0
var delivering: Dictionary={}
var curtain: CanvasLayer
func actor(id: String) -> Node:
 return runtime.population.node(id.trim_prefix("npc:")) if id.begins_with("npc:") else runtime.session.magic._actor(id)
func adult(id: String) -> bool:
 if not is_instance_valid(actor(id)): return false
 return not id.begins_with("npc:") or float(runtime.population.members.get(id.trim_prefix("npc:"),{}).get("child_left",300))<=0
func alive(id: String) -> bool:
 var node: Node=actor(id)
 return is_instance_valid(node) and (node.hp>0 if id.begins_with("npc:") else runtime.session.vitals.ensure(id).life>0)
func friendly(id: String) -> bool:
 return runtime.population.friendly(id.trim_prefix("npc:")) if id.begins_with("npc:") else is_instance_valid(actor(id))
func gender(id: String) -> String:
 if id.begins_with("npc:"): return str(runtime.population.members.get(id.trim_prefix("npc:"),{}).get("gender","male"))
 return "female" if id=="heya" else "male"
func pair(a: String,b: String) -> String:
 var ids: Array[String]=[a,b]; ids.sort(); return "|".join(ids)
func liking(a: String,b: String) -> int: return clampi(int(affinity.get(pair(a,b),50)),50,100)
func spouse(id: String) -> String:
 var people := partners(id)
 return people[0] if not people.is_empty() else ""
func partners(id: String) -> Array[String]:
 var result: Array[String]=[]
 for r: Dictionary in marriages.values():
  if r.a==id: result.append(str(r.b))
  elif r.b==id: result.append(str(r.a))
 return result
func marriage(a: String,b: String) -> Dictionary: return marriages.get(pair(a,b),{})
func name(id: String) -> String:
 if id.begins_with("npc:"): return str(runtime.population.members.get(id.trim_prefix("npc:"),{}).get("name","村民"))
 return str(actor(id).resident_name) if is_instance_valid(actor(id)) else "角色"
func village(home: Dictionary) -> String:
 if home.has("tribe"): return str(home.tribe)
 if str(home.get("id","")).begins_with("forest_"): return "forest"
 var at: Vector2=home.get("at",Vector2(548,310))
 var result := "home"; var distance := 700.0
 for tribe: String in ["forest","barbarian","yunye"]:
  var gap: float=at.distance_to(runtime.centers[tribe])
  if gap<distance: result=tribe; distance=gap
 return result
func clinic(home: Dictionary) -> bool:
 return str(home.get("function",""))=="herb_house" or str(home.get("id","")) in ["herb_house","forest_herb_house"]
func clinics(tribe: String) -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for home: Dictionary in runtime.session.world.homes:
  if clinic(home) and village(home)==tribe and runtime.relics.owner(tribe)=="player" and not home.get("ruined",false) and not home.get("building",false): result.append(home)
 return result
func ordinary(home: Dictionary) -> bool:
 if home.get("tower",false) or home.get("skill_hut",false) or home.get("building",false) or home.get("ruined",false) or clinic(home): return false
 if str(home.get("function","")) in ["kitchen","blacksmith","stove","arrow_tower"]: return false
 return str(home.get("id","")) not in ["kitchen","blacksmith","mine"]
func has_bed(home_id: String) -> bool:
 var s: Node=runtime.session
 if s.interiors.rooms.has(home_id): return s.interiors.rooms[home_id].fixtures.any(func(f: Node)->bool:return f.kind=="bed")
 var saved: Variant=s.interiors.layout_overrides.get(home_id,s.inventory.layouts.get(home_id,null))
 if saved is Array: return saved.any(func(f: Dictionary)->bool:return f.get("kind","")=="bed")
 var home: Dictionary=s.world.home_data(home_id)
 if home.has("beds"): return int(home.beds)>0
 if home.get("built",false): return ordinary(home)
 return Layout.ROOMS.has(home_id) and Layout.ROOMS[home_id].furniture.any(func(f: Array)->bool:return f[0]=="bed")
func homes() -> Array[Dictionary]:
 var result: Array[Dictionary]=[]
 for home: Dictionary in runtime.session.world.homes:
  if ordinary(home) and runtime.relics.owner(village(home))=="player" and has_bed(str(home.id)) and not clinics(village(home)).is_empty(): result.append(home)
 return result
func can_marry(a: String,b: String) -> bool:
 return compatible(a,b) and not marriages.has(pair(a,b)) and liking(a,b)>=80
func compatible(a: String,b: String) -> bool:
 return a!=b and alive(a) and alive(b) and adult(a) and adult(b) and friendly(a) and friendly(b) and gender(a)!=gender(b)
func gift(target: String) -> bool:
 var s: Node=runtime.session; var source: String=s.world.active_resident.resident_id
 if source==target or not friendly(target) or not alive(target): return false
 var before: Dictionary=s.inventory.export_data()
 if not s.inventory.exchange(source,{"bread":1},{}) or not s.inventory.exchange(target,{}, {"bread":1}):
  s.inventory.apply_data(before); s._set_notice("面包不足或对方背包已满，赠礼未完成。"); return false
 affinity[pair(source,target)]=mini(100,liking(source,target)+5)
 return s.production.commit(before,"送出面包，好感度%d／100。"%liking(source,target))

# 关系事件使用：按事件结算成对好感，统一夹在0～100。
func shift_liking(a: String,b: String,delta: int) -> int:
 if a==b: return 50
 var value := clampi(liking(a,b)+delta,0,100)
 affinity[pair(a,b)]=value
 return value
func marry(target: String,house: String) -> bool:
 var s: Node=runtime.session; var source: String=s.world.active_resident.resident_id
 if not can_marry(source,target) or not homes().any(func(h: Dictionary)->bool:return str(h.id)==house): return false
 var before: Dictionary=s.inventory.export_data()
 marriages[pair(source,target)]={"a":source,"b":target,"house":house}
 return s.production.commit(before,"已与"+name(target)+"结婚，婚房已选定。")
func invite(target := "") -> bool:
 var s: Node=runtime.session; var id: String=s.world.active_resident.resident_id
 if target=="": target=spouse(id)
 var r := marriage(id,target)
 if r.is_empty() or not alive(target) or not has_bed(str(r.house)): return false
 var before: Dictionary=s.inventory.export_data()
 escorts[target]={"leader":id,"house":str(r.house)}; actor(target).set_meta("tribal_escort",true)
 return s.production.commit(before,"配偶将同行前往婚房。进入后靠近床按E，一同上床。")
func reserved(tribe: String) -> int:
 var count := 0
 for p: Dictionary in pregnancies.values():
  if p.tribe==tribe: count+=1
 return count
func can_bed(id: String,target := "") -> bool:
 if target=="":
  for candidate: String in partners(id):
   if can_bed(id,candidate): return true
  return false
 if target=="" or not alive(id) or not alive(target) or not adult(id) or not adult(target): return false
 var r := marriage(id,target)
 if r.is_empty(): return false
 var house := str(r.house)
 if actor(id).room_id!=house or actor(target).room_id!=house or not has_bed(house): return false
 var woman := id if gender(id)=="female" else target
 var tribe := village(runtime.session.world.home_data(house))
 if pregnancies.has(woman) or clinics(tribe).is_empty(): return false
 if tribe!="home" and runtime.population.count(tribe)+reserved(tribe)>=30: return false
 for fixture: Node in runtime.session.interiors.rooms[house].fixtures:
  if fixture.kind=="bed" and actor(id).position.distance_to(fixture.position)<=38: return true
 return false
func bed(target := "") -> bool:
 var id: String=runtime.session.world.active_resident.resident_id
 if target=="":
  for candidate: String in partners(id):
   if can_bed(id,candidate): target=candidate; break
 return start_ceremony(id,target)
func start_ceremony(id: String,target: String) -> bool:
 var s: Node=runtime.session
 if not ceremony.is_empty() or not can_bed(id,target): return false
 var before: Dictionary=s.inventory.export_data(); var house := str(marriage(id,target).house)
 for fixture: Node in s.interiors.rooms[house].fixtures:
  if fixture.kind=="bed" and actor(id).position.distance_to(fixture.position)<=38:
   actor(id).position=fixture.position+Vector2(-5,-8); actor(target).position=fixture.position+Vector2(5,-8); break
 ceremony={"a":id,"b":target,"elapsed":0.0,"house":house}
 if not s.production.commit(before,"夫妻共同上床。"): return false
 s.production.close(); _show_curtain(); return true
func _show_curtain() -> void:
 if is_instance_valid(curtain): return
 curtain=Curtain.new(); curtain.romance=self; curtain.elapsed=float(ceremony.get("elapsed",0)); runtime.add_child(curtain)
 runtime.session.world.set_player_input_enabled(false); runtime.get_tree().paused=true
func finish_ceremony() -> void:
 if ceremony.is_empty(): return
 var s: Node=runtime.session; var a := str(ceremony.a); var b := str(ceremony.b)
 var woman := a if gender(a)=="female" else b; var man := b if woman==a else a
 var tribe := village(s.world.home_data(str(ceremony.house)))
 var rng := RandomNumberGenerator.new(); rng.seed=hash("birth:%d:%d"%[s.world.resource_seed,birth_counter])
 pregnancies[woman]={"father":man,"tribe":tribe,"remaining":600.0,"window":120.0,"travel":false,"clinic":"","child_gender":"female" if rng.randf()<0.5 else "male"}
 birth_counter+=1; ceremony={}; escorts.erase(a); escorts.erase(b)
 if a.begins_with("npc:") and b.begins_with("npc:"):
  weddings.pregnant(a,b)
  for id: String in [a,b]:
   var room: Node=s.interiors.rooms[actor(id).room_id]
   for f: Node in room.fixtures:
    if f.kind=="bed": actor(id).position=f.position+Vector2(-10 if gender(id)=="male" else 10,22); break
  departures[a]=true; departures[b]=true
 if is_instance_valid(actor(a)): actor(a).remove_meta("tribal_escort")
 if is_instance_valid(actor(b)): actor(b).remove_meta("tribal_escort")
 runtime.get_tree().paused=false; s.world.set_player_input_enabled(true); s.persistence.save_now(); s._set_notice(name(woman)+"已怀孕，孕期10分钟；到期后2分钟内在草药屋接生。")
func _escort(delta: float) -> void:
 var s: Node=runtime.session
 for id: String in escorts.keys():
  var follower: Node=actor(id); var r: Dictionary=escorts[id]; var leader: Node=actor(str(r.leader))
  if not is_instance_valid(follower) or not is_instance_valid(leader) or not alive(id) or not alive(str(r.leader)): escorts.erase(id); continue
  if follower==s.world.active_resident: continue
  if follower.room_id!="" and follower.room_id!=leader.room_id:
   var room: Node=s.interiors.rooms[follower.room_id]
   if runtime.workers.move(follower,room.exit_point(),delta,56):
    var at: Vector2=s.world.home_data(follower.room_id).door+Vector2(0,8)
    s.interiors.leave(follower,s.world.objects,at); s._sync_view()
  elif leader.room_id==str(r.house) and follower.room_id=="":
   var home: Dictionary=s.world.home_data(str(r.house))
   if runtime.workers.move(follower,home.door+Vector2(0,8),delta,56): s.interiors.enter(follower,home); s._sync_view()
  elif leader.room_id=="" and follower.room_id=="":
   if follower.position.distance_to(leader.position)>20: runtime.workers.move(follower,leader.position,delta,56)
func _clinic_trip(id: String, p: Dictionary, delta: float) -> void:
 var npc: Node=actor(id); var s: Node=runtime.session
 var choices := clinics(str(p.tribe))
 if choices.is_empty(): return
 choices.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.door.distance_squared_to(s.interiors.outdoor_position(npc) if npc.room_id!="" else npc.position)<b.door.distance_squared_to(s.interiors.outdoor_position(npc) if npc.room_id!="" else npc.position))
 var home: Dictionary=choices[0]; p.clinic=home.id
 if npc.room_id==home.id:
  if float(p.remaining)<=0: deliver(id)
  return
 if npc.room_id!="":
  var room: Node=s.interiors.rooms[npc.room_id]
  if runtime.workers.move(npc,room.exit_point(),delta,42): s.interiors.leave(npc,s.world.objects,s.world.home_data(npc.room_id).door+Vector2(0,8)); s._sync_view()
 elif runtime.workers.move(npc,home.door+Vector2(0,8),delta,42): s.interiors.enter(npc,home); s._sync_view()
func advance(delta: float) -> void:
 _escort(delta)
 for id: String in departures.keys():
  var npc: Node=actor(id)
  if not is_instance_valid(npc) or npc.room_id=="": departures.erase(id); continue
  var room: Node=runtime.session.interiors.rooms[npc.room_id]
  if runtime.workers.move(npc,room.exit_point(),delta,42):
   var at: Vector2=runtime.session.world.home_data(npc.room_id).door+Vector2(0,8)
   runtime.session.interiors.leave(npc,runtime.session.world.objects,at); departures.erase(id); runtime.session._sync_view()
 for id: String in pregnancies.keys():
  if not alive(id): pregnancies.erase(id); continue
  var p: Dictionary=pregnancies[id]
  var before := float(p.remaining); p.remaining=maxf(0,before-delta)
  p.window=maxf(0,float(p.window)-maxf(0,delta-before))
  if before>0 and p.remaining<=0: runtime.session._set_notice(name(id)+"孕期已满，2分钟内到草药屋接生。")
  if id.begins_with("npc:"):
   var travel := 120.0
   var choices := clinics(str(p.tribe))
   if not choices.is_empty(): travel=maxf(120,actor(id).position.distance_to(choices[0].door)/35+60)
   if p.remaining<=travel: p.travel=true; _clinic_trip(id,p,delta)
  if pregnancies.has(id) and p.remaining<=0 and p.window<=0: miscarry(id)
 weddings.advance(delta)
func busy(id: String) -> bool:
 return escorts.has(id) or departures.has(id) or bool(pregnancies.get(id,{}).get("travel",false)) or weddings.busy(id)
func deliver(id: String) -> bool:
 if delivering.has(id) or not pregnancies.has(id) or float(pregnancies[id].remaining)>0 or not alive(id): return false
 var node: Node=actor(id); var home: Dictionary=runtime.session.world.home_data(node.room_id)
 if not clinic(home) or not clinics(str(pregnancies[id].tribe)).any(func(h: Dictionary)->bool:return h.id==home.id): return false
 delivering[id]=true
 var s: Node=runtime.session; var before: Dictionary=s.inventory.export_data()
 delivering.erase(id)
 if not pregnancies.has(id): return false
 var p: Dictionary=pregnancies[id].duplicate(true)
 pregnancies.erase(id)
 var child_id: String=runtime.population.child(str(p.tribe),home.door+Vector2(0,12))
 if child_id=="": pregnancies[id]=p; return false
 runtime.population.members[child_id].gender=p.child_gender; runtime.population.members[child_id].parents=[id,p.father]; runtime.population.apply(child_id)
 var child: Node=runtime.population.node(child_id)
 s.interiors.enter(child,home); child.position=s.interiors.rooms[home.id].safe_spawn()+Vector2(12,0)
 if id.begins_with("npc:"): departures[id]=true
 weddings.complete(id,str(p.father))
 s._sync_view()
 return s.production.commit(before,"接生成功，幼童出生，5分钟在线时间后成年。")
func miscarry(id: String) -> void:
 if not pregnancies.has(id): return
 var father := str(pregnancies[id].father); pregnancies.erase(id); weddings.complete(id,father)
 if id.begins_with("npc:"):
  var npc: Node=actor(id); npc.hp=maxf(0,npc.hp-npc.max_hp*0.99); npc.refresh()
 else:
  var stats: Dictionary=runtime.session.vitals.ensure(id); stats.life=maxf(0,float(stats.life)-runtime.session.magic.skills.max_life(id)*0.99); runtime.session.vitals._sync_actors(); runtime.session.vitals.deaths_changed.emit()
 runtime.session._set_notice(name(id)+"未及时接生，已流产并扣除最大生命99%。"); runtime.session.persistence.save_now()
func options(target: String) -> Array:
 var s: Node=runtime.session; var id: String=s.world.active_resident.resident_id; var result: Array=[]
 if not friendly(target) or target==id or not alive(target): return result
 result.append(runtime.choice("romance:gift","送面包（好感＋5）","当前好感%d／100；面包送入对方背包。"%liking(id,target),true,{"bread":1}))
 if can_marry(id,target):
  for home: Dictionary in homes(): result.append(runtime.choice("romance:marry:"+str(home.id),"结婚："+str(home.name),"成年异性好感80，有床普通住房及草药屋；允许多名配偶，每对单独保存婚房。"))
 elif marriage(id,target).is_empty(): result.append(runtime.choice("romance:conditions","查看结婚条件","双方本方成年异性，好感至少80，村庄已有草药屋，选择有床普通住房；允许多名配偶。",false))
 if target in partners(id): result.append(runtime.choice("romance:invite","邀这位配偶同行回婚房","配偶会跟随，进入这对夫妻的婚房后靠近床一同上床。"))
 if target.begins_with("npc:") and adult(target):
  result.append(runtime.choice("family:host","主持NPC婚礼 / 选对象","免好感门槛，玩家选双方和婚房，消耗面包16，双方各8；之后自动入婚房、怀孕并到草药屋接生。",not homes().is_empty(),{"bread":16}))
  for partner: String in partners(target):
   if partner.begins_with("npc:"): result.append(runtime.choice("family:again:"+partner,"再次生育："+name(partner),"玩家发起后自动完成一次，不再扣婚礼面包。",weddings.can_again(target,partner)))
 return result
func status(id: String) -> String:
 if not pregnancies.has(id): return ""
 var p: Dictionary=pregnancies[id]; var left := float(p.remaining) if p.remaining>0 else float(p.window)
 return ("怀孕 " if p.remaining>0 else "接生倒计时 ")+"%02d:%02d"%[int(left)/60,int(left)%60]
func export_state() -> Dictionary: return {"weddings":weddings.export_state(),"affinity":affinity.duplicate(),"marriages":marriages.duplicate(true),"pregnancies":pregnancies.duplicate(true),"escorts":escorts.duplicate(true),"departures":departures.duplicate(),"ceremony":ceremony.duplicate(true),"birth_counter":birth_counter}
func restore(data: Dictionary) -> void:
 affinity=data.get("affinity",{}).duplicate(); marriages={}; pregnancies=data.get("pregnancies",{}).duplicate(true); escorts=data.get("escorts",{}).duplicate(true); ceremony=data.get("ceremony",{}).duplicate(true); birth_counter=maxi(0,int(data.get("birth_counter",0)))
 for key: String in data.get("marriages",{}):
  var r: Dictionary=data.marriages[key]
  if r.has("a") and r.has("b"): marriages[pair(str(r.a),str(r.b))]=r.duplicate(true)
  elif r.has("partner"): marriages[pair(key,str(r.partner))]={"a":key,"b":str(r.partner),"house":str(r.house)}
 weddings.restore(data.get("weddings",{}))
 departures=data.get("departures",{}).duplicate()
 for id: String in escorts:
  if is_instance_valid(actor(id)): actor(id).set_meta("tribal_escort",true)

func hud_status(id: String) -> String:
 if pregnancies.has(id): return status(id)
 var texts: Array[String]=[]
 for target: String in partners(id):
  if pregnancies.has(target): texts.append(name(target)+" · "+status(target))
 return " / ".join(texts)
