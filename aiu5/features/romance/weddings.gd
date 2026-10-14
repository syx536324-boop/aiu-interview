# Owns player-hosted NPC pairing and one automatic wedding/pregnancy cycle per request.
extends RefCounted
var romance_ref: WeakRef
var romance: RefCounted:
 get: return romance_ref.get_ref() if romance_ref!=null else null
 set(value): romance_ref=weakref(value)
var jobs: Dictionary={}
var staging := false
func eligible(a: String,b: String) -> bool:
 return a.begins_with("npc:") and b.begins_with("npc:") and romance.compatible(a,b)
func candidates(a: String) -> Array[String]:
 var people: Array[String]=[]
 for id: String in romance.runtime.population.members:
  var b := "npc:"+id
  if eligible(a,b) and romance.marriage(a,b).is_empty(): people.append(b)
 return people
func host(a: String,b: String,house: String) -> bool:
 if not eligible(a,b) or not romance.marriage(a,b).is_empty() or not romance.homes().any(func(h: Dictionary)->bool:return h.id==house): return false
 var s: Node=romance.runtime.session; var before: Dictionary=s.inventory.export_data()
 if not s.inventory.exchange(s.world.active_resident.resident_id,{"bread":16},{}) or not s.inventory.exchange(a,{}, {"bread":8}) or not s.inventory.exchange(b,{}, {"bread":8}):
  s.inventory.apply_data(before); s._set_notice("需要面包16，双方背包各需容纳8个；婚礼未完成。"); return false
 romance.marriages[romance.pair(a,b)]={"a":a,"b":b,"house":house}
 jobs[romance.pair(a,b)]={"a":a,"b":b,"house":house,"phase":"travel"}
 if not s.production.commit(before,"婚礼已主持，双方各收到8个面包，将自动前往婚房并完成一次生育流程。"): return false
 s.production.close(); return true
func can_again(a: String,b: String) -> bool:
 var record: Dictionary=romance.marriage(a,b)
 if record.is_empty() or not eligible(a,b) or jobs.has(romance.pair(a,b)) or not romance.has_bed(str(record.house)): return false
 var woman := a if romance.gender(a)=="female" else b
 var tribe: String=romance.village(romance.runtime.session.world.home_data(str(record.house)))
 return not romance.pregnancies.has(woman) and not romance.clinics(tribe).is_empty() and (tribe=="home" or romance.runtime.population.count(tribe)+romance.reserved(tribe)<30)
func again(a: String,b: String) -> bool:
 if not can_again(a,b): return false
 var s: Node=romance.runtime.session; var before: Dictionary=s.inventory.export_data()
 jobs[romance.pair(a,b)]={"a":a,"b":b,"house":str(romance.marriage(a,b).house),"phase":"travel"}
 return s.production.commit(before,"已发起这对NPC夫妻的一次生育流程。")
func busy(id: String) -> bool:
 return jobs.values().any(func(r: Dictionary)->bool:return r.phase=="travel" and id in [r.a,r.b])
func _enter(id: String,home: Dictionary,delta: float) -> bool:
 var npc: Node=romance.actor(id); var s: Node=romance.runtime.session
 if npc.room_id==home.id: return true
 if npc.room_id!="":
  var room: Node=s.interiors.rooms[npc.room_id]
  if romance.runtime.workers.move(npc,room.exit_point(),delta,42): s.interiors.leave(npc,s.world.objects,s.world.home_data(npc.room_id).door+Vector2(0,8)); s._sync_view()
 elif romance.runtime.workers.move(npc,home.door+Vector2(0,8),delta,42):
  s.interiors.enter(npc,home); npc.position+=Vector2(-9 if romance.gender(id)=="male" else 9,0); s._sync_view()
 return npc.room_id==home.id
func advance(delta: float) -> void:
 if staging or not romance.ceremony.is_empty(): return
 for key: String in jobs.keys():
  var r: Dictionary=jobs[key]
  if not eligible(str(r.a),str(r.b)): jobs.erase(key); continue
  if r.phase!="travel": continue
  var woman := str(r.a) if romance.gender(str(r.a))=="female" else str(r.b)
  if romance.pregnancies.has(woman) or romance.departures.has(r.a) or romance.departures.has(r.b): continue
  var home: Dictionary=romance.runtime.session.world.home_data(str(r.house))
  if home.is_empty() or not romance.ordinary(home) or not romance.has_bed(str(r.house)): continue
  var ready_a := _enter(str(r.a),home,delta); var ready_b := _enter(str(r.b),home,delta)
  if not ready_a or not ready_b: continue
  var bed: Node=romance.runtime.session.interiors.rooms[r.house].fixtures.filter(func(f: Node)->bool:return f.kind=="bed")[0]
  ready_a=romance.runtime.workers.move(romance.actor(str(r.a)),bed.position+Vector2(-10,20),delta,32)
  ready_b=romance.runtime.workers.move(romance.actor(str(r.b)),bed.position+Vector2(10,20),delta,32)
  if ready_a and ready_b and romance.can_bed(str(r.a),str(r.b)):
   staging=true; var started: bool=romance.start_ceremony(str(r.a),str(r.b)); staging=false
   if started: return
func pregnant(a: String,b: String) -> void:
 if jobs.has(romance.pair(a,b)): jobs[romance.pair(a,b)].phase="pregnant"
func complete(woman: String,man: String) -> void: jobs.erase(romance.pair(woman,man))
func export_state() -> Dictionary: return jobs.duplicate(true)
func restore(data: Dictionary) -> void: jobs=data.duplicate(true); staging=false
