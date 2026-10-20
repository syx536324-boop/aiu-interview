# Verifies parallel crafting, bench metadata, tutorial migration and direct touchscreen scrolling in isolation.
extends Node
var s: Node
var game: Node
var checks:=0
var failures: Array[String]=[]
var directory: String
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:=3) -> void:
	for i in range(n):await get_tree().process_frame
func _ready() -> void:call_deferred("run")
func count(item: String) -> int:
	var total:=0
	for slot: Dictionary in s.inventory.ensure_bag(s.world.active_resident.resident_id):
		if slot.get("item","")==item:total+=int(slot.count)
	return total
func find(id: String) -> Node2D:
	for fixture: Node2D in s.grounds.fixtures:
		if fixture.fixture_id==id:return fixture
	return null
func station(id: String) -> void:
	var fixture:=find(id)
	s.world.active_resident.position=fixture.position+Vector2(0,14)
	s.production.opened=true;s.production.mode="craft";s.production.fixture=fixture
	s.refresh_interface()
func touch(at: Vector2,pressed: bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=4;event.position=get_viewport().get_final_transform()*at;event.pressed=pressed
	Input.parse_input_event(event);await frames()
func swipe(from: Vector2,to: Vector2) -> void:
	await touch(from,true)
	for i in range(1,9):
		var event:=InputEventScreenDrag.new();event.index=4;event.position=get_viewport().get_final_transform()*(from.lerp(to,float(i)/8));event.relative=get_viewport().get_final_transform().basis_xform((to-from)/8)
		Input.parse_input_event(event);await frames()
	await touch(to,false)
func run() -> void:
	directory=OS.get_environment("AIU5_BENCH_DIR")
	if directory=="":directory=ProjectSettings.globalize_path("user://workbench-qa")
	DirAccess.make_dir_recursive_absolute(directory)
	for pair: Array in [["AIU5_STATE_PATH","state.json"],["AIU5_PROFILE_PATH","names.cfg"],["AIU5_SAVES_DIR","slots"],["AIU5_LEGACY_PATH","absent.json"],["AIU5_LEGACY_PROFILE_PATH","absent.cfg"]]:OS.set_environment(pair[0],directory+"/"+pair[1])
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2");OS.set_environment("AIU5_MOBILE_PREVIEW","1")
	game=load("res://scenes/main.tscn").instantiate();add_child(game);await frames(10)
	s=game.get_node("Session");s.simulation.set_process(false);s.persistence.set_process(false);s.world.streamer.set_process(false)
	for actor: Node in s.world.residents:actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values():enemy.set_physics_process(false)
	var actor_id: String=s.world.active_resident.resident_id
	s.inventory.bags[actor_id]=s.inventory._sanitize_slots([])
	check(s.inventory.exchange(actor_id,{}, {"wood":150,"stone":110}),"isolated supplies")
	s.grounds.add_fixture({"id":"qa:a","kind":"workbench","at":[740,1010],"size":[36,24]})
	s.grounds.add_fixture({"id":"qa:b","kind":"workbench","at":[840,1010],"size":[36,24]})
	station("qa:a")
	check(s.production.craft_capacity()==1 and s.production.craft_duration()==60,"level one defaults")
	check(s.production.perform("bowl"),"first bench starts")
	var before:=count("wood")
	check(not s.production.perform("bucket") and count("wood")==before,"full slot cannot charge materials")
	station("qa:b");check(s.production.perform("bucket"),"second bench starts independently")
	s.production.crafts.elapse(s.production,10)
	check(s.production.crafts.jobs["qa:a"].remaining==50 and s.production.crafts.jobs["qa:b"].remaining==50,"both benches advance together")
	station("qa:a");before=count("wood")
	check(s.production.perform("bench:upgrade") and count("wood")==before-25,"level two costs exactly wood25")
	check(find("qa:a").bench_level==2 and s.production.craft_capacity()==2 and s.production.craft_duration()==45,"level two capacity and duration")
	check(s.production.crafts.jobs["qa:a"].remaining==50 and s.production.crafts.jobs["qa:a"].duration==60,"upgrade preserves existing work")
	check(s.production.perform("wooden_cup"),"second simultaneous slot starts")
	check(s.production.crafts.queue("qa:a")[1].duration==45,"new job uses forty-five seconds")
	before=count("wood");var stones:=count("stone")
	check(s.production.perform("bench:upgrade") and count("wood")==before-50 and count("stone")==stones-50,"level three exact materials")
	check(s.production.craft_capacity()==3 and s.production.craft_duration()==30,"level three capacity and time")
	check(s.production.perform("watering_can"),"third simultaneous slot starts")
	check(s.production.crafts.queue("qa:a")[2].duration==30,"third job uses thirty seconds")
	check(not s.production.perform("bench:upgrade"),"level cap three")
	s.refresh_interface();await frames(6)
	check(game.get_node("Workshop").job_bars.all(func(bar: ProgressBar)->bool:return bar.size.y<=6),"three progress bars stay thin without overlapping task text")
	if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png(directory+"/parallel-three.png")
	var data: Dictionary=s.production.export_state();s.production.restore(data);station("qa:a")
	check(s.production.crafts.queue("qa:a").size()==3 and s.production.crafts.queue("qa:b").size()==1,"parallel jobs round trip")
	s.production.crafts.elapse(s.production,30)
	check(count("watering_can")==1 and s.production.crafts.queue("qa:a").size()==2,"shorter third job completes independently")
	s.production.crafts.elapse(s.production,20)
	check(count("bowl")==1 and count("bucket")==1 and count("wooden_cup")==1 and s.production.crafts.jobs.is_empty(),"all benches deliver paid outputs")
	var legacy: Dictionary={"old":{"recipe":"bowl","actor":actor_id,"remaining":17}}
	s.production.crafts.restore(legacy,s.production.all_recipes())
	check(s.production.crafts.jobs.old.remaining==17 and s.production.crafts.jobs.old.duration==60,"legacy sixty second jobs preserved")
	s.production.crafts.jobs.clear()
	station("qa:b");before=count("wood")
	s.inventory.save_hook=func(_path: String)->int:return ERR_CANT_CREATE
	check(not s.production.perform("bench:upgrade"),"failed save rejects upgrade")
	check(find("qa:b").bench_level==1 and count("wood")==before,"failed upgrade restores materials and fixture level")
	station("qa:b");check(not s.production.perform("bowl") and not s.production.crafts.jobs.has("qa:b") and count("wood")==before,"failed craft rolls back paid job")
	s.inventory.save_hook=Callable()
	station("qa:a")
	check(s.production.perform("fixture:recover"),"idle upgraded workbench recovers")
	var record: Dictionary={}
	for slot: Dictionary in s.inventory.ensure_bag(actor_id):
		if slot.get("item","")=="workbench":record=slot
	check(int(record.get("bench_level",0))==3,"recovered item preserves level")
	check(int(s.inventory._sanitize_slots([record])[0].get("bench_level",0))==3,"inventory save migration retains level")
	check(s.inventory.exchange(actor_id,{}, {"workbench":1}),"ordinary bench can coexist")
	check(s.inventory.ensure_bag(actor_id).filter(func(slot: Dictionary)->bool:return slot.get("item","")=="workbench").size()==2,"ordinary and upgraded workbenches never stack")
	check(s.editor.open(),"recovered bench can enter placement")
	s.editor.choose("workbench")
	var found:=false
	for y in range(900,1160,16):
		for x in range(650,960,16):
			s.editor.point_at(Vector2(x,y))
			if s.editor.ghost.preview_valid:found=true;break
		if found:break
	check(found and s.editor.place(),"recovered upgraded bench redeploys")
	var upgraded: Node2D
	for fixture: Node2D in s.grounds.fixtures:
		if fixture.kind=="workbench" and fixture.bench_level==3:upgraded=fixture;break
	check(is_instance_valid(upgraded),"redeployed bench retains level three")
	s.editor.close()
	if is_instance_valid(upgraded):
		station(upgraded.fixture_id)
		check(s.production.perform("bowl") and s.production.perform("bucket") and s.production.perform("wooden_cup"),"three independent paid jobs start")
		var bag: Array=s.inventory.ensure_bag(actor_id)
		for i in range(bag.size()):bag[i]={"item":"stone","count":99}
		s.production.crafts.elapse(s.production,30)
		check(s.production.crafts.queue(upgraded.fixture_id).size()==3 and s.production.crafts.queue(upgraded.fixture_id).all(func(job: Dictionary)->bool:return job.remaining==0),"full bag retains all three completed outputs")
		check(not s.production.can_remove_fixture(upgraded),"retained outputs prevent recovery")
		var retained: Array=s.production.crafts.queue(upgraded.fixture_id)
		var chosen: int=int(retained[1].id)
		s.inventory.bags[actor_id]=s.inventory._sanitize_slots([])
		check(s.production.perform("craft:collect:"+str(chosen)) and count("bucket")==1 and s.production.crafts.queue(upgraded.fixture_id).size()==2,"specific parallel output can be claimed")
		check(s.production.perform("craft:collect") and s.production.perform("craft:collect") and count("bowl")==1 and count("wooden_cup")==1,"other retained outputs remain claimable")
	station("qa:b")
	check(s.inventory.exchange(actor_id,{}, {"wood":4}),"supplies for creator ownership")
	check(s.production.perform("bowl"),"creator reserves output")
	var other_id: String=s.world.controllable[1].resident_id
	s.selected=1;s.world.active_resident=s.world.controllable[1]
	s.production.crafts.elapse(s.production,60)
	var own:=0
	for slot: Dictionary in s.inventory.ensure_bag(actor_id):
		if slot.get("item","")=="bowl":own+=int(slot.count)
	check(own==2,"switching character preserves original output owner")
	s.selected=0;s.world.active_resident=s.world.controllable[0]
	var guide: Node=s.onboarding
	guide.restore({"version":1,"enabled":true,"pickups":{"wood":2,"stone":4},"crafted":{"stone_axe":true,"pickaxe":true},"mined":true})
	check(guide.stage()==4,"legacy guide retains achievements and enters new chapters")
	check("不同人物" in guide.presentation().text,"guide recommends mixed character elements")
	s.production.close();guide.acknowledge();check(guide.stage()==5,"magic chapter acknowledgment")
	guide.acknowledge();check(guide.stage()==6,"gifting chapter acknowledgment")
	guide.acknowledge();check(guide.stage()==7 and not guide.presentation().visible,"NPC chapter completes tutorial")
	var saved: Dictionary=guide.export_state();guide.restore(saved);check(guide.stage()==7,"feature learning persists")
	guide.review_features();check(guide.stage()==4 and guide.mined,"review preserves real gathering history")
	s.inventory.save_hook=func(_path: String)->int:return ERR_CANT_CREATE
	guide.acknowledge();check(guide.stage()==4,"failed save cannot consume a tutorial chapter")
	s.inventory.save_hook=Callable()
	guide.restore({});check(guide.stage()==0,"historical save without record stays optional")
	game.get_node("MobileControls").dispatch("tutorial");check(guide.stage()==4,"touch menu reopens feature tutorial")
	station("qa:b");await frames(5)
	var ui: Node=game.get_node("Workshop")
	ui.selected_id="hoe";ui._render();await frames(5)
	var selected: String=ui.selected_id
	await swipe(Vector2(130,290),Vector2(130,135))
	check(ui.list_gesture.scroll.scroll_vertical>40,"recipe list drags without touching scrollbar")
	check(ui.selected_id==selected,"recipe drag does not select another recipe")
	ui.details.text="触屏详情测试\n".repeat(35);await frames(5)
	await swipe(Vector2(440,230),Vector2(440,120))
	check(ui.detail_scroll.scroll_vertical>30,"details drag without scrollbar")
	check(ui.list_gesture.scroll.scroll_vertical>40,"detail drag leaves list independent")
	ui.list_gesture.speed=0;ui.detail_gesture.speed=0
	await frames(15)
	ui.selected_id="bench:upgrade";ui._render();await frames(5)
	check(ui.confirm_button.text=="确认升级" and "立即升级" in ui.details.text,"bench upgrade explains immediate confirmation")
	if DisplayServer.get_name()!="headless":get_viewport().get_texture().get_image().save_png(directory+"/workbench-upgrade.png")
	var output: Dictionary={"checks":checks,"failures":failures}
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"  "));file.close()
	print("WORKBENCH_UPDATE_RESULT ",JSON.stringify(output));get_tree().quit(0 if failures.is_empty() else 1)
