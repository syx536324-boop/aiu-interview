# Verifies requested recipes, paid furniture, seed cycles, livestock, atomic rewards and renamed-app compatibility.
extends SceneTree
const Seeds := preload("res://features/forest/seed_patches.gd")
const Plant := preload("res://features/forest/plant.gd")
const Origin := preload("res://features/gifts/provenance.gd")
var game: Node
var s: Node
var failures: Array[String]=[]
var checks := 0
var path := ""
func _initialize() -> void:
	path="res://.runtime/rules-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	OS.set_environment("AIU5_WORLD_PROFILE","starter")
	create_timer(90,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n:=3) -> void:
	for i in range(n): await process_frame
func count(item: String,actor:="ali") -> int:
	var amount:=0
	for slot: Dictionary in s.inventory.ensure_bag(actor):
		if slot.get("item","")==item: amount+=int(slot.count)
	return amount
func give(items: Dictionary,actor:="ali") -> void:
	var slots: Array=[]
	for id: String in items: slots.append({"item":id,"count":items[id]})
	s.inventory.bags[actor]=s.inventory._sanitize_slots(slots)
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	s.vitals.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for animal in s.livestock.animals: animal.set_physics_process(false)
	await frames()
func outdoor() -> void:
	var actor: CharacterBody2D=s.world.active_resident
	if actor.room_id!="": s.interiors.leave(actor,s.world.objects,Vector2(322,300))
	s.production.close(); s.inventory.close(); s.editor.close(); s.attributes_id=""
	actor.dead=false
func station() -> Node2D:
	for fixture in s.grounds.fixtures:
		if fixture.fixture_id=="outdoors:public:desert": return fixture
	return null
func craft(id: String,ingredients: Dictionary) -> void:
	outdoor(); give(ingredients)
	var bench: Node2D=station()
	s.world.active_resident.position=bench.position+Vector2(0,15)
	s.production.open_near()
	check(s.production.mode=="craft" and s.production.perform(id),"start real recipe "+id)
	s.production.elapse(59)
	check(count(id)==0,"not ready before 60 seconds "+id)
	s.production.elapse(1)
	check(count(id)==1,"paid recipe returns one item "+id)
	s.production.close()
func run() -> void:
	await load_game()
	check(ProjectSettings.get_setting("application/config/name")=="沙盘上的生活","application renamed")
	check(OS.get_user_data_dir().replace("\\","/").ends_with("/Godot/app_userdata/AIU5 · 赤沙村"),"old save directory preserved")
	for actor in s.world.controllable:
		var bag: Array=s.inventory.ensure_bag(actor.resident_id)
		check(count("seeds",actor.resident_id)==3 and count("rice_seeds",actor.resident_id)==3,"initial seeds exactly three "+actor.resident_id)
		check(bag.filter(func(slot: Dictionary) -> bool: return not slot.is_empty()).size()==2,"no free starter tools, food, furniture or book "+actor.resident_id)
		s.inventory.grant_supplies(actor.resident_id)
		check(count("seeds",actor.resident_id)==3,"initial grant not repeated "+actor.resident_id)
	check(not s.magic.claim_gear("ali"),"free armor grant removed")
	check(s.achievements.definitions.is_empty(),"achievement definitions remain pending")
	check(not s.achievements.complete("ali","undefined"),"undefined achievement cannot award points")
	check(station()!=null and station().public_fixture,"public startup bench available")
	check(not s.world.navigation.find_path(s.world.active_resident.position,station().position+Vector2(0,15)).is_empty(),"public bench reachable from starting location")
	var pickup: Node2D=s.foraging.nodes["desert:0"]
	s.world.active_resident.position=pickup.position
	check(s.foraging.gather("desert:0") and count("wood")==1,"starter wood picked up through gameplay")
	check(not s.foraging.gather("desert:0"),"loose material cannot be duplicated")
	s.foraging.elapse(119); check(not pickup.available,"loose material waits two minutes")
	s.foraging.elapse(1); check(pickup.available,"loose material restores on deadline")
	var recipes := {"knife":{"wood":1,"stone":1},"iron_knife":{"wood":1,"crude_iron":1},"bowl":{"wood":2},"scissors":{"wood":1,"crude_iron":2},
		"hoe":{"wood":2,"stone":1},"watering_can":{"wood":2},"bread":{"wheat":3},"bucket":{"wood":3},"wooden_cup":{"wood":1},"workbench":{"wood":3,"stone":1},
		"fence":{"wood":4},"bed":{"wool":4,"wood":4},"cabinet":{"wood":5},"table":{"wood":4},"chair":{"wood":4},"chest":{"wood":5},
		"stone_axe":{"wood":1,"stone":2},"iron_axe":{"wood":1,"crude_iron":2},"wood_sword":{"wood":3},"stone_sword":{"wood":1,"stone":2},"iron_sword":{"wood":1,"crude_iron":2}}
	for id: String in recipes:
		check(s.production.RECIPES[id].cost==recipes[id],"recipe materials match requested rule "+id)
		craft(id,recipes[id])
	check(not s.production.RECIPES.has("book"),"book only available through gifts")
	for material in ["leather","iron"]:
		for part in {"armor":8,"leggings":5,"helmet":4,"boots":4}:
			var amount: int={"armor":8,"leggings":5,"helmet":4,"boots":4}[part]
			var id: String=material+"_"+part
			var ingredient: String="leather" if material=="leather" else "crude_iron"
			check(s.production.Smith.RECIPES["smith:"+id].cost=={ingredient:amount},"armor material rule "+id)
			outdoor(); give({ingredient:amount})
			s.interiors.enter(s.world.active_resident,s.world.home_data("blacksmith"))
			var room: Node2D=s.interiors.rooms.blacksmith
			for fixture in room.fixtures:
				if fixture.kind=="stove": s.world.active_resident.position=fixture.position+Vector2(0,14)
			s.production.open_near()
			check(s.production.perform("smith:"+id),"smith starts "+id)
			s.production.elapse(60)
			check(count(id)==1,"smith produced "+id)
	# Both crops return two seeds and do not harvest into a full bag.
	outdoor()
	for species in ["wheat","rice"]:
		give({})
		var plot: Dictionary=s.homestead.plots[0]
		plot.crop=species; plot.dry=false; plot.age=0; plot.growth=480
		s.homestead.refresh()
		s.world.active_resident.position=s.homestead.Land.bounds(plot).get_center()
		check(s.homestead.harvest(s.world.active_resident),"harvest "+species)
		check(count(species)==1 and count("seeds" if species=="wheat" else "rice_seeds")==2,"one crop plus two seeds "+species)
	# Grass selection is deterministic, periodic, persistent and contains one seed species.
	var first_period:=0
	for i in range(1000):
		var entry: Dictionary=Seeds.schedule(12345,"patch"+str(i),0)
		if entry.next==120: first_period+=1
		check(entry.next>=120 and entry.item in ["seeds","rice_seeds"],"valid patch schedule "+str(i))
	check(first_period>=150 and first_period<=250,"first period approximately 20 percent: "+str(first_period))
	var record: Dictionary={}
	for cell in [Vector2i(-2,1),Vector2i(-3,2),Vector2i(-5,4)]:
		for candidate: Dictionary in s.forest.generate(cell):
			if candidate.kind=="grass": record=candidate; break
		if not record.is_empty(): break
	check(not record.is_empty(),"forest biome produces actual grass")
	var plant:=Plant.new(); plant.configure(s.forest,record); s.world.objects.add_child(plant)
	s.forest.loaded[record.id]=plant
	s.forest.seed_patches[record.id]={"next":120.0,"item":"rice_seeds"}
	s.forest.online=119
	s.world.active_resident.position=record.at
	give({})
	check(not s.forest.gather(record.id),"seed not available before refresh")
	s.forest.elapse(1)
	check(s.forest.gather(record.id) and count("rice_seeds")==1 and count("seeds")==0,"grass yields one chosen species")
	check(not s.forest.gather(record.id),"grass seed cannot be collected twice")
	var forest_saved: Dictionary=s.forest.export_state()
	s.forest.restore(forest_saved)
	check(s.forest.export_state()==forest_saved,"seed deadline and species survive reload")
	# Sheep share pig/cow growth, food acceleration and pairing rules.
	outdoor(); give({"wheat":4})
	var sheep: CharacterBody2D=s.livestock.find_animal("sheep:1")
	check(sheep!=null and sheep.adult(),"initial adult sheep exists")
	for id in ["sheep:1","sheep:2"]:
		var parent: CharacterBody2D=s.livestock.find_animal(id)
		s.world.active_resident.position=parent.position
		check(s.livestock.feed_animal(s.world.active_resident,id,"wheat"),"feed breeding sheep "+id)
	var child: CharacterBody2D=s.livestock.find_animal("sheep:3")
	check(child!=null and not child.adult(),"fed opposite-sex adult sheep reproduce")
	s.livestock.advance(239); check(not child.adult(),"sheep needs five minutes")
	s.world.active_resident.position=child.position
	check(s.livestock.feed_animal(s.world.active_resident,child.animal_id,"wheat"),"feed juvenile reduces growth time")
	s.livestock.advance(1); check(child.adult(),"juvenile feed subtracts one minute")
	# Killing different creatures awards exactly once and drop quantities are atomic.
	give({})
	for entry in [{"id":"pig:1","drops":{"pork":1}},{"id":"cow:1","drops":{"leather":1,"beef":1}},{"id":"sheep:1","drops":{"mutton":1,"wool":2}},{"id":"bird:1","drops":{}},{"id":"dog:1","drops":{}}]:
		var target: CharacterBody2D=s.livestock.find_animal(entry.id)
		var previous: int=s.magic.ensure("ali").pending_points
		var amounts: Dictionary={}
		for item: String in entry.drops: amounts[item]=count(item)
		check(s.combat.hit_animal(target,10,"ali"),"kill actual creature "+entry.id)
		check(s.magic.ensure("ali").pending_points==previous+25,"kill adds twenty-five pending magic "+entry.id)
		check(not s.combat.hit_animal(target,10,"ali"),"dead creature cannot grant twice "+entry.id)
		for item: String in entry.drops: check(count(item)==amounts[item]+int(entry.drops[item]),"drop count "+entry.id+" "+item)
	var xp_before: int=s.magic.ensure("ali").pending_points
	check(s.combat.hit_enemy(s.combat.enemies["tribe:1"],100,"ali"),"enemy kill")
	check(s.magic.ensure("ali").pending_points==xp_before+25 and not s.combat.hit_enemy(s.combat.enemies["tribe:1"],100,"ali"),"enemy reward only once")
	var victim: CharacterBody2D=s.livestock.find_animal("sheep:2")
	var real_path: String=s.inventory.path
	var saved: Dictionary=s.inventory.export_data()
	s.inventory.path="res://project.godot/blocked.json"
	check(not s.combat.hit_animal(victim,10,"ali"),"failed save rejects kill")
	s.inventory.path=real_path
	check(s.livestock.find_animal("sheep:2")!=null and s.magic.ensure("ali").pending_points==int(saved.session.magic.residents.ali.pending_points),"failed kill rolls back creature and magic")
	check(s.inventory.ensure_bag("ali")==saved.bags.ali,"failed kill rolls back all drops")
	var full: Array=[]
	for i in range(21): full.append({"item":"book","count":10})
	s.inventory.bags.ali=s.inventory._sanitize_slots(full)
	var before_full: int=s.magic.ensure("ali").pending_points
	check(not s.combat.hit_animal(s.livestock.find_animal("sheep:2"),10,"ali"),"full bag blocks whole sheep kill")
	check(s.magic.ensure("ali").pending_points==before_full and s.livestock.find_animal("sheep:2").hp==10,"full bag keeps both drops and experience unawarded")
	# Actual arrows retain the shooter when the active character changes before impact.
	outdoor(); give({"bow":1,"arrow":1})
	check(s.magic.equip_weapon("ali","bow",0),"equip bow")
	var cow: CharacterBody2D=s.livestock.find_animal("cow:2")
	s.world.active_resident.position=cow.position+Vector2(0,20)
	s.world.streamer.focus(true)
	await frames(4); await physics_frame
	s.combat.cooldown=0
	var ali_before: int=s.magic.ensure("ali").pending_points
	var heya_before: int=s.magic.ensure("heya").pending_points
	check(s.combat.fire(cow.position+Vector2(0,-3)),"fire real arrow at cow")
	s.select_resident(1)
	for i in range(12): await physics_frame
	check(s.livestock.find_animal("cow:2")==null,"real arrow kills cow")
	check(s.magic.ensure("ali").pending_points==ali_before+25 and s.magic.ensure("heya").pending_points==heya_before,"arrow magic belongs to shooter after role switch")
	check(count("leather","ali")==1 and count("beef","ali")==1,"arrow drops belong to shooter")
	s.select_resident(0)
	# Every meat kind uses the same 60-second stove queue, preserved across reload.
	for raw in ["pork","beef","mutton"]:
		outdoor(); give({raw:1})
		s.interiors.enter(s.world.active_resident,s.world.home_data("kitchen"))
		var room: Node2D=s.interiors.rooms.kitchen
		for fixture in room.fixtures:
			if fixture.kind=="stove": s.world.active_resident.position=fixture.position+Vector2(0,14)
		s.inventory.selection={"side":"bag","index":0}
		s.use_selected()
		check(s.homestead.cooking.remaining==60 and count(raw)==0,"selected raw meat enters stove "+raw)
		s.homestead.elapse(37)
		var cooking_saved: Dictionary=s.homestead.export_state()
		s.homestead.restore(cooking_saved)
		check(s.homestead.cooking.remaining==23 and s.homestead.cooking.item=="cooked_"+raw,"cooking type and fractional job persist "+raw)
		s.homestead.elapse(23)
		s.interact()
		check(count("cooked_"+raw)==1,"collect matching cooked meat "+raw)
		s.vitals.ensure("ali").hunger=5; s.vitals.ensure("ali").health=6; s.vitals.ensure("ali").ill=true
		check(s.vitals.use_food("ali","cooked_"+raw),"eat cooked meat "+raw)
		check(s.vitals.ensure("ali").hunger==9 and s.vitals.ensure("ali").health==7 and not s.vitals.ensure("ali").ill,"cooked meat effects match pork "+raw)
	# Furniture can no longer be conjured for free; stored origins survive paid deployment/recovery.
	outdoor(); s.interiors.enter(s.world.active_resident,s.world.home_data("house"))
	var room: Node2D=s.interiors.rooms.house
	for fixture in room.fixtures.duplicate(): room.remove_fixture(fixture)
	s.editor.open(); give({})
	s.editor.choose("table"); check(s.editor.ghost==null,"no free table placement")
	for item in ["bed","cabinet","table","chair","chest"]:
		give({item:1}); s.editor.choose(item)
		s.editor.ghost.set_placement(Vector2(72,34),0)
		check(s.editor.place() and count(item)==0,"paid furniture deployment "+item)
		var fixture: Node2D=room.fixtures.back()
		s.editor.pick(fixture)
		check(s.editor.remove_selected() and count(item)==1,"furniture recovery "+item)
	give({})
	var gift: Dictionary={"item":"bed","count":1}; gift.merge(Origin.gifted("test:bed"))
	check(s.inventory.insert_record("ali",gift),"insert gifted bed")
	s.editor.choose_gift_bed(0); s.editor.ghost.set_placement(Vector2(72,34),0)
	check(s.editor.place(),"gifted bed deployment")
	s.editor.pick(room.fixtures.back()); check(s.editor.remove_selected(),"gifted bed recovery")
	check(Origin.magical(s.inventory.ensure_bag("ali")[0]),"gifted furniture retains source")
	s.editor.close()
	# A defined achievement is once-only and completion is part of the same save transaction.
	s.achievements.definitions={"probe":{"name":"test","description":"isolated test definition"},"probe_fail":{}}
	var pending: int=s.magic.ensure("ali").pending_points
	check(s.achievements.complete("ali","probe"),"defined achievement awards")
	check(s.magic.ensure("ali").pending_points==pending+100 and not s.achievements.complete("ali","probe"),"achievement exactly one hundred once")
	pending=s.magic.ensure("ali").pending_points; s.inventory.path="res://project.godot/blocked.json"
	check(not s.achievements.complete("ali","probe_fail"),"failed achievement save")
	s.inventory.path=real_path
	check(s.magic.ensure("ali").pending_points==pending and not s.achievements.completed.ali.has("probe_fail"),"achievement save failure rolls back completion and magic")
	outdoor(); s.world.active_resident.position=s.world.points.altar.position
	check(s.magic.awaken("ali","water"),"awaken with stored rewards")
	check(s.magic.ensure("ali").pending_points==0 and s.magic.ensure("ali").level>1,"stored rewards applied once on awakening")
	var migrated: Array=s.inventory._sanitize_slots([{"item":"armor","count":1},{"item":"hood","count":1,"is_magical":true,"gift_event_id":"legacy"}])
	check(migrated[0].item=="leather_armor" and migrated[1].item=="leather_helmet" and Origin.magical(migrated[1]),"legacy base armor migration preserves magical source")
	s.attributes_id="ali"; s.refresh_interface()
	var ui: Node=game.get_node("Attributes")
	ui.achievement_tab.pressed.emit()
	check(ui.achievement_root.visible and not ui.level_root.visible,"achievement tab displays")
	s.achievements.definitions={}; s.refresh_interface()
	check("待定" in ui.achievement_text.text and "100" in ui.achievement_text.text,"undefined achievements clearly marked in UI")
	s.attributes_id=""; s.refresh_interface()
	var complete_state: Dictionary=s.inventory.export_data()
	check(s.persistence.save_now(),"save all new domains")
	game.queue_free(); await frames(4); await load_game()
	check(s.inventory.saved_session.achievements==complete_state.session.achievements,"achievement completion survives actual restart")
	check(s.forest.export_state()==complete_state.session.forest,"grass refresh survives actual restart")
	check(s.magic.export_state()==complete_state.session.magic,"magic reward survives actual restart")
	check(s.livestock.export_state().animals.size()==complete_state.session.livestock.animals.size(),"dead animals do not respawn on restart")
	print("RULES_UPDATE_CHECKS=",checks)
	print("RULES_UPDATE_FAILURES=",JSON.stringify(failures))
	game.queue_free(); await frames(3)
	quit(0 if failures.is_empty() else 1)
