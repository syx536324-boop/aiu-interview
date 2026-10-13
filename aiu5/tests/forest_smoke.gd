# Exercises western traversal, streamed herbs, online respawns, herbal recipes and durable healing.
extends SceneTree
var failures: Array[String] = []
var game: Node
var session: Node
var forest: Node
var world: Node2D
var items: Node
var path := ""
func _initialize() -> void:
	path = "res://.runtime/forest-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	OS.set_environment("AIU5_WORLD_PROFILE","starter")
	OS.set_environment("AIU5_WORLD_SEED","7319")
	create_timer(50,true).timeout.connect(func() -> void: push_error("FOREST_TIMEOUT"); quit(2))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func frames(count := 3) -> void:
	for i in range(count): await physics_frame
	await process_frame
func count_item(item: String) -> int:
	var total := 0
	for slot: Dictionary in items.ensure_bag("ali"):
		if slot.get("item","") == item: total += int(slot.count)
	return total
func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	session = game.get_node("Session")
	forest = game.get_node("Forest")
	world = session.world
	items = session.inventory
	session.simulation.set_process(false)
	session.simulation.reset()
	session.persistence.set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for animal in session.livestock.animals: animal.set_physics_process(false)
	await frames()
func sample(kind: String) -> String:
	for id: String in forest.loaded:
		if forest.loaded[id].record.kind == kind: return id
	return ""
func run() -> void:
	await load_game()
	var actor: CharacterBody2D = world.active_resident
	check(world.BOUNDS.size == Vector2(7200,3200) and world.Layout.FOREST.size == Vector2(2400,1600),"widened map keeps the forest at the original desert area")
	check(world.houses.size()==9 and world.home_data("herb_house").at.x < 0,"starter village gains western herbal house")
	actor.position = Vector2(60,310)
	await frames()
	var blocked := false
	for i in range(23):
		if actor.move_and_collide(Vector2(-8,0)) != null: blocked = true
	check(not blocked and actor.position.x < -100,"western bridge crosses former zero boundary")
	actor.position = Vector2(60,400)
	await frames()
	var hit: KinematicCollision2D = actor.move_and_collide(Vector2(-70,0))
	check(hit != null and actor.position.x > 36,"river blocks walking except bridges")
	actor.position = Vector2(-700,400)
	world.streamer.focus(true)
	await frames(100)
	check(world.terrain.center.x < 0 and not world.terrain.chunks.is_empty(),"negative forest terrain chunks load")
	check(forest.loaded.size()>0 and forest.loaded.size()<=135 and forest.built_last_frame<=2,"forest object loading stays local and budgeted")
	check(not world.navigation.find_path(Vector2(-800,310),Vector2(-600,310)).is_empty(),"navigation supports negative forest coordinates")
	var mulberry := sample("mulberry")
	check(mulberry!="","forest contains gatherable mulberry trees")
	if mulberry != "":
		var tree: Node2D = forest.loaded[mulberry]
		actor.position = tree.position+Vector2(0,12)
		var before := count_item("mulberry_leaf")
		session.interact()
		check(count_item("mulberry_leaf")==before+1 and is_instance_valid(tree) and tree.is_inside_tree(),"real E gathers leaf without removing tree")
		check(not forest.gather(mulberry),"mulberry cannot be collected twice immediately")
		forest.elapse(119.9)
		check(not forest.available(tree.record),"no early mulberry regrowth")
		forest.elapse(0.1)
		check(forest.available(tree.record) and forest.gather(mulberry),"mulberry regrows at 120 online seconds")
	# Sample the distribution of independent slots, and verify epoch alignment/reload stability.
	var immediate := 0
	for i in range(10000):
		var deadline: float = forest._rare_deadline("forest-test:"+str(i),0,true)
		if deadline == 0: immediate += 1
		check(fmod(deadline,120)==0,"rare herb deadlines are aligned to two-minute checks")
	check(immediate>=230 and immediate<=370,"rare initial positions follow three-percent probability")
	print("RARE_INITIAL_RATE ",immediate,"/10000")
	var rare := sample("ginseng")
	check(rare!="","forest has seeded ginseng growth positions")
	if rare != "":
		forest.collected[rare] = forest.online
		actor.position = forest.loaded[rare].position+Vector2(0,10)
		check(forest.gather(rare),"ripe rare herb can be gathered")
		var deadline: float = forest.collected[rare]
		check(deadline>forest.online and fmod(deadline,120)==0 and not forest.available(forest.loaded[rare].record),"gathered ginseng waits for its next random spawn")
		check(session.persistence.save_now(),"herb cooldown saves")
		var clock: float = forest.online
		game.queue_free()
		await frames()
		await load_game()
		actor = world.active_resident
		check(forest.online==clock and forest.collected[rare]==deadline,"restart retains rare deadline without offline respawn")
		check(session.persistence.save_checkpoint(false),"altar records forest clock and rare deadline")
		forest.elapse(250)
		check(session.persistence.restore_checkpoint() and forest.online==clock and forest.collected[rare]==deadline,"altar restores forest gathering and regrowth snapshot")
		await frames(100)
		if forest.loaded.has(rare):
			forest.elapse(deadline-clock)
			check(forest.available(forest.loaded[rare].record),"rare herb becomes available at saved random deadline")
	# Map pauses every forest clock and does not instantiate a remote forest.
	actor.position = Vector2(400,330)
	world.streamer.focus(true)
	await frames()
	var count: int = forest.loaded.size()
	var clock: float = forest.online
	world.set_overview(true)
	await create_timer(0.1,true).timeout
	check(forest.online==clock and forest.loaded.size()==count,"full map freezes regeneration and does not load distant forest")
	check(world.streamer.overview.captions.entries.any(func(e: Dictionary)->bool:return e.id=="herb_house"),"full map labels herbal house")
	world.set_overview(false)
	# Enter the real herbal house and use its workbench recipe UI.
	actor.position = world.home_data("herb_house").door
	session.interact()
	check(actor.room_id=="herb_house","herbal house is enterable with E")
	actor.position = Vector2(52,78)
	session.production.open_near()
	check(session.production.mode=="herbs" and session.production.snapshot().recipes.size()==2,"herbal house presents both soup recipes")
	items.bags.ali = items._sanitize_slots([{"item":"ginseng","count":1},{"item":"reishi","count":1},{"item":"water_cup","count":1}])
	check(session.production.perform("restorative_soup"),"start soup job")
	session.production.elapse(60)
	check(count_item("restorative_soup")==1 and count_item("wooden_cup")==1 and count_item("water_cup")==0,"great soup consumes exact herbs and water and returns cup")
	session.production.close()
	var stats: Dictionary = session.vitals.ensure("ali")
	stats.life=2
	stats.health=2
	stats.low_health=true
	stats.low_time=1799
	stats.ill=true
	check(forest.drink_soup("restorative_soup") and stats.life==10 and stats.health==10 and not stats.low_health and stats.low_time==0,"great soup fills life/health and clears low-health deadline")
	session.production.open_near()
	items.bags.ali = items._sanitize_slots([{"item":"goji","count":2},{"item":"mulberry_leaf","count":2},{"item":"water_cup","count":1},{"item":"wooden_cup","count":1}])
	check(session.production.perform("qi_soup"),"qi soup recipe succeeds")
	session.production.elapse(60)
	session.production.close()
	stats.life=4
	stats.health=3
	check(forest.drink_soup("qi_soup") and stats.life==7 and stats.health==8,"qi soup gives exactly three life and five health")
	items.exchange("ali",{}, {"qi_soup":1})
	check(forest.drink_soup("qi_soup") and stats.life==10 and stats.health==10,"qi soup clamps both stats at ten")
	# Wrong water vessel and insufficient reward capacity are atomic failures.
	session.production.open_near()
	items.bags.ali = items._sanitize_slots([{"item":"ginseng","count":1},{"item":"reishi","count":1},{"item":"water_bucket","count":1}])
	var bag: Array = items.bags.ali.duplicate(true)
	check(not session.production.perform("restorative_soup") and items.bags.ali==bag,"full bucket cannot replace a cup in soup recipe")
	for i in range(21):items.bags.ali[i]={"item":"book","count":10}
	items.bags.ali[0]={"item":"ginseng","count":2}
	items.bags.ali[1]={"item":"reishi","count":2}
	items.bags.ali[2]={"item":"water_cup","count":1}
	bag=items.bags.ali.duplicate(true)
	check(not session.production.perform("restorative_soup") and items.bags.ali==bag,"room for only soup or cup cannot partially consume ingredients")
	items.bags.ali=items._sanitize_slots([{"item":"ginseng","count":1},{"item":"reishi","count":1},{"item":"water_cup","count":1}])
	bag=items.bags.ali.duplicate(true)
	var old_path: String=items.path
	var blocked_path:=path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path))
	items.path=blocked_path
	check(not session.production.perform("restorative_soup"),"failed save rejects completed soup transaction")
	items.path=old_path
	check(items.bags.ali==bag,"save failure restores exact ingredients and water")
	items.bags.ali=items._sanitize_slots([{"item":"qi_soup","count":1}])
	stats=session.vitals.ensure("ali")
	stats.life=2
	stats.health=2
	items.path=blocked_path
	check(not forest.drink_soup("qi_soup"),"healing is rolled back if saving fails")
	items.path=old_path
	stats=session.vitals.ensure("ali")
	check(stats.life==2 and stats.health==2 and count_item("qi_soup")==1,"failed soup use restores both stats and item")
	session.vitals.ensure("heya").life=0
	check(not session.vitals.use_food("heya","qi_soup") and count_item("qi_soup")==1,"soup cannot revive an inactive dead role")
	game.queue_free()
	await frames()
	if failures.is_empty():print("FOREST_SMOKE_OK");quit(0)
	else:print("FOREST_FAILED ",failures);quit(1)
