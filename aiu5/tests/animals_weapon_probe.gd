# Exercises real livestock colliders through clicked melee/J and swept bow flight, in a unique save.
extends Node
const Gear := preload("res://features/combat/weapon_catalog.gd")
const Herd := preload("res://features/livestock/herd_catalog.gd")
var directory := ""
var game: Node
var s: Node
var checks := 0
var failures: Array[String]=[]
var serial := 0
var base := Vector2(1300,2000)
func _enter_tree() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	var parent := OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(parent!="" and parent.is_absolute_path())
	directory=parent.path_join("animals-weapons-"+str(Time.get_ticks_usec()))
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
	OS.set_environment("AIU5_STATE_PATH",directory.path_join("state.json"))
	OS.set_environment("AIU5_PROFILE_PATH",directory.path_join("names.cfg"))
	OS.set_environment("AIU5_WORLD_PROFILE","starter_v2")
	OS.set_environment("AIU5_WORLD_SEED","92092")
	get_tree().create_timer(85,true).timeout.connect(func()->void:get_tree().quit(2))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await get_tree().physics_frame
	await get_tree().process_frame
func wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds,true).timeout
	await frames()
func count(item: String) -> int:
	var result := 0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: result+=int(slot.count)
	return result
func points() -> int: return int(s.magic.ensure("ali").pending_points)
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); game.process_mode=Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(game); s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	s.resources.set_process(false); s.world.streamer.set_process(false); s.forest.set_process(false)
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	for enemy: Node in s.combat.enemies.values(): enemy.set_physics_process(false)
	for animal: Node in s.livestock.animals: animal.set_physics_process(false)
	s.world.active_resident.position=base; s._sync_view(); s.world.streamer.set_process(false)
	s.world.camera.force_update_scroll(); await frames(6)
func equip(item: String) -> void:
	check(s.magic.equip_weapon("ali",item),"normal inventory equips "+item)
	# Set a fixture's initial cooldown only; duplicate clicks and waits use real combat frames.
	s.combat.cooldown=0
func make_animal(kind: String,adult: bool,wild: bool,distance := 20.0) -> Node:
	serial+=1
	var id := "wild:5:7:"+str(serial) if wild else kind+":"+str(700+serial)
	var area := Rect2(base-Vector2(160,80),Vector2(320,160))
	var animal: Node=s.livestock._spawn(id,kind,"female",300.0 if adult else 0.0,base+Vector2(distance,0),area if wild else Rect2())
	assert(animal!=null)
	animal.pen_bounds=area; animal.position=base+Vector2(distance,0); animal.set_physics_process(false)
	s.livestock._refresh_points()
	return animal
func right_mouse(at: Vector2) -> void:
	var point: Vector2=s.world.active_resident.get_canvas_transform()*at
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_RIGHT
		event.position=point; event.global_position=point; event.pressed=pressed
		Input.parse_input_event(event); await frames(1)
func record(id: String,kind: String,hp: float) -> Dictionary:
	return {"id":id,"species":kind,"hp":hp,"growth":300.0,"sex":"female",
		"position":[base.x+20,base.y],"wild_bounds":[base.x-80,base.y-60,160,120]}
func run() -> void:
	await load_game()
	check(s.inventory.path.begins_with(directory),"all combat and saves use the unique isolated path")
	# Make kill rewards measurable independently of first-discovery achievements.
	var seen := {}
	for id: String in s.achievements.definitions: seen[id]=true
	s.achievements.completed.ali=seen
	s.inventory.bags.ali=s.inventory._sanitize_slots([])
	check(s.inventory.exchange("ali",{}, {"iron_sword":1,"bow":1,"arrow":40}),"supply test equipment through inventory")
	equip("iron_sword")
	for kind: String in ["pig","cow","sheep"]:
		for adult: bool in [false,true]:
			for wild: bool in [false,true]:
				var animal: Node=make_animal(kind,adult,wild)
				var id: String=animal.animal_id
				await frames()
				check(animal.hp==10 and animal.max_hp==10,"ten HP "+id)
				check(animal.is_in_group("creature_targets"),"physical animal target "+id)
				var expected: Dictionary=Herd.drops(kind,adult)
				var before_drops := {}
				for item: String in expected: before_drops[item]=count(item)
				var before_points := points()
				s.combat.cooldown=0
				# At least one creature is attacked through the real Session right-button input.
				if kind=="pig" and adult and not wild:
					await right_mouse(animal.attack_bounds().get_center())
					check(animal.hp==5,"real right mouse input damages the visible pig body")
				else:
					check(s.combat.attack_clicked(animal.attack_bounds().get_center()),"clicked weapon attacks "+id)
					check(animal.hp==5,"first actual sword strike removes five HP "+id)
				check(not s.combat.attack_clicked(animal.attack_bounds().get_center()) and animal.hp==5,
					"same-interval click cannot hit twice "+id)
				await wait_real(Gear.interval("iron_sword")+0.1)
				check(s.combat.fire(animal.global_position),"normal J fire path lands the lethal melee strike "+id)
				check(s.livestock.find_animal(id)==null and s.livestock.dead_ids.has(id),"dead identity removed and remembered "+id)
				check(points()==before_points+25,"one kill awards exactly25 points "+id)
				for item: String in expected:
					check(count(item)==int(before_drops[item])+int(expected[item]),"confirmed drop count "+id+"/"+item)
				check(not s.combat.hit_animal(animal,10,"ali"),"dead target rejects duplicate kill "+id)
				check(points()==before_points+25,"duplicate kill cannot award points "+id)
				await frames()

	equip("bow")
	var cow: Node=make_animal("cow",true,true,90)
	await frames()
	var arrows := count("arrow")
	check(s.combat.attack_clicked(cow.attack_bounds().get_center()),"clicked bow accepts an in-range cow")
	check(count("arrow")==arrows-1,"successful bow shot consumes exactly one arrow")
	check(not s.combat.attack_clicked(cow.attack_bounds().get_center()) and count("arrow")==arrows-1,
		"bow cooldown blocks another shot and another arrow charge")
	await wait_real(0.5)
	check(cow.hp==9,"real swept arrow collider deals base bow damage to ten-HP cow")
	await wait_real(0.7)
	cow.hp=1 # A wounded fixture lets the next real arrow test lethal rewards without ten waits.
	var cow_id: String=cow.animal_id
	var before_points := points(); var hides := count("cowhide"); var beef := count("beef")
	check(s.combat.attack_clicked(cow.attack_bounds().get_center()),"second timed bow shot accepted")
	await wait_real(0.5)
	check(s.livestock.find_animal(cow_id)==null and points()==before_points+25,
		"real lethal arrow removes the cow and awards one kill")
	check(count("cowhide")==hides+1 and count("beef")==beef+1,"arrow preserves cowhide and beef drops")
	await wait_real(0.7)
	check(points()==before_points+25 and count("cowhide")==hides+1,"arrow reward is not repeated on later physics frames")
	var pig: Node=make_animal("pig",false,false,80)
	var wall: Node=s.world._body(s.world.objects,base+Vector2(40,-4),Vector2(12,30))
	await frames()
	arrows=count("arrow")
	check(not s.combat.attack_clicked(pig.attack_bounds().get_center()) and count("arrow")==arrows,
		"wall blocks clicked targeting before ammunition is spent")
	check(s.combat.fire(pig.global_position),"J may fire toward a wall with one normal arrow cost")
	await wait_real(0.5)
	check(pig.hp==10 and count("arrow")==arrows-1,"swept arrow stops on the wall and cannot hurt the animal")
	wall.queue_free(); await frames(); await wait_real(0.7)
	pig.position=base+Vector2(Gear.attack_range("bow")+1,0)
	await frames()
	arrows=count("arrow")
	check(not s.combat.attack_clicked(pig.attack_bounds().get_center()) and count("arrow")==arrows,
		"animal out of bow range is rejected without an arrow charge")

	# Older records migrate health only; an explicit empty population stays empty.
	s.livestock.restore({"animals":[record("cow:900","cow",24),record("pig:901","pig",2.5),
		record("sheep:902","sheep",0),record("wild:4:5:99","pig",-2),record("cow:903","cow",0.005)],
		"fauna_version":0,"herd_version":0})
	check(s.livestock.animals.size()==3,"old record migration invents no extra cows pigs sheep or fauna")
	check(s.livestock.find_animal("cow:900").hp==10,"old health above ten clamps to ten")
	check(s.livestock.find_animal("pig:901").hp==2.5 and s.livestock.find_animal("cow:903").hp==0.005,
		"low old health is preserved without healing")
	check(s.livestock.find_animal("sheep:902")==null and s.livestock.find_animal("wild:4:5:99")==null,
		"old zero or negative health never revives")
	s.wildlife.restore({"generated":{},"tethers":{}})
	check(s.wildlife.generated.has("4:5"),"dead old wild record keeps its first-generated cell consumed")
	var old_count: int=s.livestock.animals.size()
	s.wildlife._generate(Vector2i(4,5)); s.wildlife._generate(Vector2i(4,5))
	check(s.livestock.animals.size()==old_count and s.livestock.find_animal("wild:4:5:99")==null,
		"revisiting the consumed cell neither revives nor replenishes the herd")
	check(s.persistence.save_now(),"migration and dead identities save through the normal session path")
	game.queue_free(); await frames(4); await load_game()
	check(s.livestock.find_animal("cow:900").hp==10 and s.livestock.find_animal("pig:901").hp==2.5,
		"restart preserves health migration")
	check(s.livestock.find_animal("sheep:902")==null and s.livestock.dead_ids.has("sheep:902"),
		"restart preserves the animal death record")
	s.livestock.restore({"animals":[]},[])
	check(s.livestock.animals.is_empty(),"explicit empty old herd does not repopulate")
	s.livestock.restore({},[{"position":[410,247],"hp":3}])
	check(s.livestock.animals.size()==1 and s.livestock.find_animal("pig:1").hp==3,
		"legacy fallback restores only the one recorded pig")
	game.queue_free(); await frames()
	print("ANIMALS_WEAPON_FAILURES="+JSON.stringify(failures))
	if failures.is_empty(): print("ANIMALS_WEAPON_PROBE_OK checks="+str(checks))
	get_tree().quit(0 if failures.is_empty() else 1)
