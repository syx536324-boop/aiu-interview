# Samples deterministic first-spawn probability and verifies shared rope limits, persistence and legacy fences.
extends Node
var checks := 0
var failures: Array[String]=[]
var directory := ""
func _enter_tree() -> void:
 directory=OS.get_environment("AIU5_PROBE_DIRECTORY"); OS.set_environment("AIU5_STATE_PATH",directory+"/state.json"); OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg"); OS.set_environment("AIU5_WORLD_PROFILE","expanded")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)
func run() -> void:
 var game: Node=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game)
 await get_tree().process_frame
 var s: Node=game.get_node("Session"); s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
 var w: Node=s.wildlife
 # Separate the random first-spawn decision from obstacles; every populated cell is still bounded to two.
 var trials := 0; var successful := 0
 for y in range(-6,18):
  for x in range(-9,18):
   var cell := Vector2i(x,y); var key := str(x)+":"+str(y)
   if w.generated.has(key): continue
   trials+=1
   var rng := RandomNumberGenerator.new(); rng.seed=s.world.resource_seed^((x+131)*73856093)^((y+131)*19349663)
   if rng.randf()<0.3: successful+=1
   w._generate(cell)
 var probability := float(successful)/trials
 check(probability>0.25 and probability<0.35,"first-cell herd decision samples around30%%: %.3f over%d"%[probability,trials])
 var cell_counts: Dictionary={}; var wild: Array=[]
 for animal: Node in s.livestock.animals:
  if not animal.animal_id.begins_with("wild:"): continue
  var key: String=animal.animal_id.rsplit(":",true,1)[0]; cell_counts[key]=int(cell_counts.get(key,0))+1; wild.append(animal)
  check(animal.species in ["cow","pig","sheep"],"wild animal species"+animal.animal_id)
 check(cell_counts.values().all(func(value: int)->bool:return value<=2),"cow pig sheep combined max2 per cell")
 var old_count: int=s.livestock.animals.size(); w._generate(Vector2i(-3,3)); w._generate(Vector2i(-3,3))
 check(old_count==s.livestock.animals.size(),"revisiting does not add herds")
 var animal: Node=wild[0]; s.world.active_resident.position=animal.position; s.inventory.exchange("ali",{}, {"rope":3})
 check(w.tie(animal),"tie one rope")
 if animal.get_parent()==null: s.world.objects.add_child(animal)
 animal.position=Vector2(1000,2000); s.world.active_resident.position=Vector2(1100,2000); s.world.active_resident.set_physics_process(false)
 var old_at: Vector2=animal.position
 for i in range(60): w.advance(0.05); await get_tree().physics_frame
 check(animal.position.distance_to(old_at)>30,"live animal follows rope waypoints rather than stopping18pixels from each")
 var before: Dictionary=s.inventory.export_data(); s.inventory.apply_data(before); s.persistence.restore_session(before.session)
 check(w.tethers.has(animal.animal_id) and s.livestock.find_animal(animal.animal_id).has_meta("tether_target"),"tether owner and animal target survive full restore")
 s.world.active_resident.position=animal.position; check(w.tie(animal),"untying refunds rope")
 # Native fences in old saves also use10HP and retain damage in the same save snapshot.
 var fence: Node=s.world.legacy_barriers.values()[0]
 check(fence.hp==10,"legacy timber fence starts at10HP")
 fence.damage(6); var saved: Dictionary=s.inventory.export_data(); fence.damage(4)
 check(fence.hp==0 and fence.body.collision_layer==0,"legacy timber fence can be destroyed physically")
 s.inventory.apply_data(saved); s.persistence.restore_session(saved.session)
 check(fence.hp==4 and fence.body.collision_layer==1,"legacy fence HP and collider restored")
 fence.damage(4); check(s.persistence.save_now(),"destroyed legacy fence saves")
 check(JSON.parse_string(FileAccess.get_file_as_string(s.inventory.path)).session.legacy_fences.values().has(0.0),"destroyed native fence is stored in disk save")
 print("WILDLIFE_OK checks=%d trials=%d probability=%.3f"%[checks,trials,probability] if failures.is_empty() else "WILDLIFE_FAILED "+str(failures)); get_tree().quit(0 if failures.is_empty() else 1)
