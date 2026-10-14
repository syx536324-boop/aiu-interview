# Exercises the actual overview after clearing, lighting and expiring distant exploration cells.
extends Node
var game: Node
var checks := 0
var failures: Array[String]=[]
var directory := ""
func _enter_tree() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
 assert(directory!="")
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)
func frames(n := 5) -> void:
 for i in range(n): await get_tree().process_frame
func run() -> void:
 game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames()
 var s: Node=game.get_node("Session")
 s.simulation.set_process(false); s.persistence.set_process(false)
 for actor: Node in s.world.residents: actor.set_physics_process(false)
 var map: Node=s.world.streamer.overview
 map.present(); map.lit.clear(); map._refresh_visibility(true)
 check(map.all_markers.size()>map.markers.entries.size(),"unexplored actors excluded")
 check(not map.markers.entries.any(func(e: Dictionary)->bool:return e.get("enemy",false)),"no red enemies in black cells")
 check(not map.captions.entries.any(func(e: Dictionary)->bool:return e.id=="forest_chief_house" or e.id=="mine"),"black locations have no captions")
 check(map.captions.entries.any(func(e: Dictionary)->bool:return e.id=="kitchen"),"lit home caption retained")
 var enemy: Node=s.combat.enemies["barbarian:chief"]
 var cell := Vector2i((enemy.position/map.FOG_CELL).floor())
 map.lit[cell]=Time.get_ticks_msec(); map._refresh_visibility()
 check(map.markers.entries.any(func(e: Dictionary)->bool:return e.get("enemy",false) and e.world_at==enemy.position),"enemy appears only after its cell lights")
 var mine_cell := Vector2i((Vector2(2070,440)/map.FOG_CELL).floor())
 map.lit[mine_cell]=Time.get_ticks_msec(); map._refresh_visibility()
 check(map.captions.entries.any(func(e: Dictionary)->bool:return e.id=="mine"),"lit mine gains name")
 map.lit[cell]=Time.get_ticks_msec()-31000; map.lit[mine_cell]=Time.get_ticks_msec()-31000
 map._process(0.2)
 check(not map.markers.entries.any(func(e: Dictionary)->bool:return e.get("enemy",false)),"expired fog hides enemies while map stays open")
 check(not map.captions.entries.any(func(e: Dictionary)->bool:return e.id=="mine"),"expired fog hides names while map stays open")
 check(map.build_count==1,"dynamic visibility does not rebuild terrain image")
 if OS.get_environment("AIU5_CAPTURE")=="true":
  await RenderingServer.frame_post_draw
  check(get_viewport().get_texture().get_image().save_png(directory+"/dark-overview.png")==OK,"capture actual map")
 map.visible=false
 print("OVERVIEW_VISIBILITY_OK checks=%d"%checks if failures.is_empty() else "OVERVIEW_VISIBILITY_FAILED "+str(failures))
 get_tree().quit(0 if failures.is_empty() else 1)
