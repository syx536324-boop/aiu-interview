# Verifies real orchard transactions, migration, collision footprints and online-only timers in isolation.
extends Node
var s: Node
var checks := 0
var failures: Array[String]=[]
var directory := ""
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func apples(id: String) -> int:
	var count := 0
	for slot: Dictionary in s.inventory.ensure_bag(id):
		if slot.get("item","")=="apple": count+=int(slot.count)
	return count
func spot(actor: Node) -> bool:
	actor.facing=0
	for y in range(1000,2000,96):
		for x in range(900,1800,96):
			actor.position=Vector2(x,y)
			if s.orchard.placement_error((actor.position+Vector2(0,48)).snapped(Vector2(8,8)))=="": return true
	return false
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	directory=OS.get_environment("AIU5_BENCH_DIR");assert(directory!="")
	DirAccess.make_dir_recursive_absolute(directory)
	for pair: Array in [["AIU5_STATE_PATH","state.json"],["AIU5_PROFILE_PATH","names.cfg"],["AIU5_SAVES_DIR","slots"],["AIU5_LEGACY_PATH","none.json"],["AIU5_LEGACY_PROFILE_PATH","none.cfg"]]:OS.set_environment(pair[0],directory+"/"+pair[1])
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2");OS.set_environment("AIU5_MOBILE_PREVIEW","1")
	var game: Node=load("res://scenes/main.tscn").instantiate();add_child(game)
	for i in range(8):await get_tree().process_frame
	s=game.get_node("Session");s.simulation.set_process(false);s.persistence.set_process(false);s.world.streamer.set_process(false)
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values(): enemy.set_physics_process(false)
	var orchard: Node=s.orchard
	var actor: Node=s.world.active_resident
	var id: String=actor.resident_id
	check(orchard.records.size()==23,"three main-village and twenty forest-village mature trees exist")
	var main_count := 0;var forest_count := 0
	for key: String in orchard.records:
		if key.begins_with("starter_"):main_count+=1
		if key.begins_with("forest_"):forest_count+=1
	check(main_count==3 and forest_count==20,"each village receives the requested number")
	check(orchard.records.values().all(func(record: Dictionary)->bool:return record.fruit==3 and record.growth==0),"initial trees carry three ripe apples")
	orchard.ensure_starter();orchard.ensure_starter()
	check(orchard.records.size()==23,"seeding is idempotent")
	var key := "starter_0"
	check(orchard.nodes[key].body.collision_layer==1,"tree trunks have physical collision")
	s.inventory.bags[id]=s.inventory._sanitize_slots([])
	actor.position=orchard.nodes[key].position+Vector2(0,22)
	s._refresh_nearest();s.interact()
	check(apples(id)==3 and orchard.records[key].fruit==0,"normal interaction harvests exactly three apples")
	check(is_equal_approx(float(orchard.records[key].remaining),300),"successful harvest starts the five-minute timer")
	orchard.elapse(299)
	check(orchard.records[key].fruit==0 and is_equal_approx(float(orchard.records[key].remaining),1),"tree does not fruit early")
	s.overview=true;orchard.elapse(90);s.overview=false
	check(is_equal_approx(float(orchard.records[key].remaining),1),"overview does not advance fruit timers")
	s.menu_paused=true;orchard.elapse(90);s.menu_paused=false
	check(is_equal_approx(float(orchard.records[key].remaining),1),"pause does not advance fruit timers")
	s.vitals.set_process(false);orchard.elapse(90);s.vitals.set_process(true)
	check(is_equal_approx(float(orchard.records[key].remaining),1),"stopped simulation does not advance fruit timers")
	orchard.elapse(1);orchard.elapse(900)
	check(orchard.records[key].fruit==3,"unpicked fruit stays capped at one three-apple batch")
	var full: Array=[]
	for i in range(21):full.append({"item":"wood","count":99})
	s.inventory.bags[id]=s.inventory._sanitize_slots(full)
	check(not orchard.gather(key) and orchard.records[key].fruit==3,"full backpack leaves all ripe fruit on the tree")
	s.inventory.bags[id]=s.inventory._sanitize_slots([{"item":"apple","count":2}])
	check(spot(actor),"a valid clear planting position exists")
	var magic: Dictionary=s.magic.ensure(id)
	magic.element="";magic.level=1
	check(not orchard.plant() and apples(id)==2 and orchard.records.size()==23,"unawakened character cannot plant or lose materials")
	magic.element="water";magic.level=50
	check(not orchard.plant(),"other elements cannot plant despite high level")
	magic.element="wood";magic.level=0
	check(not orchard.plant(),"wood level below one cannot plant")
	magic.level=1;s.inventory.bags[id]=s.inventory._sanitize_slots([])
	check(not orchard.plant() and orchard.records.size()==23,"missing apple does not create a sapling")
	s.inventory.bags[id]=s.inventory._sanitize_slots([{"item":"apple","count":2}])
	game.get_node("MobileControls").dispatch("apple")
	check(orchard.records.size()==24 and apples(id)==1,"mobile plant action consumes exactly one apple")
	var planted := "planted_0"
	check(orchard.records.has(planted) and orchard.records[planted].growth==300,"new sapling starts with a five-minute growth timer")
	orchard.elapse(299)
	check(orchard.records[planted].fruit==0 and is_equal_approx(float(orchard.records[planted].growth),1),"sapling cannot produce fruit before maturity")
	check(s.persistence.save_now(),"orchard progress saves through the real persistence domain")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(s.inventory.path))
	s.inventory.apply_data(saved);s.persistence.restore_session(saved.session)
	check(orchard.records.size()==24 and is_equal_approx(float(orchard.records[planted].growth),1),"save reload preserves growth and avoids duplicate trees")
	orchard.elapse(1)
	check(orchard.records[planted].growth==0 and orchard.records[planted].fruit==3,"mature sapling yields its first three apples")
	check(spot(actor),"a second clear planting position exists")
	var old_count: int=orchard.records.size();var old_apples:=apples(id)
	s.inventory.save_hook=func(_path: String)->Error:return ERR_CANT_CREATE
	check(not orchard.plant(),"failed save rejects planting")
	s.inventory.save_hook=Callable()
	check(orchard.records.size()==old_count and apples(id)==old_apples,"failed planting save rolls back both tree and material")
	actor.position=orchard.nodes[key].position+Vector2(0,22)
	old_apples=apples(id)
	s.inventory.save_hook=func(_path: String)->Error:return ERR_CANT_CREATE
	check(not orchard.gather(key),"failed save rejects harvesting")
	s.inventory.save_hook=Callable()
	check(orchard.records[key].fruit==3 and apples(id)==old_apples,"failed harvest save rolls back fruit and inventory")
	var original: Dictionary=orchard.export_state()
	orchard.restore({})
	check(orchard.records.size()==23 and orchard.starter_seeded and orchard.forest_seeded,"old save without orchard migrates to exactly 23 trees")
	orchard.restore(original)
	check(orchard.records.size()==24 and orchard.records[planted].fruit==3,"restoring orchard state never grants duplicate starter trees")
	var mobile: Node=game.get_node("MobileControls")
	check(mobile.buttons.run.position==Vector2(548,318) and not mobile.buttons.has("attack"),"user's bottom-right run and touch-only attacks remain")
	check(mobile.buttons.has("apple"),"more menu exposes planting")
	game.queue_free()
	for i in range(8):await get_tree().process_frame
	var result: Dictionary={"checks":checks,"failures":failures}
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("ORCHARD_OK" if failures.is_empty() else "ORCHARD_FAILED"," ",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
