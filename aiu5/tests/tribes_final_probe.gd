# Exercises actual arrows, raid limits, recall, indoor birth, NPC travel and disk-backed reloads.
extends Node
var game: Node
var checks := 0
var failures: Array[String]=[]
var directory := ""
func _enter_tree() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS; directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
 OS.set_environment("AIU5_STATE_PATH",directory+"/state.json"); OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg"); OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)
func frames(n := 4) -> void:
 for i in range(n): await get_tree().process_frame
func count(s: Node,id: String,item: String) -> int:
 var total := 0
 for slot: Dictionary in s.inventory.ensure_bag(id):
  if slot.get("item","")==item: total+=int(slot.count)
 return total
func load_game() -> Node:
 game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames()
 var s: Node=game.get_node("Session"); s.simulation.set_process(false); s.persistence.set_process(false)
 for a: Node in s.world.residents: a.set_physics_process(false)
 return s
func run() -> void:
 var s: Node=await load_game(); var t: Node=s.tribes; var f: RefCounted=t.romance
 check(s.combat.enemies.size()==62 and t.population.count("home")==2,"new start has three20-member tribes plus two home NPCs and no unassigned raiders")
 var map: Node=s.world.streamer.overview; map.present(); map.lit.clear(); map._refresh_visibility(true)
 check(not map._building_names().any(func(r: Dictionary)->bool:return r.id in ["well","pig_pen","cow_shed"]),"minimal start excludes nonexistent facility captions")
 t.mine_visited=true; t.mine_marked=true; map._refresh_visibility(true)
 check(map.get_node("PermanentMineLabel").visible,"explicitly marked mine remains above dark fog")
 map.visible=false
 # A friendly NPC returns to its own settlement on recall.
 t.relics.hit("forest",200); var id := "forest:12"; var unit: Node=t.population.node(id)
 unit.position=t.centers.forest+Vector2(140,90); t.war.orders[id]="barbarian"; t.war.recall()
 check(t.war.orders.get(id)=="return","recall creates an actual return order")
 var gap: float=unit.position.distance_to(t.centers.forest+Vector2(0,64))
 t.war.cooldowns[id]=0
 for i in range(10): t.war._act(id,unit,0.2)
 check(unit.position.distance_to(t.centers.forest+Vector2(0,64))<gap,"recalled NPC moves toward home")
 # Raid authorization starts at founder magic5 and limits one finite squad to four.
 t.war.orders.clear(); s.magic.ensure("ali").level=4; t.war.raid_left=0; t.war.advance(0.1)
 check(t.war.orders.is_empty(),"no village raid before founder level5")
 s.magic.ensure("ali").level=5; t.war.advance(0.1)
 check(t.war.orders.size()==4 and t.war.orders.values().all(func(v: String)->bool:return v=="home"),"level5 creates one raid of four real fighters")
 t.war.advance(301); check(t.war.orders.size()==4,"active raid prevents another simultaneous squad")
 check(not t.war.hostile("forest"),"captured forest is friendly")
 t.war.orders.clear()
 # All three actual archer ranks spend one arrow and deal their configured damage.
 s.world.active_resident.position=Vector2(1000,620); s.world.camera.position=s.world.active_resident.position; s._sync_view()
 id="barbarian:12"; unit=t.population.node(id)
 if unit.get_parent()==null: s.world.objects.add_child(unit)
 for rank in [3,4,5]:
  t.population.members[id].level=rank; t.population.apply(id); unit.position=s.world.active_resident.position+Vector2(70,0)
  s.vitals.ensure("ali").life=10; s.vitals._sync_actors(); await get_tree().physics_frame
  var arrows := count(s,unit.resident_id,"arrow"); t.war.cooldowns[id]=0; t.war._act(id,unit,0.01)
  check(count(s,unit.resident_id,"arrow")==arrows-1,"archer%d consumes an arrow"%rank)
  await get_tree().create_timer(0.35).timeout
  check(is_equal_approx(s.vitals.ensure("ali").life,10-float({3:1,4:3,5:5}[rank])),"archer%d physical arrow damage"%rank)
  var after := count(s,unit.resident_id,"arrow"); t.war._act(id,unit,0.01)
  check(count(s,unit.resident_id,"arrow")==after,"archer%d one-second cooldown"%rank)
 s.vitals.ensure("ali").life=10; s.vitals._sync_actors()
 # NPC mother actually walks through the clinic door, delivers indoors and then leaves.
 var clinic_id := "settlement:forest:herbs"; var home: Dictionary=s.world.home_data(clinic_id)
 var mother := "forest:1"; var npc: Node=t.population.node(mother); t.population.members[mother].gender="female"; t.population.apply(mother)
 npc.position=home.door+Vector2(0,48); npc.navigation=PackedVector2Array()
 f.pregnancies[npc.resident_id]={"father":"ali","tribe":"forest","remaining":1.0,"window":120.0,"travel":false,"clinic":"","child_gender":"female"}
 for i in range(80): f.advance(0.1)
 check(not f.pregnancies.has(npc.resident_id),"NPC auto-walks and delivers within the window")
 var child := "forest:child:0"; check(t.population.members.has(child),"NPC birth creates child")
 if not t.population.members.has(child): get_tree().quit(1); return
 check(t.population.node(child).room_id==clinic_id and t.population.members[child].gender=="female","baby born inside the herb house with saved gender")
 check(npc.room_id=="","NPC mother exits clinic after birth")
 # Persist pregnancy, newborn, marked mine and career in the real disk save and recreate main scene.
 f.pregnancies.heya={"father":"ali","tribe":"home","remaining":431.25,"window":120.0,"travel":false,"clinic":"","child_gender":"male"}
 f.affinity[f.pair("ali","heya")]=85
 check(s.persistence.save_now(),"full disk state saved")
 var young: float=t.population.members[child].child_left
 game.queue_free(); await frames(6); s=await load_game(); t=s.tribes; f=t.romance
 check(is_equal_approx(float(f.pregnancies.heya.remaining),431.25),"pregnancy does not advance across restart")
 check(f.liking("ali","heya")==85 and t.mine_marked,"affinity and permanent mine marker survive restart")
 check(t.population.node(child).room_id==clinic_id and is_equal_approx(float(t.population.members[child].child_left),young),"newborn room and online growth survive restart")
 check(s.inventory.ensure_bag("npc:"+child).size()==9 and s.magic.ensure("npc:"+child).level==1,"newborn keeps nine-slot bag and no awakened magic")
 t.population.advance(young)
 for i in range(150): t.population.advance(0.1)
 check(t.population.members[child].child_left==0 and t.population.node(child).room_id=="","adult child can leave clinic normally")
 # Colony smith is functional and has a furnace independent of the starter smith.
 var actor: Node=s.world.active_resident; s.interiors.enter(actor,s.world.home_data("settlement:forest:smith")); s._sync_view()
 check(s.production.is_smith(),"captured colony smith supports forge recipes")
 s.production.furnace_state().remaining=12
 check(s.production.smith_smelting.remaining==0,"colony forge does not borrow starter furnace products")
 print("TRIBES_FINAL_OK checks=%d"%checks if failures.is_empty() else "TRIBES_FINAL_FAILED "+str(failures))
 get_tree().quit(0 if failures.is_empty() else 1)
