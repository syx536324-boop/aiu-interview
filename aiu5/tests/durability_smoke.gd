# Checks durability boundaries, per-instance transfers, gathering costs and durable rollback.
extends SceneTree
const Wear := preload("res://features/combat/durability.gd")
var game: Node
var s: Node
var failures: Array[String] = []
var path := ""
func _initialize() -> void:
	path="res://.runtime/durability-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(n:=3) -> void:
	for i in range(n): await process_frame
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	await frames()
func wear() -> Dictionary:
	return s.magic.ensure("ali").weapon_wear
func bag_weapon(item: String) -> Dictionary:
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: return slot
	return {}
func run() -> void:
	var counter := Wear.normalize()
	for i in range(599): check(Wear.consume(counter),"use before break")
	check(counter.durability==1 and counter.uses==14,"599 uses leave one cell with fourteen uses")
	check(Wear.consume(counter) and counter.durability==0 and counter.uses==0,"600th use breaks weapon")
	check(not Wear.consume(counter),"broken record cannot consume again")
	await load_game()
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"wood_sword","count":1},{"item":"wood_sword","count":1,"durability":12,"uses":7}])
	check(s.magic.equip_weapon("ali","wood_sword",0),"equip fresh sword instance")
	for i in range(14):
		s.combat.cooldown=0
		check(s.combat.fire(s.world.active_resident.position+Vector2(60,0)),"swing consumes one use")
	check(wear().durability==40 and wear().uses==14,"fourteen actual swings keep forty cells")
	s.combat.cooldown=0
	check(s.combat.fire(s.world.active_resident.position+Vector2(60,0)),"fifteenth swing succeeds")
	check(wear().durability==39 and wear().uses==0,"fifteenth swing consumes first cell")
	check(s.magic.equip_weapon("ali","wood_sword",1) and wear().durability==12 and wear().uses==7,"same-type selected worn instance swaps without resetting")
	check(s.magic.equip_weapon("ali",""),"unequip worn instance")
	s.inventory.actor_id="ali"
	s.inventory.open_container("ali","阿砾","durability:chest","测试箱")
	s.inventory.quick_transfer("bag",1)
	check(s.inventory.containers["durability:chest"][0].durability==12 and s.inventory.containers["durability:chest"][0].uses==7,"quick storage preserves wear")
	s.inventory.quick_transfer("storage",0)
	check(s.inventory.bags.ali[1].durability==12,"quick retrieval preserves wear")
	s.inventory.bags.heya=s.inventory._sanitize_slots([{"item":"wood_sword","count":1,"durability":33,"uses":2}])
	s.inventory.transfer_slots(s.inventory.bags.ali,1,s.inventory.bags.heya,0)
	check(s.inventory.bags.heya[0].durability==12 and s.inventory.bags.ali[1].durability==33,"same-type cross-character swap keeps each instance")
	s.inventory.close()
	check(s.magic.equip_weapon("heya","wood_sword",0),"other character equips shared used sword")
	check(s.magic.ensure("heya").weapon_wear.durability==12 and s.magic.ensure("heya").weapon_wear.uses==7,"other character receives same partial counter")
	check(s.magic.equip_weapon("ali","wood_sword",0),"re-equip original sword")
	wear().uses=6
	check(s.persistence.save_now(),"save partial wear")
	game.queue_free()
	await frames()
	await load_game()
	check(wear().durability==39 and wear().uses==6,"restart retains cells and partial use counter")
	check(s.magic.ensure("heya").weapon_wear.durability==12 and s.magic.ensure("heya").weapon_wear.uses==7,"restart retains independent other character wear")
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"bow","count":1},{"item":"arrow","count":1},{"item":"stone_axe","count":1},{"item":"pickaxe","count":1}])
	check(s.magic.equip_weapon("ali","bow",0),"equip bow")
	s.combat.cooldown=0
	check(s.combat.fire(s.world.active_resident.position+Vector2(60,0)) and wear().uses==1,"bow shot uses once")
	s.combat.cooldown=0
	check(not s.combat.fire(s.world.active_resident.position+Vector2(60,0)) and wear().uses==1,"no arrows consume no wear")
	check(s.magic.equip_weapon("ali","stone_axe"),"equip axe")
	wear().uses=14
	var tree: Node2D=s.harvesting.trees["deadwood_01"]
	s.world.active_resident.position=tree.position+Vector2(0,18)
	check(s.harvesting.chop(tree.resource_id,s.world.active_resident) and wear().durability==39 and wear().uses==0,"chopping consumes fifteenth axe use")
	s.harvesting.cooldown=0
	var original: String=s.inventory.path
	var blocked:=path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	s.inventory.path=blocked
	check(not s.harvesting.chop(tree.resource_id,s.world.active_resident),"failed chop save rejected")
	s.inventory.path=original
	check(wear().durability==39 and wear().uses==0 and tree.hits==1,"failed save restores wear and tree progress")
	check(s.magic.equip_weapon("ali","pickaxe"),"equip mining tool")
	wear().uses=14
	var ore: Node2D=s.mining.surface["surface:1"]
	s.world.active_resident.position=ore.position+Vector2(0,18)
	await frames()
	check(s.mining.strike(s.world.active_resident,ore) and wear().durability==39 and wear().uses==0,"mining consumes fifteenth pickaxe use")
	s.mining.cooldown=0
	s.inventory.path=blocked
	check(not s.mining.strike(s.world.active_resident,ore),"failed mining save rejected")
	s.inventory.path=original
	check(wear().durability==39 and wear().uses==0 and s.mining.progress[ore.resource_id]==1,"failed mining restores reward progress and wear")
	wear().durability=0
	check(not s.mining.strike(s.world.active_resident,ore) and ore.hits==1,"broken pickaxe cannot mine")
	check(s.magic.equip_weapon("ali","bow"),"equip bow to test final use")
	s.inventory.exchange("ali",{}, {"arrow":2})
	wear().durability=1
	wear().uses=14
	s.combat.cooldown=0
	check(s.combat.fire(s.world.active_resident.position+Vector2(60,0)) and wear().durability==0,"last use still performs attack")
	s.combat.cooldown=0
	check(not s.combat.fire(s.world.active_resident.position+Vector2(60,0)),"broken bow cannot consume remaining arrow")
	check(s.magic.equip_weapon("ali","") and bag_weapon("bow").durability==0,"broken weapon remains recoverable in bag")
	check(s.magic.equip_weapon("ali","bow") and wear().durability==0,"re-equipping cannot repair broken weapon")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("DURABILITY_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
