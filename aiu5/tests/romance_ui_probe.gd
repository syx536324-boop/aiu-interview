# Drives the actual workshop buttons, spouse escort and interrupted curtain save/resume with GPU captures.
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
func shot(label: String) -> void:
 await RenderingServer.frame_post_draw
 check(get_viewport().get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"capture "+label)
func click(button: Button) -> void:
 var at := get_viewport().get_final_transform()*button.get_global_rect().get_center()
 var motion := InputEventMouseMotion.new(); motion.position=at; Input.parse_input_event(motion); await frames(2)
 var event := InputEventMouseButton.new(); event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; Input.parse_input_event(event)
 await frames(1); event=InputEventMouseButton.new(); event.position=at; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=false; Input.parse_input_event(event); await frames(2)
func load_game() -> Node:
 game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames()
 var s: Node=game.get_node("Session"); s.simulation.set_process(false); s.persistence.set_process(false); s.simulation.reset()
 for a: Node in s.world.residents: a.set_physics_process(false)
 return s
func run() -> void:
 var s: Node=await load_game(); var f: RefCounted=s.tribes.romance; var a: Node=s.world.controllable[0]; var b: Node=s.world.controllable[1]
 await shot("starter-village")
 check(s.grounds.fixtures.filter(func(n: Node)->bool:return n.kind=="workbench" and n.position.x>0 and n.position.y>0).size()==1,"starter has exactly one main-village workbench")
 s.inventory.exchange("ali",{}, {"wood":150,"stone":60,"bread":20})
 var ids: Dictionary={}
 for kind: String in ["herb_house","wood_house"]:
  var at := Vector2(720,650) if kind=="herb_house" else Vector2(870,650)
  var bench: Node=s.grounds.add_fixture({"id":"outdoors:ui:"+kind,"kind":"building_bench","at":[at.x,at.y],"size":[96,80]})
  a.position=bench.position+Vector2(0,20); ids[kind]="built:"+str(s.construction.next_id)
  check(s.construction.build(a,bench,kind),"pay "+kind); s.construction.advance(30)
 for i in range(6): check(f.gift("heya"),"gift "+str(i))
 a.position=Vector2(880,730); b.position=a.position+Vector2(10,0); s._sync_view(); s.tribes.open("person","heya"); await frames()
 var ui: Node=game.get_node("Workshop"); var selection: Button
 for button: Button in ui.buttons:
  if str(button.get_meta("recipe_id","")).begins_with("romance:marry:"): selection=button
 check(is_instance_valid(selection),"marriage home available in actual UI")
 if not is_instance_valid(selection): get_tree().quit(1); return
 await click(selection); await shot("marriage-choice"); await click(ui.confirm_button)
 check(f.spouse("ali")=="heya","mouse selection and confirmation commits marriage")
 s.production.close(); check(f.invite(),"invite spouse escort")
 var home: Dictionary=s.world.home_data(ids.wood_house)
 s.interiors.enter(a,home); s._sync_view()
 for i in range(90): f.advance(0.1)
 check(b.room_id==a.room_id,"spouse follows through actual marriage-house door")
 var bed: Node=s.interiors.rooms[home.id].fixtures.filter(func(n: Node)->bool:return n.kind=="bed")[0]
 a.position=bed.position+Vector2(0,20); check(f.bed(),"couple starts curtain")
 if f.ceremony.is_empty(): get_tree().quit(1); return
 await get_tree().create_timer(0.25,true).timeout
 var ceremony_elapsed: float=f.ceremony.elapsed
 check(s.persistence.save_now(),"save interrupted ceremony")
 game.queue_free(); get_tree().paused=false; await frames(6); s=await load_game(); f=s.tribes.romance
 check(get_tree().paused and not f.ceremony.is_empty() and f.ceremony.elapsed>=ceremony_elapsed,"disk reload resumes saved curtain while world stays paused")
 var old_selected: int=s.selected; var key := InputEventKey.new(); key.keycode=KEY_2; key.pressed=true; Input.parse_input_event(key); await frames(1)
 check(s.selected==old_selected,"role-switch keys cannot interrupt curtain")
 await get_tree().create_timer(2.5,true).timeout
 check(not get_tree().paused and f.pregnancies.has("heya") and f.pregnancies.heya.remaining==600,"restored ceremony starts one pregnancy and resumes world")
 await shot("pregnancy-hud")
 # Huge protected trees and river branches are real southern forest geography.
 s.interiors.leave(s.world.active_resident,s.world.objects,Vector2(-1640,2500)); s._sync_view(); await frames(20); await shot("southern-forest")
 check(preload("res://features/landscape/frontier.gd").protected(Rect2(-1690,2400,100,128)),"giant tree cannot be used for ordinary resource/build placement")
 var map: Node=s.world.streamer.overview; s.world.set_overview(true); await frames(); await shot("expanded-overview"); s.world.set_overview(false)
 print("ROMANCE_UI_OK checks=%d"%checks if failures.is_empty() else "ROMANCE_UI_FAILED "+str(failures)); get_tree().quit(0 if failures.is_empty() else 1)
