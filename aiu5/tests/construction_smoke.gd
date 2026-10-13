# Exercises material transactions, deploy/build/enter/collapse, roof combat and durable enemy defeat.
extends SceneTree
var failures: Array[String] = []
var game: Node
var s: Node
var path := ""
func _initialize() -> void:
	path = "res://.runtime/construction-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	OS.set_environment("AIU5_WORLD_PROFILE","starter")
	create_timer(90,true).timeout.connect(func() -> void: push_error("CONSTRUCTION_TIMEOUT"); quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("CHECK FAILED: "+label)
func frames(n:=3) -> void:
	for i in range(n): await process_frame
func key(code: int) -> void:
	for pressed in [true,false]:
		var e := InputEventKey.new()
		e.keycode=code
		e.physical_keycode=code
		e.pressed=pressed
		Input.parse_input_event(e)
		await frames(2)
func click(control: Control) -> void:
	await frames()
	for pressed in [true,false]:
		var e := InputEventMouseButton.new()
		e.position=control.get_global_rect().get_center()
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressed
		Input.parse_input_event(e)
		await frames(2)
func count(item: String) -> int:
	var n:=0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: n+=int(slot.count)
	return n
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.resources.set_process(false)
	s.world.streamer.set_process(false)
	for a in s.world.residents: a.set_physics_process(false)
	for e in s.combat.enemies.values(): e.set_physics_process(false)
	await frames()
func outside(at: Vector2) -> void:
	var a: CharacterBody2D=s.world.active_resident
	if a.room_id!="": s.interiors.leave(a,s.world.objects,at)
	a.position=at
	s._sync_view()
	s.refresh_interface()
func deploy(at: Vector2) -> Node2D:
	outside(at+Vector2(48,100))
	s.editor.open()
	s.editor.choose("building_bench")
	s.editor.point_at(at+Vector2(48,40))
	check(s.editor.place(),"construction bench deploys only into validated reserved footprint")
	s.editor.close()
	var bench: Node2D=s.grounds.fixtures.back()
	outside(bench.position+Vector2(0,14))
	return bench
func construct(at: Vector2, button: int) -> String:
	await deploy(at)
	await key(KEY_E)
	check(s.production.opened and s.production.mode=="build","E at construction bench opens four building choices")
	await click(game.get_node("Workshop").buttons[button])
	await click(game.get_node("Workshop").confirm_button)
	s.construction.advance(30)
	return "built:"+str(s.construction.next_id-1)
func craft_recipe(id: String) -> void:
	var ui: Node=game.get_node("Workshop")
	s.refresh_interface()
	await frames()
	for b: Button in ui.buttons:
		if b.visible and str(b.get_meta("recipe_id",""))==id:
			ui.list.get_parent().ensure_control_visible(b)
			await frames()
			await click(b)
			await click(ui.confirm_button)
			s.production.elapse(60)
			return
	check(false,"workshop recipe missing "+id)
func run() -> void:
	await load_game()
	check(s.combat.enemies.has("tribe:1") and s.combat.enemies.has("tribe:2") and s.combat.enemies.has("tribe:3") and s.combat.tribe_members("forest").size()==20 and s.combat.tribe_members("barbarian").size()==20 and s.combat.tribe_members("yunye").size()==20,"three outlanders plus three twenty-member tribes exist without adding playable villagers")
	check(s.mining.UNDERGROUND.filter(func(r: Dictionary) -> bool: return r.kind=="iron_ore").size()*2 >=67,"finite iron supply supports iron house plus five buckets and bow")
	s.inventory.bags.ali=[]
	for i in range(21): s.inventory.bags.ali.append({})
	check(s.inventory.exchange("ali",{}, {"wood":450,"stone":300,"crude_iron":68,"iron_ore":2,"arrow":50,"workbench":1,"stone_axe":1}),"test supplies fit ordinary inventory")
	var wb: Node2D=s.grounds.add_fixture({"id":"outdoors:workshop","kind":"workbench","at":[870,1010],"size":[36,24]})
	outside(wb.position+Vector2(0,14))
	await key(KEY_T)
	check(s.production.opened and s.production.mode=="craft","T remains a shortcut to categorized workbench recipes")
	var wood_before:=count("wood")
	var stone_before:=count("stone")
	await craft_recipe("building_bench")
	check(count("wood")==wood_before-4 and count("stone")==stone_before-5 and count("building_bench")==1,"building bench recipe consumes four individual wood and five stone")
	await craft_recipe("iron_bucket")
	check(count("iron_bucket")==1 and count("crude_iron")==65,"iron bucket costs three crude iron")
	await craft_recipe("bow")
	check(count("bow")==1 and count("crude_iron")==63,"bow recipe consumes five wood and two crude iron")
	check(s.magic.equip_weapon("ali","bow"),"crafted bow equips before tower combat")
	await key(KEY_ESCAPE)
	outside(Vector2(900,980))
	await key(KEY_V)
	check(count("iron_bucket")==0 and count("sand_bucket")==1,"V on open desert fills one iron bucket with sand")
	check(s.inventory.exchange("ali",{}, {"building_bench":4,"sand_bucket":4}),"extra isolated building supplies fit")
	var wood_id: String=await construct(Vector2(740,850),0)
	check(s.construction.records[wood_id].hp==50 and not s.production.opened and s.grounds.fixtures.size()==3,"wood house has fifty health and consumes the deployed bench while keeping public workbenches")
	var home: Dictionary=s.world.home_data(wood_id)
	outside(home.door)
	await key(KEY_E)
	check(s.world.active_resident.room_id==wood_id and s.interiors.rooms[wood_id].fixtures.size()==4,"constructed house is enterable with wooden furniture and a straw mat")
	var chest: Node2D=s.interiors.rooms[wood_id].fixtures[1]
	s.inventory.ensure_container(chest.fixture_id)[0]={"item":"book","count":1}
	var chest_id: String=chest.fixture_id
	outside(home.door)
	var stone_id: String=await construct(Vector2(920,850),1)
	check(s.construction.records[stone_id].hp==100 and s.construction.records[stone_id].defense==10,"stone house has specified health and armor")
	check(s.construction.hit(stone_id,10) and s.construction.records[stone_id].hp==91,"ten defense mitigates ten percent, not ten flat damage")
	s.interiors.enter(s.world.active_resident,s.world.home_data(stone_id))
	s._sync_view()
	var attacker: CharacterBody2D=s.combat.enemies["tribe:2"]
	var original_at: Vector2=attacker.position
	attacker.position=s.world.home_data(stone_id).door+Vector2(0,8)
	attacker.cooldown=0
	attacker._physics_process(0)
	check(s.construction.records[stone_id].hp==82,"other-tribe attackers damage occupied houses through percentage armor")
	attacker.position=original_at
	var iron_id: String=await construct(Vector2(1100,850),2)
	check(s.construction.records[iron_id].hp==200 and s.construction.records[iron_id].defense==20 and count("sand_bucket")==0 and count("iron_bucket")==5,"iron house consumes five sand buckets and returns five empty iron buckets")
	check(s.construction.hit(iron_id,10) and s.construction.records[iron_id].hp==192,"twenty defense mitigates twenty percent")
	var tower_id: String=await construct(Vector2(1280,850),3)
	outside(s.world.home_data(tower_id).door)
	await key(KEY_E)
	await frames(5)
	check(s.world.active_resident.room_id==tower_id and s.world.visible and s.interiors.rooms[tower_id].get_meta("outdoor_roof",false),"tower entry directly places character on world-space roof with desert visible")
	var enemy: CharacterBody2D=s.combat.enemies["tribe:1"]
	if enemy.get_parent()==null: s.world.objects.add_child(enemy)
	enemy.position=s.world.active_resident.global_position+Vector2(65,0)
	enemy.set_physics_process(false)
	await physics_frame
	for i in range(40):
		s.combat.cooldown=0
		check(s.combat.fire(enemy.global_position),"tower can shoot a visible other-tribe enemy")
		await create_timer(0.3).timeout
	await create_timer(0.6).timeout
	check(enemy.hp==0 and not enemy.visible,"swept arrow hits defeat enemy without respawn")
	s.combat._process(600)
	check(enemy.hp==0,"elapsed time does not respawn defeated tribal enemies")
	check(not s.combat.fire(Vector2(-10000,-10000)),"cannot shoot outside viewport")
	outside(Vector2(1350,1020))
	var inactive: Dictionary=s.vitals.ensure("heya").duplicate(true)
	attacker=s.combat.enemies["tribe:3"]
	original_at=attacker.position
	attacker.position=s.world.active_resident.position+Vector2(0,8)
	attacker.cooldown=0
	var life_before: float=s.vitals.ensure("ali").life
	attacker._physics_process(0)
	check(s.vitals.ensure("ali").life==life_before-1 and s.vitals.ensure("heya")==inactive,"enemy melee damages only the controlled role and preserves inactive stat locking")
	attacker.position=original_at
	# Destroy an occupied house and preserve its recoverable storage in the ruins.
	outside(s.world.home_data(wood_id).door)
	s.interiors.enter(s.world.controllable[1],s.world.home_data(wood_id))
	check(s.magic.equip_weapon("ali","stone_axe"),"equip stone axe for demolition")
	for i in range(25):
		s.combat.demolition_cooldown=0
		await key(KEY_X)
	check(s.construction.records[wood_id].hp==0 and s.world.controllable[1].room_id=="" and s.world.home_data(wood_id).ruined,"zero health collapses house and safely evacuates occupants")
	check(s.magic.ensure("ali").weapon_wear.durability==39 and s.magic.ensure("ali").weapon_wear.uses==10,"twenty-five demolition uses cost one cell and ten partial uses")
	await key(KEY_E)
	check(s.world.active_resident.room_id==wood_id and s.inventory.ensure_container(chest_id)[0].item=="book","ruins remain searchable without deleting stored items")
	# Smelting uses online time, capacity protection and complete-session persistence.
	outside(s.world.home_data("kitchen").door)
	s.interiors.enter(s.world.active_resident,s.world.home_data("kitchen"))
	var room: Node2D=s.interiors.rooms.kitchen
	var stove: Node2D=room.fixtures.filter(func(f: Node2D) -> bool: return f.kind=="stove")[0]
	s.world.active_resident.position=stove.position+Vector2(0,16)
	s._sync_view()
	await key(KEY_T)
	await click(game.get_node("Workshop").buttons[0])
	await click(game.get_node("Workshop").confirm_button)
	check(s.production.smelting.remaining==30 and count("iron_ore")==1,"stove T consumes one ore for thirty online seconds")
	s.combat.cooldown=0.4
	s.overview=true
	s.world.set_overview(true)
	await create_timer(0.1,true).timeout
	check(s.production.smelting.remaining==30 and s.combat.cooldown==0.4,"overview freezes smelting, projectiles and combat timers")
	s.overview=false
	s.world.set_overview(false)
	s.production.elapse(29.5)
	check(s.production.smelting.ready==0,"smelting does not complete early")
	s.production.close()
	check(s.persistence.save_checkpoint(false),"checkpoint includes buildings and defeated enemy")
	var saved_buildings: Dictionary=s.construction.export_state()
	var saved_enemies: Dictionary=s.combat.export_state()
	check(s.persistence.save_now(),"autosave includes remaining half-second smelting")
	game.queue_free()
	await frames(5)
	await load_game()
	# Compare serialized form: saved float32 positions round-trip through the state file.
	check(JSON.stringify(s.construction.export_state())==JSON.stringify(saved_buildings) and JSON.stringify(s.combat.export_state())==JSON.stringify(saved_enemies) and s.production.smelting.remaining==0.5,"new process scene restores construction, enemy defeat and fractional smelting")
	s.production.elapse(0.5)
	check(s.production.smelting.ready==1,"remaining online half second completes coarse-time smelting")
	s.production.open_near()
	var bag: Array=s.inventory.ensure_bag("ali").duplicate(true)
	for i in range(21): s.inventory.bags.ali[i]={"item":"book","count":10}
	check(not s.production.perform("collect") and s.production.smelting.ready==1,"full inventory retains finished crude iron")
	s.inventory.bags.ali=bag
	check(s.production.perform("collect") and s.production.smelting.ready==0,"finished crude iron can be collected after freeing capacity")
	s.production.close()
	# Failed construction write restores bench and all materials, not a half-built house.
	await deploy(Vector2(1460,850))
	s.production.open_near()
	var before: Dictionary=s.construction.export_state()
	bag=s.inventory.ensure_bag("ali").duplicate(true)
	var blocked:=path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	s.inventory.path=blocked
	check(not s.production.perform("wood_house"),"failed construction write is reported")
	s.inventory.path=path
	check(s.construction.export_state()==before and s.inventory.ensure_bag("ali")==bag and s.grounds.fixtures.any(func(f: Node2D)->bool:return f.kind=="building_bench"),"failed build rolls back building, bench and materials together")
	check(s.persistence.restore_checkpoint() and s.construction.export_state()==saved_buildings and s.combat.enemies["tribe:1"].hp==0 and s.production.smelting.remaining==0.5,"altar rollback restores exact buildings, no-refresh enemy state and production progress")
	game.queue_free()
	await frames(5)
	if failures.is_empty(): print("CONSTRUCTION_SMOKE_OK")
	else: print("CONSTRUCTION_FAILURES: ",failures)
	quit(0 if failures.is_empty() else 1)
