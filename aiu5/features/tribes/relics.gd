# Owns sacred-crystal capture, five-minute reconstruction, controllable successor chiefs and scoped defeat.
extends RefCounted
const Visual := preload("res://features/tribes/relic_visual.gd")
const Resident := preload("res://features/actors/resident.gd")
var runtime: Node
var states: Dictionary={}
var visuals: Dictionary={}
var failed := false
func start(owner_runtime: Node) -> void:
 runtime=owner_runtime
 for tribe: String in ["home","forest","barbarian","yunye"]:
  states[tribe]={"owner":"player" if tribe=="home" else tribe,"hp":200.0,"remaining":0.0,"generation":0,"chief_id":""}
  var v := Visual.new(); v.runtime=runtime; v.tribe=tribe; v.position=runtime.centers[tribe]+Vector2(0,-32)
  runtime.session.world.objects.add_child(v); visuals[tribe]=v
  runtime.session.world.points["relic:"+tribe]={"position":v.position,"radius":25.0,"label":str(runtime.names[tribe])+"圣品","action":"查看 / 重建","source":v}
func owner(tribe: String) -> String: return str(states.get(tribe,{}).get("owner","player" if tribe=="home" else tribe))
func hit(tribe: String, raw: float, attacker := "", enemy_attack := false) -> bool:
 if failed or not states.has(tribe) or raw<=0 or states[tribe].hp<=0: return false
 if owner(tribe)=="player" and not enemy_attack: return false
 states[tribe].hp=maxf(0,float(states[tribe].hp)-raw)
 if states[tribe].hp<=0:
  if tribe=="home": defeat(); return true
  var old := owner(tribe)
  states[tribe].remaining=0.0
  if old=="player":
   states[tribe].owner=tribe
   var id := str(states[tribe].chief_id)
   if id!="": runtime.session.vitals.ensure(id).life=0; runtime.session.vitals._sync_actors()
   runtime.session._set_notice(str(runtime.names[tribe])+"圣品被毁，分村失守，可返回重新占领。")
  else:
   states[tribe].owner="player"
   for id: String in runtime.population.members:
    if runtime.population.members[id].tribe==tribe:
     if runtime.population.members[id].career=="chief": runtime.population.node(id).hp=0
     runtime.population.apply(id)
   runtime.session._set_notice("已占领"+str(runtime.names[tribe])+"，靠近原圣品按E重建，需5分钟。")
  runtime.war.recall(tribe)
  for id: String in runtime.population.members:
   if runtime.population.members[id].tribe==tribe: runtime.population.apply(id)
 visuals[tribe].queue_redraw(); return true
func rebuild(tribe: String) -> bool:
 if failed or tribe=="home" or not states.has(tribe) or states[tribe].hp>0 or states[tribe].remaining>0: return false
 var s: Node=runtime.session; var actor: Node=s.world.active_resident
 if actor.position.distance_to(visuals[tribe].position)>32 or actor.room_id!="": return false
 var before: Dictionary=s.inventory.export_data()
 states[tribe].owner="player"; states[tribe].remaining=300.0
 for id: String in runtime.population.members:
  if runtime.population.members[id].tribe==tribe:
   if runtime.population.members[id].career=="chief": runtime.population.node(id).hp=0
   runtime.population.apply(id)
 return s.production.commit(before,"开始重建圣品，需5分钟在线时间。")
func advance(delta: float) -> void:
 if failed: return
 for tribe: String in states:
  if states[tribe].remaining<=0: continue
  states[tribe].remaining=maxf(0,float(states[tribe].remaining)-delta)
  if states[tribe].remaining<=0:
   states[tribe].hp=200.0; states[tribe].generation+=1
   var id := "colony_"+tribe+"_"+str(states[tribe].generation)
   states[tribe].chief_id=id; _chief(tribe,id,true)
   runtime.session._set_notice(str(runtime.names[tribe])+"圣品重建完成，新村长加入可操控角色。")
func _chief(tribe: String, id: String, fresh := false) -> void:
 var s: Node=runtime.session
 if is_instance_valid(s.magic._actor(id)): return
 var actor := Resident.new(); actor.name=id; actor.resident_id=id; actor.can_control=true; actor.role_label=str(runtime.names[tribe])+"村长"
 var sheet: Texture2D=load("res://assets/ninja_adventure/Actor/Character/ShamanLion/SpriteSheet.png")
 var route: Array[Vector2]=[runtime.centers[tribe]+Vector2(0,42)]
 actor.configure(actor.role_label,sheet,route,s.world.navigation.find_path); actor.position=route[0]
 s.world.objects.add_child(actor); s.world.residents.append(actor); s.world.controllable.append(actor); actor.add_to_group("controllable_residents")
 actor.magic_branches=s.magic.branches
 var magic: Dictionary=s.magic.ensure(id); magic.element=runtime.elements[tribe]; magic.level=9; magic.unlocked=["trunk_1","trunk_2","trunk_3","trunk_4"]; magic.skill_points=0
 s.inventory.ensure_bag(id); s.vitals.ensure(id)
 if fresh: s.vitals.ensure(id).mana=s.magic.max_mana(id)
func defeat() -> void:
 if failed: return
 failed=true
 var s: Node=runtime.session
 s.inventory.defeated=true; s.persistence.ready_to_save=false; s.persistence.restore_queued=false; s.persistence.checkpoint.clear()
 s.menu_paused=true; s.world.set_player_input_enabled(false)
 # Explicit files in the active slot only; never scan or delete neighboring save folders.
 var path := ProjectSettings.globalize_path(s.inventory.path).replace("\\","/")
 var files: Array[String]=[path,path+".tmp",path+".altar",path+".altar.tmp"]
 if path.get_file()=="state.json":
  files.append(path.get_base_dir()+"/slot.json"); files.append(path.get_base_dir()+"/names.cfg")
 for file: String in files:
  if FileAccess.file_exists(file):
   var result := DirAccess.remove_absolute(file)
   if result!=OK: s._set_notice("村落已覆灭，存档清除失败，请检查文件权限。")
 runtime.show_defeat()
 s.get_tree().paused=true
func export_state() -> Dictionary: return {"states":states.duplicate(true),"failed":failed}
func restore(data: Dictionary) -> void:
 if data.is_empty(): return
 var s: Node=runtime.session
 failed=bool(data.get("failed",false))
 for tribe: String in states:
  if data.get("states",{}).has(tribe): states[tribe]=data.states[tribe].duplicate(true)
  var id := str(states[tribe].get("chief_id",""))
  if id!="": _chief(tribe,id)
 for actor: Node in s.world.controllable.duplicate():
  if not actor.resident_id.begins_with("colony_"): continue
  var keep := states.values().any(func(r: Dictionary)->bool:return str(r.get("chief_id",""))==actor.resident_id)
  if not keep:
   if actor==s.world.active_resident: s.world.set_active(0)
   s.world.controllable.erase(actor); s.world.residents.erase(actor)
   if actor.get_parent()!=null: actor.get_parent().remove_child(actor)
   actor.queue_free()
