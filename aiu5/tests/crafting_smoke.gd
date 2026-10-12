# Exercises E navigation, explicit confirmation, paid jobs, pause, persistence and full-bag recovery.
extends SceneTree
var failures: Array[String]=[]
var game: Node
var s: Node
var ui: Node
var path: String
func _initialize() -> void:
	path="res://.runtime/crafting-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	create_timer(65,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n:=2) -> void:
	for i in range(n): await physics_frame
	await process_frame
func key(code: int) -> void:
	for pressed in [true,false]:
		var e:=InputEventKey.new()
		e.keycode=code; e.physical_keycode=code; e.pressed=pressed
		Input.parse_input_event(e)
		await frames(1)
func click(button: Button) -> void:
	var point:=button.get_global_rect().get_center()
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=point; e.button_index=MOUSE_BUTTON_LEFT; e.pressed=pressed
		Input.parse_input_event(e)
		await frames(1)
func count(id: String, actor:="ali") -> int:
	var result:=0
	for slot: Dictionary in s.inventory.ensure_bag(actor):
		if slot.get("item","")==id: result+=int(slot.count)
	return result
func choose(id: String) -> void:
	for b: Button in ui.buttons:
		if b.visible and str(b.get_meta("recipe_id",""))==id:
			ui.list.get_parent().ensure_control_visible(b)
			await frames()
			await click(b)
			check(ui.selected_id==id,"actual click selects "+id)
			return
	check(false,"recipe not visible "+id)
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	s=game.get_node("Session"); ui=game.get_node("Workshop")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	for a in s.world.residents: a.set_physics_process(false)
	for a in s.livestock.animals: a.set_physics_process(false)
	await frames()
func run() -> void:
	await load_game()
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"wood","count":40},{"item":"stone","count":40},{"item":"crude_iron","count":20}])
	var bench: Node2D=s.grounds.add_fixture({"id":"outdoors:craft-test","kind":"workbench","at":[740,1010],"size":[36,24]})
	s.world.active_resident.position=bench.position+Vector2(0,14)
	await key(KEY_E)
	check(s.production.opened and ui.root.visible and s.production.crafts.jobs.is_empty(),"E opens outdoor table without crafting")
	await click(ui.tab_buttons.weapon)
	check(ui.category=="weapon" and ui.tab_buttons.tool.visible,"top navigation filters recipes")
	await choose("pickaxe")
	check(count("wood")==40 and ui.details.text.contains("石头") and ui.confirm_button.text=="确认合成","selection only shows ingredients")
	await click(ui.confirm_button)
	check(count("wood")==39 and count("stone")==38 and count("pickaxe")==0,"confirmation reserves exact materials without immediate output")
	check(s.production.crafts.jobs[bench.fixture_id].remaining==60 and ui.confirm_button.disabled,"sixty second job and disabled duplicate confirmation")
	check(not s.production.perform("bow") and count("wood")==39,"busy bench rejects another job")
	check(not s.production.can_remove_fixture(bench),"busy bench cannot be removed")
	s.production.elapse(17.25)
	check(s.persistence.save_checkpoint(false),"checkpoint stores fractional craft progress")
	s.production.close()
	await key(KEY_M)
	s.simulation.pending=1.0
	await create_timer(0.1,true).timeout
	check(s.production.crafts.jobs[bench.fixture_id].remaining==42.75,"map pause freezes crafting")
	s.simulation.reset()
	await key(KEY_M)
	check(s.persistence.save_now(),"save job before reload")
	game.queue_free(); await frames(3)
	await load_game()
	check(s.production.crafts.jobs["outdoors:craft-test"].remaining==42.75,"reload preserves remaining online time")
	s.production.elapse(42.5)
	check(count("pickaxe")==0,"no output before sixty seconds")
	s.select_resident(1)
	s.production.elapse(0.25)
	check(count("pickaxe")==1 and s.production.crafts.jobs.is_empty(),"finished item goes to original maker after character switch")
	check(s.persistence.restore_checkpoint(),"checkpoint restores reserved job")
	check(count("pickaxe")==0 and s.production.crafts.jobs["outdoors:craft-test"].remaining==42.75,"rollback cannot duplicate output")
	var bag: Array=s.inventory.ensure_bag("ali")
	for i in range(21): bag[i]={"item":"book","count":10}
	s.production.elapse(42.75)
	check(s.production.crafts.jobs["outdoors:craft-test"].remaining==0,"full bag retains finished output")
	s.inventory.ensure_bag("ali")[20]={}
	for fixture: Node2D in s.grounds.fixtures:
		if fixture.fixture_id=="outdoors:craft-test": bench=fixture
	s.world.active_resident.position=bench.position+Vector2(0,14)
	await key(KEY_E)
	await choose("craft:collect")
	await click(ui.confirm_button)
	check(count("pickaxe")==1 and s.production.crafts.jobs.is_empty(),"held output collected once without spending materials")
	check(not s.production.perform("craft:collect"),"duplicate collect rejected")
	s.production.close()
	# Interior tables use the same E path and failure to save refunds materials.
	s.select_resident(0)
	var actor: CharacterBody2D=s.world.active_resident
	s.interiors.enter(actor,s.world.home_data("blacksmith")); s._sync_view()
	var room: Node2D=s.interiors.rooms.blacksmith
	var wb: Node2D
	for f: Node2D in room.fixtures:
		if f.kind=="workbench": wb=f
	check(wb!=null,"smith room contains workbench")
	actor.position=Vector2(wb.collision_bounds().end.x+7,wb.collision_bounds().get_center().y)
	await key(KEY_E)
	check(s.production.mode=="craft" and ui.root.visible,"interior E opens categorized crafting")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"wood","count":8},{"item":"stone","count":8}])
	var original_path: String=s.inventory.path
	s.inventory.path="res://project.godot/fail.json"
	check(not s.production.perform("pickaxe") and count("wood")==8 and count("stone")==8 and s.production.crafts.jobs.is_empty(),"failed save rolls back reservation and job")
	s.inventory.path=original_path
	game.queue_free(); await frames(2)
	if failures.is_empty(): print("CRAFTING_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)
