# Verifies the new starter, NPC material progression and baseline tribal state with isolated data.
extends Node
var checks := 0
var failures: Array[String]=[]
var game: Node
func _enter_tree() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 var directory := OS.get_environment("AIU5_PROBE_DIRECTORY")
 OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
 OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
 OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)
func frames(n := 4) -> void:
 for i in range(n): await get_tree().process_frame
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames()
 var s: Node=game.get_node("Session"); s.simulation.set_process(false); s.persistence.set_process(false)
 for actor in s.world.residents: actor.set_physics_process(false)
 var t: Node=s.tribes
 check(s.world.settlement=="starter_v2","new starter profile")
 check(s.tribes.population.count("home")==2,"two initial home NPCs in addition to the controlled founders")
 check(s.world.controllable.size()==3 and s.world.residents.size()==3,"only three local founding residents")
 check(s.world.BOUNDS.size==Vector2(7200,6400),"double map area")
 check(not s.world.points.has("well") and not s.world.points.has("trough"),"no starter well or animal pens")
 check(s.world.homes.filter(func(h: Dictionary)->bool:return h.at.x>=0 and h.at.y>=0).size()==2,"only starter kitchen and smith")
 check(s.homestead.plots.all(func(p: Dictionary)->bool:return p.get("tribe","")!=""),"no free starter farm")
 for tribe: String in ["forest","barbarian","yunye"]:
  check(t.population.count(tribe)==20,"twenty including chief "+tribe)
  check(t.relics.states[tribe].hp==200,"holy crystal200 "+tribe)
 check(t.relics.states.home.hp==200,"player crystal200")
 check(s.inventory.ensure_bag("npc:forest:0").size()==9,"nine NPC bag slots")
 check(s.production.RECIPES.rope.cost=={"cloth":3},"rope recipe")
 check(s.production.RECIPES.fence_gate.cost=={"wood":4},"gate recipe")
 check(t.population.members["forest:0"].level==1 and t.population.node("forest:0").hp==10,"civilian begins at career1 hp10")
 check(s.magic.ensure("npc:forest:0").level==1 and s.magic.ensure("npc:forest:0").element=="","ordinary npc no magic")
 # Capture and upgrade a real surviving civilian, consuming only player materials.
 t.relics.hit("forest",200)
 check(t.population.friendly("forest:0"),"capture survivor joins player")
 check(not t.population.upgrade("forest:0","civilian"),"insufficient upgrade materials refuses")
 check(s.inventory.exchange("ali",{}, {"bread":20,"wood":6,"hoe":1,"stone":3,"crude_iron":1}),"provide only isolated materials")
 check(t.population.upgrade("forest:0","civilian") and t.population.node("forest:0").max_hp==17,"career2 hp17")
 check(t.population.upgrade("forest:0","civilian") and t.population.node("forest:0").max_hp==24,"career3 hp24")
 check(t.population.specialize("forest:0","civilian"),"career3 choose civilian")
 check(t.population.upgrade("forest:0","farmer") and t.population.node("forest:0").max_hp==29,"farmer4 hp29 exact materials")
 check(s.persistence.save_now(),"whole domains persist")
 check(not t.relics.failed,"player holy remains intact")
 print("TRIBES_PHASE_OK checks=%d"%checks if failures.is_empty() else "TRIBES_PHASE_FAILED "+str(failures))
 get_tree().quit(0 if failures.is_empty() else 1)
