# Exercises real multitouch input, shared gameplay actions, lifecycle saves and native camera frames in isolation.
extends Node
var game: Node
var s: Node
var mobile: Node
var checks := 0
var failures: Array[String] = []
var directory := ""
var menu_app: Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS; call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame
func touch(index: int,at: Vector2,pressed: bool) -> void:
	var event := InputEventScreenTouch.new(); event.index = index; event.position = get_viewport().get_final_transform()*at; event.pressed = pressed
	Input.parse_input_event(event); await frames()
func tap(id: String,index := 1) -> void:
	var center: Vector2 = mobile.buttons[id].get_global_rect().get_center()
	await touch(index,center,true)
	if id == "back": await frames(12)
	await touch(index,center,false)
func spot() -> Vector2:
	var actor: Node = s.world.active_resident
	for y in range(400,1200,32):
		for x in range(600,1400,32):
			actor.position=Vector2(x+5,y+7); s._refresh_nearest()
			if s.nearest!="" or not s.grounds.nearby(actor).is_empty() or s.homestead.standing_plot(actor): continue
			if s.world.residents.any(func(other: Node)->bool:return other!=actor and other.room_id=="" and other.position.distance_to(actor.position)<64): continue
			var near:=false
			for id: String in s.tribes.population.members:
				var other: Node=s.tribes.population.node(id)
				if is_instance_valid(other) and other.room_id=="" and other.position.distance_to(actor.position)<64: near=true;break
			if not near and s.grounds.land_error(s.homestead.till_bounds(actor),actor,false)=="": return actor.position
	return Vector2.INF
func run() -> void:
	directory=OS.get_environment("AIU5_BENCH_DIR")
	if directory=="": directory=ProjectSettings.globalize_path("user://android-qa")
	DirAccess.make_dir_recursive_absolute(directory)
	for pair: Array in [["AIU5_STATE_PATH","state.json"],["AIU5_PROFILE_PATH","names.cfg"],["AIU5_SAVES_DIR","slots"],["AIU5_LEGACY_PATH","absent.json"],["AIU5_LEGACY_PROFILE_PATH","absent.cfg"]]: OS.set_environment(pair[0],directory+"/"+pair[1])
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2"); OS.set_environment("AIU5_MOBILE_PREVIEW","1")
	game=load("res://scenes/main.tscn").instantiate(); add_child(game); await frames(8)
	s=game.get_node("Session"); mobile=game.get_node("MobileControls")
	s.simulation.set_process(false);s.persistence.set_process(false);s.world.streamer.set_process(false)
	check(s.orchard.records.keys().filter(func(id: String)->bool:return id.begins_with("starter_")).size()==3,"main village receives three mature apple trees")
	check(s.orchard.records.keys().filter(func(id: String)->bool:return id.begins_with("forest_")).size()==20,"forest tribe receives twenty mature apple trees")
	check(mobile.buttons.has("apple") and mobile.buttons.run.position==Vector2(548,318),"planting is reachable without changing bottom-right run layout")
	s._set_notice("走到门口按e开门")
	check("按交互" in game.get_node("HUD").notice_label.text and "按e" not in game.get_node("HUD").notice_label.text,"phone notices translate lowercase interaction key")
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values(): enemy.set_physics_process(false)
	check(mobile.root.visible and mobile.movement.visible,"mobile controls activate only for mobile presentation")
	check(not game.get_node("HUD").help_label.visible,"keyboard-only footer is hidden for touch presentation")
	s.refresh_interface();await frames()
	check(not game.get_node("HUD").belongings_hint.visible and not game.get_node("HUD").skill_hint.visible and "按 E" not in game.get_node("OnboardingView").detail.text,"normal refresh preserves touch HUD and onboarding instructions")
	var actor: Node=s.world.active_resident
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,Vector2(600,500))
	actor.position=spot();s._sync_view();s.refresh_interface();await frames()
	check(actor.position.is_finite(),"isolated farmland is available")
	var stick: Vector2=mobile.movement.get_global_rect().get_center()+Vector2(35,0)
	await touch(0,stick,true)
	check(Input.is_action_pressed("move_right") and mobile.movement.finger==0,"first finger controls continuous analog movement")
	var walk_start: Vector2=actor.position;actor.set_physics_process(true);await frames(8);actor.set_physics_process(false)
	check(actor.position.distance_to(walk_start)>0.1,"virtual movement drives actual collision-aware character movement")
	await tap("run")
	check(Input.is_action_pressed("move_right") and mobile.movement.finger==0,"second finger action does not steal the movement finger")
	var run_at: Vector2=mobile.buttons.run.get_global_rect().get_center()
	await touch(1,run_at,true);check(Input.is_action_pressed("run"),"run supports holding alongside the joystick")
	await touch(1,run_at,false);check(not Input.is_action_pressed("run"),"run releases without leaving a stuck key")
	await tap("bag")
	check(s.inventory.opened and not mobile.movement.visible and not Input.is_action_pressed("move_right"),"opening a panel releases held movement")
	await touch(0,stick,false);await tap("back")
	check(not s.inventory.opened and mobile.movement.visible,"touch back closes the bag and restores controls")
	var id: String=actor.resident_id
	s.inventory.bags[id]=s.inventory._sanitize_slots([{"item":"hoe","count":1}])
	check(s.magic.equip_weapon(id,"hoe"),"ordinary inventory hoe equips through the shared domain")
	actor.position=spot();s._sync_view();s.refresh_interface();await frames()
	var total: int=s.homestead.plots.size()
	await tap("interact")
	check(s.homestead.plots.size()==total,"touch interaction retains E behavior and cannot till")
	await tap("more");check(mobile.tools.visible,"more exposes farming construction and magic actions")
	await tap("till")
	check(s.homestead.plots.size()==total+1 and s.homestead.Land.bounds(s.homestead.plots.back()).has_point(actor.position),"touch farming cultivates the feet through the same Q domain")
	check(s.magic.ensure(id).weapon_wear.uses==1,"one mobile cultivation uses the hoe once")
	await tap("more")
	actor.position=spot();s._sync_view();s.refresh_interface();await frames()
	var enemy: Node
	for candidate: Node in s.combat.enemies.values():
		if not candidate.has_meta("goblin") and not candidate.friendly: enemy=candidate;break
	check(is_instance_valid(enemy),"hostile target exists for actual touch combat")
	if is_instance_valid(enemy):
		if enemy.get_parent()==null: s.world.objects.add_child(enemy)
		enemy.room_id="";enemy.position=actor.position+Vector2(24,0);enemy.hp=30;enemy.refresh();await frames(8)
		var at: Vector2=actor.get_canvas_transform()*(enemy.global_position+Vector2(0,-8));s.combat.cooldown=0
		await touch(2,at,true);await touch(2,at,false)
		check(enemy.hp==29,"tapping the enemy causes actual ordinary weapon damage")
		s.combat.cooldown=0;await touch(0,stick,true);await touch(1,at,true);await touch(1,at,false)
		check(enemy.hp==28 and Input.is_action_pressed("move_right"),"movement and touch attack work simultaneously with separate fingers")
		await touch(0,stick,false);enemy.position=Vector2(2500,2500)
	await tap("map");check(s.overview and not mobile.movement.visible,"touch map opens the normal paused overview")
	await tap("back");check(not s.overview and mobile.movement.visible,"touch back exits overview")
	var previous: int=s.selected;await tap("switch")
	check(s.selected!=previous,"touch switch selects another living controllable character")
	check(not mobile.aim.is_finite(),"switching characters clears a stale target")
	game.queue_free();await frames(8)
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("run"),"scene teardown releases all virtual inputs")
	OS.set_environment("AIU5_MOBILE_PREVIEW","")
	if not OS.has_feature("android"):
		game=load("res://scenes/main.tscn").instantiate();add_child(game);await frames(8)
		check(not game.has_node("MobileControls"),"desktop game keeps its original keyboard and mouse presentation")
		game.queue_free();await frames(8)
	OS.set_environment("AIU5_MOBILE_PREVIEW","1")
	menu_app=load("res://features/mobile/bootstrap.gd").new();add_child(menu_app);await frames(10)
	check(menu_app.menu.view.visible,"Android bootstrap displays the real start menu")
	menu_app.menu.create_game("安卓隔离验收");await frames(35)
	check(is_instance_valid(menu_app.menu.game),"start menu creates and launches an isolated save")
	if is_instance_valid(menu_app.menu.game):
		game=menu_app.menu.game;s=game.get_node("Session");mobile=game.get_node("MobileControls")
		if OS.has_feature("android"):
			check(Engine.has_singleton("AiuGiftCamera"),"Android native camera plugin is registered")
			actor=s.world.active_resident;actor.position=s.world.point_info("altar").position;s._sync_view()
			check(s.gifts.open_menu(),"native camera is reached through the actual altar")
			s.gifts.begin_camera()
			var deadline: int=Time.get_ticks_msec()+30000
			while not s.gifts.received and Time.get_ticks_msec()<deadline: await frames()
			check(s.gifts.received and s.gifts.frame_jpeg!="" and s.gifts.sequence>0,"Camera2 plus local ONNX inference produces actual phone preview snapshots")
			s.gifts.close();await frames(20)
			check(not Engine.get_singleton("AiuGiftCamera").isCameraOpen(),"closing the gift panel releases the actual Camera2 device")
		if OS.has_feature("android"):
			actor=s.world.active_resident
			actor.position=s.orchard.nodes["starter_0"].position+Vector2(0,22)
			s._sync_view();s.refresh_interface();await frames(12)
			check(get_viewport().get_texture().get_image().save_png(directory+"/apple-tree.png")==OK,"actual Android apple-tree presentation captured")
			for bench: Node2D in s.grounds.fixtures:
				if bench.kind!="workbench": continue
				actor.position=bench.collision_bounds().get_center()+Vector2(0,22)
				s._sync_view();s.production.open_near();await frames(6)
				var workshop: Node=game.get_node("Workshop")
				workshop.selected_id="pickaxe";workshop.category="all";workshop._render();await frames(12)
				check(s.production.opened and "用途：" in workshop.details.text and "合成材料" in workshop.details.text,"Android workbench presents actual tool purpose and material requirements")
				check(get_viewport().get_texture().get_image().save_png(directory+"/tool-purpose.png")==OK,"actual Android workshop presentation captured")
				s.production.close();await frames(6);break
		var state_path: String=s.inventory.path
		await touch(0,mobile.movement.get_global_rect().get_center()+Vector2(35,0),true)
		menu_app._notification(NOTIFICATION_APPLICATION_PAUSED);await frames(10)
		check(s.menu_paused and get_tree().paused,"background lifecycle pauses the game")
		check(FileAccess.file_exists(state_path) and JSON.parse_string(FileAccess.get_file_as_string(state_path)) is Dictionary,"background lifecycle saves valid state")
		check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("run"),"background lifecycle releases movement and sprint")
		menu_app.menu.resume_game();await frames(5)
		check(not get_tree().paused and not s.menu_paused,"resume returns to the playable session")
		menu_app.menu.return_home();await frames(15)
		check(not is_instance_valid(menu_app.menu.game) and menu_app.menu.library.slots().size()>0,"return home preserves the Android save library")
	menu_app.queue_free();await frames(8)
	var result: Dictionary={"version":ProjectSettings.get_setting("application/config/version"),"android":OS.has_feature("android"),"display":DisplayServer.get_name(),"checks":checks,"failures":failures}
	var file:=FileAccess.open(directory+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("MOBILE_OK" if failures.is_empty() else "MOBILE_FAILED"," ",JSON.stringify(result))
	if OS.has_feature("android") and failures.is_empty():
		if is_instance_valid(game):game.queue_free()
		await frames(5)
		OS.set_environment("AIU5_BENCH_DIR",ProjectSettings.globalize_path("user://workbench-qa"))
		var next: Node=load("res://tests/workbench_update_probe.tscn").instantiate();get_parent().add_child(next)
		queue_free()
	else:get_tree().quit(0 if failures.is_empty() else 1)

