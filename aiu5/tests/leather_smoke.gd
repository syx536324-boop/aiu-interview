# Verifies actual melee/arrow cattle kills, single leather drops, rollback and herd persistence.
extends SceneTree
var failures: Array[String]=[]
var game: Node
var s: Node
var path: String
func _initialize() -> void:
	path="res://.runtime/leather-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	create_timer(60,true).timeout.connect(func() -> void: quit(2))
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
	for a in s.world.residents: a.set_physics_process(false)
	for animal in s.livestock.animals: animal.set_physics_process(false)
	await frames()
func cow(id: String="cow:1") -> CharacterBody2D:
	return s.livestock.find_animal(id)
func count(item: String) -> int:
	var result:=0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item","")==item: result+=int(slot.count)
	return result
func aim(id: String="cow:1") -> void:
	s.world.active_resident.position=cow(id).position+Vector2(0,18)
	s.world.streamer.focus(true)
	await frames(5)
	await physics_frame
func swing() -> bool:
	s.combat.cooldown=0
	return s.combat.fire(cow().position)
func run() -> void:
	await load_game()
	s.inventory.bags.ali=s.inventory._sanitize_slots([{"item":"iron_sword","count":1},{"item":"bow","count":1},{"item":"arrow","count":1}])
	check(s.magic.equip_weapon("ali","iron_sword",0),"equip hunting sword")
	await aim()
	check(swing() and cow().hp==5 and count("leather")==0 and s.magic.ensure("ali").weapon_wear.uses==1,"first real sword hit damages cow and uses weapon once")
	check(s.persistence.save_checkpoint(false),"checkpoint wounded cow")
	var bag: Array=s.inventory.bags.ali.duplicate(true)
	for i in range(21): s.inventory.bags.ali[i]={"item":"book","count":10}
	check(not swing() and cow().hp==5 and s.magic.ensure("ali").weapon_wear.uses==1,"full bag cancels lethal hit without losing drop or wear")
	s.inventory.bags.ali=bag
	var original: String=s.inventory.path
	var blocked:=path.get_base_dir()+"/blocked"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked))
	s.inventory.path=blocked
	check(not swing(),"failed lethal save rejected")
	s.inventory.path=original
	await frames()
	check(cow()!=null and cow().hp==5 and s.world.cows.size()==2 and count("leather")==0 and s.magic.ensure("ali").weapon_wear.uses==1,"rollback restores herd hp drop and durability together")
	cow().set_physics_process(false)
	await aim()
	var defeated: CharacterBody2D=cow()
	check(swing() and cow()==null and s.world.cows.size()==1 and count("leather")==1 and s.magic.ensure("ali").weapon_wear.uses==2,"second real hit kills cow and gives one leather")
	check(not s.combat.hit_cow(defeated,10) and count("leather")==1,"removed cow cannot drop twice")
	check(not s.livestock.feed_animal(s.world.active_resident,"cow:1"),"killed cow cannot feed or breed")
	s.livestock.advance(600)
	check(cow()==null and s.world.cows.size()==1,"elapsed time does not respawn killed cow")
	check(s.persistence.save_now(),"save killed herd")
	game.queue_free()
	await frames()
	await load_game()
	check(cow()==null and s.world.cows.size()==1 and count("leather")==1,"reload preserves kill and exactly one drop")
	check(s.persistence.restore_checkpoint(),"restore pre-kill checkpoint")
	check(cow()!=null and cow().hp==5 and s.world.cows.size()==2 and count("leather")==0,"checkpoint restores historical herd and leather")
	for animal in s.livestock.animals: animal.set_physics_process(false)
	check(s.magic.equip_weapon("ali","bow"),"equip cattle hunting bow")
	await aim("cow:2")
	s.combat.cooldown=0
	check(s.combat.fire(cow("cow:2").position+Vector2(0,-3)),"fire actual arrow at cow")
	s.select_resident(1)
	await create_timer(0.2,true).timeout
	check(cow("cow:2")==null and count("leather")==1 and count("arrow")==0 and s.magic.ensure("ali").weapon_wear.uses==1,"arrow kills cow, gives leather and spends one arrow/use")
	check(not s.inventory.has_item("heya","leather"),"switching role while arrow flies preserves original shooter loot")
	check(s.world.pigs.size()==3,"hunting cows preserves pig herd")
	game.queue_free()
	await frames()
	if failures.is_empty(): print("LEATHER_SMOKE_OK"); quit(0)
	else: print(failures); quit(1)
