# Exercises bench actions through the actual UI and verifies inventory, busy-job and persistence guarantees.
extends Node
var game: Node
var s: Node
var directory := ""
var checks := 0
var failures: Array[String] = []
func _ready() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func frames(n:=2) -> void:
	for i in range(n): await get_tree().process_frame
func key(code: int) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
		Input.parse_input_event(event); await frames(12 if pressed else 2)
func click(button: Button) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*button.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		Input.parse_input_event(event); await frames(12 if pressed else 2)
func find_fixture(id: String) -> Node2D:
	for fixture: Node2D in s.grounds.fixtures:
		if fixture.fixture_id==id: return fixture
	return null
func count(item: String) -> int:
	var total:=0
	for slot: Dictionary in s.inventory.ensure_bag(s.world.active_resident.resident_id):
		if slot.get("item","")==item: total+=int(slot.count)
	return total
func approach(fixture: Node2D) -> void:
	var actor: Node=s.world.active_resident
	var bounds: Rect2=fixture.collision_bounds()
	for at: Vector2 in [Vector2(bounds.get_center().x,bounds.end.y+11),Vector2(bounds.end.x+11,bounds.get_center().y),Vector2(bounds.position.x-11,bounds.get_center().y),Vector2(bounds.get_center().x,bounds.position.y-8)]:
		actor.position=at
		if s.production.context().get("fixture")==fixture: break
	s._sync_view(); s.refresh_interface()
func open_station(fixture: Node2D) -> void:
	s.editor.close(); s.production.close(); approach(fixture)
	await key(KEY_T)
	check(s.production.opened and s.production.fixture==fixture,"T opens the intended bench")
func choose_position(origin: Vector2, min_gap:=48.0) -> bool:
	for y in range(int(origin.y-144),int(origin.y+177),16):
		for x in range(int(origin.x-144),int(origin.x+177),16):
			var at:=Vector2(x,y)
			if at.distance_to(origin)<min_gap: continue
			s.editor.ghost.set_placement(at,0)
			if s.grounds.land_error(s.editor.ghost.visual_bounds(),s.world.active_resident,true,s.editor.original)!="": continue
			s.editor.point_at(at+s.editor.ghost.size/2)
			if s.editor.ghost.preview_valid: return true
	return false
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game); await frames(5)
	s=game.get_node("Session")
	s.persistence.set_process(false); s.simulation.set_process(false); s.editor.set_process(false)
	s.resources.set_process(false); s.world.streamer.set_process(false)
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values(): enemy.set_physics_process(false)
	var actor: Node=s.world.active_resident
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,Vector2(300,400))
	actor.position=Vector2(300,400); s._sync_view()
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames(3)
	get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")
func run() -> void:
	directory=OS.get_environment("AIU5_BENCH_DIR")
	if directory=="": get_tree().quit(2); return
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	await load_game()
	var actor_id: String=s.world.active_resident.resident_id
	s.inventory.bags[actor_id]=[]
	for i in range(21): s.inventory.bags[actor_id].append({})
	check(s.inventory.exchange(actor_id,{}, {"wood":30,"stone":30,"building_bench":3}),"isolated supplies are available")
	var public_id:="outdoors:public:desert"
	var bench:=find_fixture(public_id)
	check(is_instance_valid(bench) and bench.public_fixture,"preplaced starter workbench exists in both new and old saves")
	if not is_instance_valid(bench): get_tree().quit(1); return
	var original: Vector2=bench.visual_bounds().position
	check(s.persistence.save_checkpoint(false),"checkpoint captures original bench and supplies")
	await open_station(bench)
	var ui: Node=game.get_node("Workshop")
	check(ui.move_button.visible and ui.recover_button.visible and not ui.recover_button.disabled,"workbench offers usable move and recover buttons")
	await screenshot("workbench-actions")
	await click(ui.move_button)
	check(s.editor.opened and s.editor.original==bench and not s.production.opened,"move button selects the existing preplaced workbench")
	check(choose_position(original),"free nearby workbench destination exists")
	check(s.editor.place() and bench.visual_bounds().position!=original and count("workbench")==0,"moving a preplaced workbench changes position without consuming or creating an item")
	s.editor.close()
	await open_station(bench)
	check(s.production.perform("knife"),"real workbench starts a paid crafting job")
	s.refresh_interface(); await frames()
	check(ui.recover_button.disabled and not s.production.perform("fixture:recover"),"busy workbench cannot be recovered through its interaction menu")
	s.production.close(); s.editor.open(); s.editor.pick(bench)
	check(not s.editor.remove_selected() and is_instance_valid(find_fixture(public_id)),"F/Delete route also protects a busy bench")
	s.editor.close()
	var bag: Array=s.inventory.ensure_bag(actor_id).duplicate(true)
	for i in range(21): s.inventory.bags[actor_id][i]={"item":"book","count":10}
	s.production.elapse(60)
	check(s.production.crafts.jobs.has(public_id) and s.production.crafts.jobs[public_id].remaining==0,"finished craft is held when its owner's bag is full")
	await open_station(bench)
	check(ui.recover_button.disabled,"uncollected output keeps bench recovery disabled")
	s.inventory.bags[actor_id]=bag
	check(s.production.perform("craft:collect") and count("knife")==1,"held output is delivered before recovering its bench")
	for i in range(21): s.inventory.bags[actor_id][i]={"item":"book","count":10}
	check(not s.production.perform("fixture:recover") and is_instance_valid(find_fixture(public_id)) and not s.grounds.retired_fixtures.has(public_id),"full bag retains the bench and does not mark it removed")
	s.inventory.bags[actor_id]=bag
	bench=find_fixture(public_id); await open_station(bench)
	var blocked:=directory+"/blocked-directory"; DirAccess.make_dir_recursive_absolute(blocked)
	var path: String=s.inventory.path; s.inventory.path=blocked
	check(not s.production.perform("fixture:recover"),"failed save refuses workbench recovery")
	s.inventory.path=path
	check(is_instance_valid(find_fixture(public_id)) and count("workbench")==0 and not s.grounds.retired_fixtures.has(public_id),"failed save restores workbench, bag and removal record together")
	bench=find_fixture(public_id); await open_station(bench)
	await click(ui.recover_button)
	check(not is_instance_valid(find_fixture(public_id)) and count("workbench")==1,"UI recovers the starter workbench as exactly one item")
	check(s.grounds.retired_fixtures.has(public_id),"preplaced workbench retirement is part of the saved transaction")
	s.foraging._build()
	check(not is_instance_valid(find_fixture(public_id)),"resource rebuild never respawns a recovered preplaced workbench")
	s.editor.open(); s.editor.choose("building_bench")
	check(choose_position(Vector2(520,500),0),"free building bench position exists")
	check(s.editor.place() and count("building_bench")==2,"building bench deploys normally")
	bench=s.grounds.fixtures.back(); var building_id: String=bench.fixture_id
	await open_station(bench)
	check(ui.move_button.visible and ui.move_button.text=="移动建筑台" and ui.recover_button.text=="回收建筑台","unbuilt bench exposes clearly named management actions")
	await screenshot("building-bench-actions")
	await click(ui.move_button)
	var previous: Vector2=bench.visual_bounds().position
	check(s.editor.original==bench and choose_position(previous),"building move action retains the existing fixture")
	check(s.editor.place() and bench.visual_bounds().position!=previous and count("building_bench")==2,"unbuilt building bench moves without item loss")
	await open_station(bench); await click(ui.recover_button)
	check(not is_instance_valid(find_fixture(building_id)) and count("building_bench")==3,"unbuilt building bench recovers into exactly one item")
	check(not s.production.perform("fixture:recover") and count("building_bench")==3,"repeated recovery action cannot duplicate a bench")
	# Redeploying the recovered starter bench must not reactivate its old spawn point.
	s.editor.open(); s.editor.choose("workbench")
	check(choose_position(Vector2(540,500),0) and s.editor.place() and count("workbench")==0,"recovered workbench deploys from the returned item")
	var replacement_id: String=s.grounds.fixtures.back().fixture_id
	s.editor.close(); check(s.persistence.save_now(),"final bench layout saves")
	game.queue_free(); await frames(5); await load_game()
	check(not is_instance_valid(find_fixture(public_id)) and s.grounds.retired_fixtures.has(public_id),"actual reload preserves preplaced workbench removal")
	check(is_instance_valid(find_fixture(replacement_id)) and count("workbench")==0,"reload retains the single redeployed bench without duplicating it")
	check(not is_instance_valid(find_fixture(building_id)) and count("building_bench")==3,"reload preserves building bench recovery")
	check(s.persistence.restore_checkpoint(),"altar rollback succeeds after bench changes")
	check(is_instance_valid(find_fixture(public_id)) and find_fixture(public_id).visual_bounds().position==original and not s.grounds.retired_fixtures.has(public_id),"altar rollback restores the original bench and clears later retirement")
	check(not is_instance_valid(find_fixture(replacement_id)) and count("building_bench")==3 and count("workbench")==0,"altar rollback restores matching items without extra benches")
	game.queue_free(); await frames(5)
	var result: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"display":DisplayServer.get_name(),"checks":checks,"failures":failures}
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"  "))
	print("BENCH_MANAGEMENT_OK" if failures.is_empty() else "BENCH_MANAGEMENT_FAILED"," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
