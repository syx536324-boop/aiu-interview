# Tests a real clinic/house, affinity gifts, two-person curtain, pregnancy windows, birth and maturation.
extends Node
var game: Node
var checks := 0
var failures: Array[String]=[]
var directory := ""
func _enter_tree() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
 OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
 OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
 OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)
func frames(n := 4) -> void:
 for i in range(n): await get_tree().process_frame
func shot(label: String) -> void:
 if OS.get_environment("AIU5_CAPTURE")!="true": return
 await RenderingServer.frame_post_draw
 check(get_viewport().get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"capture "+label)
func build(s: Node,kind: String,at: Vector2) -> String:
 var bench: Node=s.grounds.add_fixture({"id":"outdoors:test:"+kind,"kind":"building_bench","at":[at.x,at.y],"size":[96,80]})
 s.world.active_resident.position=bench.position+Vector2(0,20)
 var id := "built:"+str(s.construction.next_id)
 check(s.construction.build(s.world.active_resident,bench,kind),"material-paid construction "+kind)
 s.construction.advance(30)
 return id
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames()
 var s: Node=game.get_node("Session"); s.simulation.set_process(false); s.persistence.set_process(false)
 for a: Node in s.world.residents: a.set_physics_process(false)
 var t: Node=s.tribes; var f: RefCounted=t.romance
 check(f.liking("ali","heya")==50 and f.homes().is_empty(),"initial affinity50 and no eligible starter marriage house")
 s.inventory.bags.ali=s.inventory._sanitize_slots([])
 check(s.inventory.exchange("ali",{}, {"bread":20,"wood":200,"stone":50}),"materials inserted with normal99 stack limits")
 for i in range(6): check(f.gift("heya"),"bread affinity gift "+str(i))
 check(f.liking("heya","ali")==80,"pair has shared affinity80")
 var clinic_id := build(s,"herb_house",Vector2(800,600))
 check(f.clinic(s.world.home_data(clinic_id)) and not f.ordinary(s.world.home_data(clinic_id)),"clinic supports delivery but is excluded as wedding home")
 var home_id := build(s,"wood_house",Vector2(650,600))
 check(f.has_bed(home_id) and f.homes().any(func(h: Dictionary)->bool:return h.id==home_id),"completed ordinary bed house eligible")
 check(f.marry("heya",home_id) and f.spouse("heya")=="ali","adult heterosexual couple marries in chosen house")
 check(not f.marry("heya",home_id),"existing spouse cannot remarry")
 var a: Node=s.world.controllable[0]; var b: Node=s.world.controllable[1]
 var home: Dictionary=s.world.home_data(home_id)
 s.interiors.enter(a,home); s.interiors.enter(b,home); s._sync_view()
 var bed: Node=s.interiors.rooms[home_id].fixtures.filter(func(n: Node)->bool:return n.kind=="bed")[0]
 a.position=bed.position+Vector2(0,22); b.position=bed.position+Vector2(12,22)
 check(f.can_bed("ali") and f.bed(),"both adults use wedding bed")
 check(get_tree().paused and not f.ceremony.is_empty(),"world clocks paused during ceremony")
 await get_tree().create_timer(0.4,true).timeout; await shot("curtain-closing")
 await get_tree().create_timer(0.5,true).timeout; await shot("curtain-folds")
 await get_tree().create_timer(1.6,true).timeout
 check(f.pregnancies.has("heya") and f.pregnancies.heya.remaining==600 and not get_tree().paused,"curtain closes waitsone second opens then starts10min pregnancy")
 check(not f.can_bed("ali"),"pregnancy cannot be duplicated")
 var saved: Dictionary=f.export_state(); f.restore(saved)
 check(f.spouse("ali")=="heya" and f.pregnancies.heya.remaining==600,"marriage and pregnancy phase persist")
 f.advance(599.5); check(f.pregnancies.heya.remaining>0,"pregnancy not ready before10min")
 f.advance(0.5); check(f.pregnancies.heya.remaining==0 and f.pregnancies.heya.window==120,"two minute delivery grace starts after pregnancy")
 s.interiors.leave(a,s.world.objects,home.door+Vector2(0,8)); s.interiors.leave(b,s.world.objects,home.door+Vector2(12,8))
 s.interiors.enter(b,s.world.home_data(clinic_id)); s.world.set_active(1); s._sync_view()
 check(f.deliver("heya") and not f.pregnancies.has("heya"),"controlled mother gives birth at actual clinic")
 var child_id := "home:child:0"
 check(t.population.members.has(child_id) and t.population.members[child_id].child_left==300,"newborn is five-minute noncontrollable child")
 check(not t.population.upgrade(child_id,"civilian"),"child cannot upgrade")
 t.population.advance(299); check(t.population.members[child_id].child_left>0,"child remains young before5min")
 t.population.advance(1); check(t.population.members[child_id].child_left==0 and t.population.members[child_id].level==1 and t.population.node(child_id).max_hp==10,"child becomes career1 hp10 adult")
 # A second due pregnancy fails exactly after the full120s window and removes99% of max life directly.
 s.vitals.ensure("heya").life=10
 f.pregnancies.heya={"father":"ali","tribe":"home","remaining":0.0,"window":120.0,"travel":false,"clinic":clinic_id,"child_gender":"male"}
 f.advance(119.5); check(s.vitals.ensure("heya").life==10,"no early miscarriage")
 f.advance(0.5); check(not f.pregnancies.has("heya") and is_equal_approx(s.vitals.ensure("heya").life,0.1),"missed delivery loses99% max life")
 check(s.persistence.save_now(),"relationship child and miscarriage save")
 print("ROMANCE_OK checks=%d"%checks if failures.is_empty() else "ROMANCE_FAILED "+str(failures))
 get_tree().quit(0 if failures.is_empty() else 1)
