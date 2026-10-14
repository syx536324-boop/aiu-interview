# Checks two starter NPCs, multi-spouse migration and real player-hosted automatic NPC birth with restart.
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
 var amount := 0
 for slot: Dictionary in s.inventory.ensure_bag(id):
  if slot.get("item","")==item: amount+=int(slot.count)
 return amount
func load_game() -> Node:
 game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames()
 var s: Node=game.get_node("Session"); s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
 for a: Node in s.world.residents: a.set_physics_process(false)
 return s
func click(button: Button) -> void:
 await frames(2)
 var at := get_viewport().get_final_transform()*button.get_global_rect().get_center()
 for pressed in [true,false]:
  var event := InputEventMouseButton.new(); event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; Input.parse_input_event(event); await frames(2)
func select(ui: Node,id: String) -> void:
 for b: Button in ui.buttons:
  if b.visible and str(b.get_meta("recipe_id",""))==id:
   ui.list.get_parent().ensure_control_visible(b); await click(b); check(ui.selected_id==id,"actual choice "+id); await click(ui.confirm_button); return
 check(false,"choice exists "+id)
func run() -> void:
 var s: Node=await load_game(); var t: Node=s.tribes; var f: RefCounted=t.romance
 var male := "npc:home:initial_male"; var female := "npc:home:initial_female"
 check(t.population.count("home")==2 and s.world.controllable.size()==3,"starter has three controlled founders plus two ordinary NPCs")
 check(f.gender(male)=="male" and f.gender(female)=="female" and f.actor(male).max_hp==10 and f.actor(female).max_hp==10,"starter NPCs are one man one woman HP10")
 check(s.inventory.ensure_bag(male).size()==9 and s.magic.ensure(male).level==1 and s.magic.ensure(male).element=="","starter NPC bag9 and no magic")
 s.inventory.exchange("ali",{}, {"wood":250,"stone":60,"bread":60})
 var houses: Array[String]=[]; var clinic := ""
 for kind: String in ["herb_house","wood_house","wood_house"]:
  var at := Vector2(1000+houses.size()*150,800)
  if kind=="herb_house": at=Vector2(900,650)
  var bench: Node=s.grounds.add_fixture({"id":"outdoors:wedding:"+str(s.construction.next_id),"kind":"building_bench","at":[at.x,at.y],"size":[96,80]})
  s.world.active_resident.position=bench.position+Vector2(0,20); var id := "built:"+str(s.construction.next_id)
  check(s.construction.build(s.world.active_resident,bench,kind),"paid "+kind); s.construction.advance(30)
  if kind=="herb_house": clinic=id
  else: houses.append(id)
 f.affinity[f.pair("ali","heya")]=80; f.affinity[f.pair("ali",female)]=80
 check(f.marry("heya",houses[0]) and f.marry(female,houses[1]),"player can marry two different partners")
 check(f.partners("ali").size()==2 and f.marriage("ali","heya").house!=f.marriage("ali",female).house,"each pair retains its own marriage house")
 check(not f.marry("heya",houses[1]),"same pair cannot repeat wedding")
 # NPC woman already married to the player may also marry the starter male, without affinity80.
 check(f.liking(male,female)==50,"NPC pair begins at affinity50")
 var held_bag: Array=s.inventory.ensure_bag(male).duplicate(true)
 var full_bag: Array=[]
 for i in range(9): full_bag.append({"item":"wood","count":99})
 s.inventory.bags[male]=s.inventory._sanitize_slots(full_bag,9)
 var held_bread := count(s,"ali","bread")
 check(not f.weddings.host(male,female,houses[0]) and count(s,"ali","bread")==held_bread and f.marriage(male,female).is_empty(),"full NPC bag rejects wedding and refunds all16 bread")
 s.inventory.bags[male]=held_bag
 var real_path: String=s.inventory.path; var blocked := directory+"/blocked-wedding"; DirAccess.make_dir_recursive_absolute(blocked); s.inventory.path=blocked
 check(not f.weddings.host(male,female,houses[0]),"failed wedding save rejected")
 s.inventory.path=real_path
 check(count(s,"ali","bread")==held_bread and count(s,male,"bread")==0 and count(s,female,"bread")==0 and f.marriage(male,female).is_empty() and f.weddings.jobs.is_empty(),"failed wedding save rolls back both gifts relationship and automatic job")
 var home: Dictionary=s.world.home_data(houses[0]); f.actor(male).position=home.door+Vector2(-15,40); f.actor(female).position=home.door+Vector2(15,40)
 var before := count(s,"ali","bread"); t.open("npc","home:initial_male"); var ui: Node=game.get_node("Workshop"); await frames()
 await select(ui,"family:host"); await select(ui,"family:pick:"+female)
 if OS.get_environment("AIU5_CAPTURE")=="true":
  await RenderingServer.frame_post_draw; check(get_viewport().get_texture().get_image().save_png(directory+"/npc-wedding-house.png")==OK,"capture hosted wedding house choices")
 await select(ui,"family:house:"+houses[0])
 check(count(s,"ali","bread")==before-16 and count(s,male,"bread")==8 and count(s,female,"bread")==8,"hosted wedding spends16 and gives exactly8 to each NPC")
 check(f.partners(female).size()==2 and f.weddings.jobs.has(f.pair(male,female)),"NPC polygamy and one automatic wedding job created")
 check(s.persistence.save_now(),"hosted wedding before walk saved")
 game.queue_free(); await frames(5); s=await load_game(); t=s.tribes; f=t.romance
 check(f.partners("ali").size()==2 and f.weddings.jobs.has(f.pair(male,female)),"multiple marriages and queued NPC wedding survive real restart")
 for i in range(500):
  if not f.ceremony.is_empty(): break
  f.advance(0.1)
  if i%5==0: await get_tree().physics_frame
 check(not f.ceremony.is_empty() and f.actor(male).room_id==houses[0] and f.actor(female).room_id==houses[0],"NPC couple actually enters the house and automatically starts wedding curtain")
 if f.ceremony.is_empty(): print(JSON.stringify(f.weddings.jobs)); get_tree().quit(1); return
 await get_tree().create_timer(2.5,true).timeout
 check(f.pregnancies.has(female) and f.pregnancies[female].remaining==600,"automatic wedding starts exactly one pregnancy")
 # Move the clock naturally through all online seconds; NPC must walk to clinic without a manual deliver call.
 for i in range(1250):
  f.advance(0.5)
  if i%10==0: await get_tree().physics_frame
  if not f.pregnancies.has(female): break
 check(not f.pregnancies.has(female) and t.population.members.has("home:child:0"),"NPC woman automatically reaches clinic and gives birth")
 if t.population.members.has("home:child:0"): check(t.population.node("home:child:0").room_id==clinic,"automatic newborn is inside herb clinic")
 check(f.weddings.jobs.is_empty(),"automatic cycle ends after one birth")
 f.advance(1500); check(not f.pregnancies.has(female) and t.population.next_child==1,"NPC marriage does not loop into automatic repeat pregnancies")
 check(f.weddings.again(male,female) and f.weddings.jobs.has(f.pair(male,female)),"player can request another single cycle later")
 # Older one-spouse snapshots migrate into pair records without changing partners/home.
 var state: Dictionary=f.export_state(); state.marriages={"ali":{"partner":"heya","house":houses[0]},"heya":{"partner":"ali","house":houses[0]}}
 f.restore(state); check(f.partners("ali")==["heya"] and f.marriage("ali","heya").house==houses[0],"old monogamous marriage snapshot migrates safely")
 print("NPC_WEDDING_OK checks=%d"%checks if failures.is_empty() else "NPC_WEDDING_FAILED "+str(failures)); get_tree().quit(0 if failures.is_empty() else 1)
