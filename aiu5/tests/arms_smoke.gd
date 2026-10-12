# Verifies requested recipes, actual melee damage, ammunition transactions and persistent tree/tool rules.
extends SceneTree
var game: Node
var s: Node
var failures: Array[String] = []
var path := ""
func _initialize() -> void:
	path="res://.runtime/arms-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	OS.set_environment("AIU5_WORLD_SEED","7319")
	create_timer(70,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n:=3) -> void:
	for i in range(n): await physics_frame
	await process_frame
func count(item: String) -> int:
	var total:=0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: total+=int(slot.count)
	return total
func equip(item: String) -> void:
	check(s.magic.equip_weapon("ali",item),"equip "+item)
	s.combat.cooldown=0
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for a in s.world.residents: a.set_physics_process(false)
	for e in s.combat.enemies.values(): e.set_physics_process(false)
	await frames()
	check(not s.inventory.Catalog.ITEMS.has("wood_axe"),"no wooden axe item")
	check(s.inventory._sanitize_slots([{"item":"wood_axe","count":1}])[0].item=="stone_axe","legacy axes migrate in bags and containers")
	check(s.magic.Catalog.restore_state({"equipment":{"weapon":"wood_axe"}}).equipment.weapon=="stone_axe","legacy equipped axe migrates")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"wood","count":99},{"item":"stone","count":99},{"item":"crude_iron","count":99}])
	var bench: Node2D=s.grounds.add_fixture({"id":"outdoors:armsbench","kind":"workbench","at":[740,1010],"size":[36,24]})
	var actor: CharacterBody2D=s.world.active_resident
	actor.position=bench.position+Vector2(0,14)
	s.production.open_near()
	var costs: Dictionary={"stone_axe":{"wood":1,"stone":2},"stone_sword":{"wood":1,"stone":2},"wood_sword":{"wood":3},"iron_sword":{"wood":1,"crude_iron":2},"iron_axe":{"wood":1,"crude_iron":2},"arrow":{"wood":2,"crude_iron":1},"pickaxe":{"wood":1,"stone":2},"bow":{"wood":5,"crude_iron":2}}
	for item: String in costs:
		var before: Dictionary={"wood":count("wood"),"stone":count("stone"),"crude_iron":count("crude_iron")}
		check(s.production.perform(item),"start craft "+item)
		s.production.elapse(60.0)
		for ingredient: String in before: check(count(ingredient)==before[ingredient]-int(costs[item].get(ingredient,0)),"exact material cost "+item+"/"+ingredient)
		check(count(item)==(10 if item=="arrow" else 1),"exact yield "+item)
	s.refresh_interface()
	check(game.get_node("Workshop").buttons.filter(func(b: Button) -> bool: return b.visible).size()==s.production.snapshot().recipes.size(),"all recipes represented in categorized workshop")
	s.production.close()
	var tree: Node2D=s.harvesting.trees["deadwood_01"]
	actor.position=tree.position+Vector2(0,18)
	check(not s.harvesting.chop(tree.resource_id,actor) and tree.hits==0,"bag axe cannot chop")
	equip("stone_axe")
	check(s.harvesting.chop(tree.resource_id,actor) and tree.hits==1,"equipped axe chops")
	var ore: Node2D=s.mining.surface["surface:1"]
	actor.position=ore.position+Vector2(0,18)
	check(not s.mining.strike(actor,ore) and ore.hits==0,"bag pickaxe cannot mine with axe equipped")
	equip("pickaxe")
	check(s.mining.strike(actor,ore) and ore.hits==1,"equipped pickaxe mines")
	# Place a real enemy in open space and apply every stated initial attack value.
	actor.position=Vector2(1330,1250)
	s.world.streamer.focus(true)
	var enemy: CharacterBody2D=s.combat.enemies["tribe:1"]
	if enemy.get_parent()==null: s.world.objects.add_child(enemy)
	enemy.position=actor.position+Vector2(20,0)
	enemy.hp=100
	enemy.refresh()
	enemy.set_physics_process(false)
	await frames()
	for weapon: String in ["wood_sword","stone_sword","stone_axe","iron_sword","iron_axe","pickaxe"]:
		equip(weapon)
		var hp: float=enemy.hp
		check(s.combat.fire(enemy.global_position),"melee accepts "+weapon)
		check(hp-enemy.hp==s.combat.Gear.damage(weapon),"actual damage matches "+weapon)
		check(not s.combat.fire(enemy.global_position),"cooldown prevents repeated melee")
	# Move enemy away so test arrows do not affect melee fixtures.
	enemy.position+=Vector2(200,0)
	equip("bow")
	var arrows:=count("arrow")
	check(s.combat.fire(actor.position+Vector2(80,0)) and count("arrow")==arrows-1,"one successful shot consumes one arrow")
	check(not s.combat.fire(actor.position+Vector2(80,0)) and count("arrow")==arrows-1,"cooldown consumes no ammunition")
	s.combat.cooldown=0
	check(not s.combat.fire(actor.position+Vector2(10000,0)) and count("arrow")==arrows-1,"invalid target consumes no ammunition")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"arrow","count":1}])
	var original: String=s.inventory.path
	var blocked:=path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	s.inventory.path=blocked
	check(not s.combat.fire(actor.position+Vector2(80,0)) and count("arrow")==1 and s.combat.cooldown==0,"failed save rolls back ammunition and rejects shot")
	s.inventory.path=original
	check(s.combat.fire(actor.position+Vector2(80,0)) and count("arrow")==0,"last arrow can be fired")
	s.combat.cooldown=0
	check(not s.combat.fire(actor.position+Vector2(80,0)),"empty bag prevents bow attack")
	# Empty hands gather leaves; axes chop the same mulberry and permanently remove it.
	equip("")
	actor.position=Vector2(-700,400)
	s.world.streamer.focus(true)
	await frames(90)
	var id: String=""
	for key: String in s.forest.loaded:
		if s.forest.loaded[key].record.kind=="mulberry": id=key; break
	check(id!="","mulberry fixture streamed")
	if id!="":
		var at: Vector2=s.forest.loaded[id].position
		actor.position=at+Vector2(0,18)
		check(s.forest.gather(id) and count("mulberry_leaf")==1,"empty hands gather leaves without chopping")
		s.inventory.exchange("ali",{}, {"stone_axe":1,"wood_sword":1})
		equip("wood_sword")
		check(not s.forest.gather(id),"sword cannot gather leaves or chop mulberry")
		equip("stone_axe")
		var wood:=count("wood")
		var wear_before: Dictionary=s.magic.ensure("ali").weapon_wear.duplicate()
		for i in range(4):
			s.forest.chop_cooldown=0
			check(s.forest.gather(id),"axe interaction chops mulberry "+str(i))
		check(count("wood")==wood+2 and not s.forest.loaded.has(id),"four cuts remove tree and award two wood")
		var after_wear: Dictionary=s.magic.ensure("ali").weapon_wear
		check((40-after_wear.durability)*15+after_wear.uses == (40-wear_before.durability)*15+wear_before.uses+4,"forest axe consumes exactly four uses")
		check(s.persistence.save_now(),"save felled mulberry")
		var saved: Dictionary=s.inventory.export_data()
		s.inventory.apply_data(saved)
		s.persistence.restore_session(saved.session)
		actor.position=at+Vector2(0,18)
		s.world.streamer.focus(true)
		await frames(90)
		check(int(s.inventory.resource_hits.get(id,0))==4 and not s.forest.loaded.has(id) and not s.world.points.has("herb:"+id),"felled mulberry never respawns on restore")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("ARMS_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
