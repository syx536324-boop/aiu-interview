# Verifies the real title-screen new-slot path and the minimal starter before and after resume.
extends Node
var checks := 0
var failures: Array[String]=[]
var directory := ""
func _enter_tree() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS; directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)
func frames(n := 4) -> void:
 for i in range(n): await get_tree().process_frame
func click(button: Button) -> void:
 await frames(2)
 var at := get_viewport().get_final_transform()*button.get_global_rect().get_center()
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new(); e.position=at; e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed; Input.parse_input_event(e); await frames(2)
func button(menu: Node,text: String) -> Button:
 for n: Node in menu.view.root.find_children("*","Button",true,false):
  if n.text==text: return n
 return null
func run() -> void:
 var menu: Node=load("res://scenes/start.tscn").instantiate(); get_tree().root.add_child(menu); await frames()
 check(menu.game==null,"title does not start a phantom game")
 await click(button(menu,"创建新存档")); menu.view.input.text="新开局核验"; await click(menu.view.create_button); await frames()
 var s: Node=menu.game.get_node("Session"); s.simulation.flush(); s.simulation.set_process(false); s.persistence.set_process(false)
 check(s.world.settlement=="starter_v2","menu creates new minimal profile")
 check(s.world.residents.size()==3 and s.world.controllable.size()==3 and s.tribes.population.count("home")==2,"actual new-slot path has three controlled founders plus two ordinary NPCs")
 check(s.world.homes.filter(func(h: Dictionary)->bool:return h.at.x>=0 and h.at.y>=0).map(func(h: Dictionary)->String:return h.id)==["blacksmith","kitchen"],"only the smith and lowest kitchen are prebuilt in main village")
 check(not s.world.points.has("well") and not s.world.points.has("gate"),"actual new-slot has no well or animal pen")
 check(s.homestead.plots.all(func(p: Dictionary)->bool:return p.get("tribe","")!=""),"no prebuilt main-village farm")
 check(s.tribes.population.count("forest")==20 and s.tribes.population.count("barbarian")==20 and s.tribes.population.count("yunye")==20,"three tribes start at20 incl chiefs through real menu")
 check(s.tribes.relics.states.home.hp==200,"new main holy crystal has200HP")
 check(s.inventory.ensure_bag("ali").filter(func(slot: Dictionary)->bool:return not slot.is_empty()).size()==2,"founder has only two seed types")
 s.vitals.ensure("ali").thirst=7
 var slot_id: String=menu.active_slot.id; menu.pause_game(); await click(button(menu,"保存并返回开始界面")); await frames()
 check(menu.game==null and not get_tree().paused,"save returns to title normally")
 if menu.game!=null: get_tree().quit(1); return
 await click(menu.view.continue_button); menu.view._select(slot_id); await click(menu.view.load_button); await frames()
 s=menu.game.get_node("Session"); s.simulation.set_process(false); s.persistence.set_process(false)
 check(s.world.settlement=="starter_v2" and s.world.residents.size()==3 and s.vitals.ensure("ali").thirst==7,"real continue restores correct minimal slot and status")
 check(menu.library.resolve(slot_id).homes==2,"save picker accurately reports two main starter buildings")
 print("NEW_START_OK checks=%d"%checks if failures.is_empty() else "NEW_START_FAILED "+str(failures)); get_tree().quit(0 if failures.is_empty() else 1)
