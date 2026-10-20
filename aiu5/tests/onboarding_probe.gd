# Exercises real starter pickups, paid crafting, final mining, persistence and transactional rollback.
extends Node
var game: Node
var s: Node
var view: Node
var directory := ""
var failures: Array[String]=[]
var checks := 0
var capture := false
const BENCH := "outdoors:onboarding-probe"

func _enter_tree() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var base := OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(base!="" and base.is_absolute_path())
	directory=base.path_join("onboarding-"+str(Time.get_ticks_usec()))
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
	OS.set_environment("AIU5_STATE_PATH",directory.path_join("state.json"))
	OS.set_environment("AIU5_PROFILE_PATH",directory.path_join("names.cfg"))
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	OS.set_environment("AIU5_WORLD_SEED","92001")
	capture=OS.get_environment("AIU5_CAPTURE")=="true"
	get_tree().create_timer(65,true).timeout.connect(func() -> void: push_error("ONBOARDING_TIMEOUT"); get_tree().quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)

func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame

func wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds,true).timeout
	await frames()

func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		Input.parse_input_event(event)
		await frames(1)

func count(item: String) -> int:
	var amount := 0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: amount+=int(slot.count)
	return amount

func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.process_mode=Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(game)
	s=game.get_node("Session")
	view=game.get_node("OnboardingView")
	# Actors stand still; all actual online domain clocks remain enabled.
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for id: String in s.tribes.population.members: s.tribes.population.node(id).set_physics_process(false)
	await frames()
	check(s.inventory.path.begins_with(directory),"probe only uses its fresh isolated save")
	check(s.simulation.is_processing() and s.foraging.is_processing(),"real online Simulation and resource domain stay enabled")

func restart() -> void:
	check(s.persistence.save_now(),"normal save before actual restart")
	game.queue_free()
	await frames(4)
	await wait_real(0.65)
	await load_game()

func gather(id: String) -> bool:
	var actor: Node2D=s.world.active_resident
	actor.position=s.foraging.nodes[id].position
	s._refresh_nearest()
	return s.foraging.gather(id)

func screenshot(name: String) -> void:
	if not capture: return
	# Give the real 0.1-second session presentation refresh time after fixture teleports.
	await wait_real(0.2)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(name))==OK,"saved guide screenshot "+name)

func run() -> void:
	await load_game()
	check(s.foraging.batch_limit==2 and s.onboarding.stage()==1,"new starter save enables two batches and initial guide")
	check(view.panel.visible and view.panel.position==Vector2(12,158),"guide card fits beneath existing skill hints")
	await screenshot("guide-01-pickups.png")
	view.fold_button.pressed.emit()
	check(view.folded and not view.detail.visible and not view.marker.visible,"guide can be folded without blocking movement")
	view.fold_button.pressed.emit()
	check(not view.folded and view.detail.visible,"folded guide can be expanded")

	# Merely owning gifted/test materials and tools never counts as a completed objective.
	s.inventory.bags.ali=s.inventory._sanitize_slots([{ "item":"wood","count":2 },{"item":"stone","count":4},{"item":"stone_axe","count":1},{"item":"pickaxe","count":1}])
	s.refresh_interface()
	check(s.onboarding.stage()==1 and s.onboarding.pickups.wood==0 and not s.onboarding.crafted.pickaxe,"gifted or pre-owned materials/tools do not advance guide")
	s.inventory.bags.ali=s.inventory._sanitize_slots([])
	for i in range(21): s.inventory.ensure_bag("ali")[i]={"item":"book","count":10}
	check(not gather("desert:0") and s.onboarding.pickups.wood==0 and s.foraging.nodes["desert:0"].available,"full bag preserves first batch and pickup objective")
	s.inventory.bags.ali=s.inventory._sanitize_slots([])
	s.inventory.save_hook=func(_path: String) -> Error: return ERR_CANT_CREATE
	check(not gather("desert:0"),"failed save rejects pickup")
	check(s.onboarding.pickups.wood==0 and s.foraging.nodes["desert:0"].available and int(s.foraging.taken.get("desert:0",0))==0 and count("wood")==0,"failed save rolls back bag, batch usage and guide atomically")
	s.inventory.save_hook=Callable()
	check(gather("desert:0"),"normal pickup takes first wood")
	check(count("wood")==1 and s.onboarding.pickups.wood==1 and s.foraging.taken["desert:0"]==1,"first actual pickup counts once")
	check(not gather("desert:0") and count("wood")==1 and s.onboarding.pickups.wood==1,"duplicate pickup cannot count twice")
	var remaining: float=float(s.foraging.collected["desert:0"])-float(s.foraging.online)
	check(remaining>119 and remaining<=120,"first pickup reserves original 120 online seconds")
	s.foraging.collected["desert:0"]=s.foraging.online+0.8
	await key(KEY_M)
	check(s.overview and get_tree().paused,"actual M path pauses full map")
	var paused: float=s.foraging.online
	await wait_real(0.9)
	check(is_equal_approx(paused,s.foraging.online) and not s.foraging.nodes["desert:0"].available,"pause freezes replenishment deadline")
	await key(KEY_M)
	await wait_real(1.5)
	check(s.foraging.nodes["desert:0"].available,"real online clock produces exactly the second batch")
	await restart()
	check(s.onboarding.pickups.wood==1 and s.foraging.taken["desert:0"]==1 and s.foraging.nodes["desert:0"].available,"restart restores unfinished guide and existing second batch")
	check(gather("desert:0") and count("wood")==2,"second pickup grants final material")
	check(s.foraging.taken["desert:0"]==2 and not s.foraging.nodes["desert:0"].available,"second pickup permanently exhausts its new-save resource point")
	s.foraging.collected["desert:0"]=s.foraging.online+0.5
	await wait_real(1.2)
	check(not s.foraging.nodes["desert:0"].available and not s.world.points.has("forage:desert:0"),"later real clock ticks never produce a third batch")
	await restart()
	check(not s.foraging.nodes["desert:0"].available and not gather("desert:0"),"exhausted two-batch cap survives actual restart")
	for id in ["desert:7","desert:8","desert:9","desert:10"]: check(gather(id),"actual stone pickup "+id)
	check(s.onboarding.stage()==2 and count("wood")==2 and count("stone")==4,"exact two wood and four stone move guide to crafting")

	var bench: Node2D=s.grounds.add_fixture({"id":BENCH,"kind":"workbench","at":[740,1010],"size":[36,24]})
	s.world.active_resident.position=bench.position+Vector2(0,14)
	s._sync_view()
	await screenshot("guide-02-crafting.png")
	await key(KEY_E)
	check(s.production.opened and s.production.mode=="craft","actual E interaction opens workbench")
	check(not view.panel.visible,"workbench modal hides guide card")
	check(s.production.perform("stone_axe"),"normal craft request reserves stone axe materials")
	check(count("wood")==1 and count("stone")==2 and not s.onboarding.crafted.stone_axe,"starting craft pays once but does not advance completed objective")
	s.production.crafts.jobs[BENCH].remaining=0.7
	await wait_real(1.4)
	check(count("stone_axe")==1 and s.onboarding.crafted.stone_axe,"real timed output delivery records crafted axe")
	check(s.production.perform("pickaxe"),"normal craft request reserves pickaxe materials")
	check(count("wood")==0 and count("stone")==0 and not s.onboarding.crafted.pickaxe,"both tools reserve exactly total wood2 stone4")
	s.production.crafts.jobs[BENCH].remaining=0.7
	await wait_real(1.4)
	check(count("pickaxe")==1 and s.onboarding.stage()==3,"real timed second output advances guide to mining")
	s.production.close()
	await restart()
	check(s.onboarding.stage()==3 and s.onboarding.crafted.stone_axe and s.onboarding.crafted.pickaxe,"actual restart preserves both completed craft events")
	var ore: Node2D=s.mining.surface["surface:1"]
	s.world.active_resident.position=ore.position+Vector2(0,15)
	s._sync_view()
	await screenshot("guide-03-mining.png")
	check(not s.mining.strike(s.world.active_resident,ore) and s.onboarding.stage()==3,"mining without equipped pickaxe does not complete guide")
	check(s.magic.equip_weapon("ali","pickaxe"),"normal equipment action equips crafted pickaxe")
	for i in range(2):
		s.mining.cooldown=0
		await key(KEY_E)
		check(ore.hits==i+1 and s.onboarding.stage()==3,"effective E mining hit waits for the whole deposit")
	s.mining.cooldown=0
	s.inventory.save_hook=func(_path: String) -> Error: return ERR_CANT_CREATE
	check(not s.mining.strike(s.world.active_resident,ore),"failed final mining save rolls back transaction")
	check(ore.hits==2 and not s.onboarding.mined and count("stone")==0,"failed final mining save keeps ore, output and tutorial unfinished")
	s.inventory.save_hook=Callable()
	s.mining.cooldown=0
	await key(KEY_E)
	check(ore.hits==3 and count("stone")==3 and s.onboarding.stage()==4,"actual final E mining yields stone3 and completes guide")
	check(view.panel.visible and "不同人物" in view.detail.text,"mining transitions to elemental choice guidance")
	await restart()
	check(s.onboarding.stage()==4 and view.panel.visible and s.foraging.taken["desert:0"]==2,"completed state and exhausted starter resources survive restart")

	# Old saved records deliberately retain prior unlimited replenishment and no forced guide.
	var new_state: Dictionary=s.foraging.export_state()
	s.onboarding.restore({})
	s.foraging.restore({"online":0,"collected":{"desert:0":0}})
	check(s.onboarding.stage()==0 and s.foraging.batch_limit==0,"missing historical fields do not force guide or restrict past saves")
	for i in range(3):
		check(gather("desert:0"),"legacy resource pickup "+str(i+1))
		s.foraging.collected["desert:0"]=s.foraging.online+0.2
		await wait_real(0.8)
		check(s.foraging.nodes["desert:0"].available,"legacy save still permits replenishment "+str(i+1))
	s.foraging.restore(new_state)
	check(not s.foraging.nodes["desert:0"].available,"restoring versioned new save reinstates exhausted cap")
	finish()

func finish() -> void:
	get_tree().paused=false
	if is_instance_valid(game): game.queue_free()
	print("ONBOARDING_PROBE_DIRECTORY="+directory)
	print("ONBOARDING_FAILURES="+JSON.stringify(failures))
	if failures.is_empty(): print("ONBOARDING_PROBE_OK checks="+str(checks))
	get_tree().quit(0 if failures.is_empty() else 1)
