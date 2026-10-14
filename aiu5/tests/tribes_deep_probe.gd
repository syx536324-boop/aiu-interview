# Exercises farming, finite mining, material limits, real barrier combat and defeat scope in isolated slots.
extends Node
var game: Node
var checks := 0
var failures: Array[String]=[]
var directory := ""
func _enter_tree() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
 DirAccess.make_dir_recursive_absolute(directory+"/current")
 OS.set_environment("AIU5_STATE_PATH",directory+"/current/state.json")
 OS.set_environment("AIU5_PROFILE_PATH",directory+"/current/names.cfg")
 OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)
func frames(n := 4) -> void:
 for i in range(n): await get_tree().process_frame
func physics() -> void:
 await get_tree().physics_frame; await get_tree().physics_frame
func count(s: Node,id: String,item: String) -> int:
 var value := 0
 for slot: Dictionary in s.inventory.ensure_bag(id):
  if slot.get("item","")==item: value+=int(slot.count)
 return value
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames()
 var s: Node=game.get_node("Session"); s.simulation.set_process(false); s.persistence.set_process(false)
 for a: Node in s.world.residents: a.set_physics_process(false)
 var t: Node=s.tribes
 t.relics.hit("forest",200)
 # Farmer performs actual inventory/farm operations, waiting between individual stages.
 var id := "forest:0"; var npc: Node=t.population.node(id)
 t.population.members[id].career="farmer"; t.population.members[id].level=4; t.population.apply(id)
 s.homestead.plots=[{"x":700.0,"y":600.0,"w":16.0,"h":16.0,"age":0.0,"dry":true,"crop":"","growth":0.0}]; s.homestead.plot_stamps.clear(); s.homestead.refresh()
 npc.position=Vector2(708,608)
 if npc.get_parent()==null: s.world.objects.add_child(npc)
 s.inventory.bags[npc.resident_id]=s.inventory._sanitize_slots([{"item":"water_bucket","count":1},{"item":"seeds","count":5}],9)
 t.workers.advance(0.5)
 check(not s.homestead.plots[0].dry and count(s,npc.resident_id,"bucket")==1,"farmer irrigates from own bag")
 t.workers.advance(14.9)
 check(s.homestead.plots[0].crop=="","farmer respects15s delay")
 t.workers.advance(0.1)
 check(s.homestead.plots[0].crop=="wheat" and count(s,npc.resident_id,"seeds")==4,"farmer seeds after full interval")
 s.homestead.plots[0].growth=480; s.homestead.refresh(); t.workers.advance(15)
 check(count(s,npc.resident_id,"wheat")==1 and count(s,npc.resident_id,"seeds")==6,"farmer harvests crop1 seeds2 into own bag")
 var full: Array=[]
 for i in range(9): full.append({"item":"iron_knife","count":1})
 s.inventory.bags[npc.resident_id]=s.inventory._sanitize_slots(full,9)
 s.homestead.plots[0].crop="wheat"; s.homestead.plots[0].growth=480; s.homestead.refresh(); t.workers.advance(15)
 check(s.homestead.plots[0].mature,"full9-slot farmer leaves harvest intact")
 # Miners start a timed cycle only on arriving at a real finite vein.
 var miner: Node=t.population.node("forest:1")
 t.population.members["forest:1"].career="miner"; t.population.members["forest:1"].level=4; t.population.apply("forest:1")
 t.mine_visited=true; t.mine_marked=true
 t.workers.jobs["forest:1"]={"kind":"stone","left":0.0,"status":"测试"}
 miner.position=s.mining.DOOR+Vector2(0,10)
 t.workers.advance(0.5)
 check(miner.room_id=="mine","miner physically enters marked mine")
 var ore: Dictionary={}
 for r: Dictionary in s.mining.underground_records:
  if r.kind=="stone": ore=r; break
 miner.position=ore.at+Vector2(0,15); t.workers.advance(0.5)
 check(count(s,miner.resident_id,"stone")==0,"miner cannot instantly generate stone")
 t.workers.advance(9.9); check(count(s,miner.resident_id,"stone")==0,"stone4 waits10s")
 t.workers.advance(0.1); check(count(s,miner.resident_id,"stone")==1,"stone4 gainsone after10s")
 t.workers.advance(10); t.workers.advance(10)
 check(count(s,miner.resident_id,"stone")==3 and s.mining.progress[ore.id]==3,"mining shares finite3-unit vein")
 check(s.persistence.save_now(),"NPC inside cave saves safely")
 var snapshot: Dictionary=s.inventory.export_data(); s.inventory.apply_data(snapshot); s.persistence.restore_session(snapshot.session)
 miner=t.population.node("forest:1")
 check(miner.room_id=="mine" and count(s,miner.resident_id,"stone")==3,"indoor miner room and nine-slot inventory restore")
 # Actual rope transactions; third rope refuses and untying returns exactly one.
 s.world.active_resident.position=Vector2(700,800); s.world.streamer.ensure_actor(s.world.active_resident)
 s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"rope","count":3},{"item":"wood_sword","count":1}])
 var animals: Array=[]
 for i in range(3): animals.append(s.livestock._spawn("rope-test:"+str(i),"cow" if i==0 else "sheep","female",300,Vector2(710+i*5,800),Rect2(680,770,100,80)))
 check(s.wildlife.tie(animals[0]) and s.wildlife.tie(animals[1]),"two ropes bind two animals")
 check(not s.wildlife.tie(animals[2]) and count(s,"ali","rope")==1,"third rope is refused without consumption")
 check(s.wildlife.tie(animals[0]) and count(s,"ali","rope")==2,"untying returns one rope")
 # Real right-clicked timber attack, health persistence and collapse.
 check(s.magic.equip_weapon("ali","wood_sword"),"equip actual wooden sword")
 var actor: Node=s.world.active_resident; actor.position=Vector2(900,704); s.world.streamer.ensure_actor(actor)
 var gate: Node=s.grounds.add_fixture({"id":"outdoors:testgate","kind":"fence_gate","at":[912,694],"size":[24,12]})
 await physics(); s.combat.cooldown=0
 check(s.combat.attack_clicked(gate.visual_bounds().get_center()) and gate.hp==9,"right click damages wooden gate")
 check(s.combat.hit_structure(gate.get_node("FurnitureBody"),9,"ali"),"gate destruction transaction")
 check(not s.grounds.fixtures.has(gate),"gate destroyed at0hp")
 # Sacred crystal rebuild creates only one controllable successor at300online seconds.
 actor.position=t.relics.visuals.forest.position; s.world.streamer.ensure_actor(actor)
 check(t.relics.rebuild("forest"),"captured crystal rebuild starts")
 t.relics.advance(299); check(s.world.controllable.size()==3,"no successor before5minutes")
 t.relics.advance(1); check(s.world.controllable.size()==4 and t.relics.states.forest.hp==200,"successor joins after5minutes")
 check(t.population.count("forest")==20,"successor included in population")
 check(s.magic.ensure(str(t.relics.states.forest.chief_id)).element=="wood","successor keeps original element")
 # Level milestones add finite recruits to each surviving tribe, with a30 cap and no corpse refill.
 s.magic.ensure("ali").level=20; t.population.advance(0)
 for tribe: String in ["forest","barbarian","yunye"]: check(t.population.count(tribe)==30,"level growth capped30 "+tribe)
 t.population.node("barbarian:growth:2").hp=0; t.population.node("barbarian:growth:2").refresh(); t.population.advance(0)
 check(t.population.count("barbarian")==29,"dead member is not automatically replaced")
 # Only active slot files are deleted on main-crystal defeat; an adjacent slot remains byte-identical.
 var other_path := directory+"/other/state.json"; DirAccess.make_dir_recursive_absolute(directory+"/other")
 var file := FileAccess.open(other_path,FileAccess.WRITE); file.store_string("other-slot-sentinel"); file.close()
 check(s.persistence.save_now() and FileAccess.file_exists(s.inventory.path+".altar"),"current autosave and altar exist before defeat")
 t.relics.hit("home",200,"barbarian",true)
 check(t.relics.failed and not FileAccess.file_exists(s.inventory.path) and not FileAccess.file_exists(s.inventory.path+".altar"),"main crystal clears only current gameplay saves")
 check(FileAccess.get_file_as_string(other_path)=="other-slot-sentinel","neighbor slot preserved")
 check(not s.persistence.save_now() and not s.persistence.restore_checkpoint() and s.inventory.save_state()!=OK,"defeat cannot autosave or rewind into old village")
 get_tree().paused=false
 print("TRIBES_DEEP_OK checks=%d"%checks if failures.is_empty() else "TRIBES_DEEP_FAILED "+str(failures))
 get_tree().quit(0 if failures.is_empty() else 1)
