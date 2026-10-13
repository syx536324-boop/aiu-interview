# Verifies actual leather equipment transfers, injury reduction, shield stacking, rollback and saved protection.
extends Node
const Armor := preload("res://features/magic/equipment_catalog.gd")
const Origin := preload("res://features/gifts/provenance.gd")
var game: Node
var s: Node
var directory := ""
var failures: Array[String] = []
var checks := 0
var capture := false
func _enter_tree() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	directory=OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(directory!="")
	OS.set_environment("AIU5_STATE_PATH",directory+"/state.json")
	OS.set_environment("AIU5_PROFILE_PATH",directory+"/names.cfg")
	capture=OS.get_environment("AIU5_CAPTURE")=="true"
	get_tree().create_timer(60,true).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame
func load_game() -> void:
	game=load("res://scenes/main.tscn").instantiate(); get_tree().root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false); s.simulation.reset(); s.persistence.set_process(false)
	for actor in s.world.residents: actor.set_physics_process(false)
	for enemy in s.combat.enemies.values(): enemy.set_physics_process(false)
	await frames()
func screenshot(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")==OK,"screenshot "+name)
func run() -> void:
	await load_game()
	check(ProjectSettings.get_setting("application/config/version")=="0.7.8","maintenance version")
	var items := {"armor":"leather_armor","legs":"leather_leggings","head":"leather_helmet","feet":"leather_boots"}
	check(s.magic.defense("ali")==0 and is_equal_approx(s.vitals.damage("ali",10),10),"no equipment no reduction")
	var count := 0
	for slot: String in items:
		var item: String=items[slot]
		check(s.inventory.exchange("ali",{}, {item:1}),"new gear enters bag "+item)
		check(s.magic.defense("ali")==count,"bag alone adds no protection "+item)
		check(s.magic.equip("ali",slot,item),"real equip "+item)
		count+=1
		check(s.magic.defense("ali")==count,"one defense per worn leather piece "+item)
		check(is_equal_approx(s.vitals.damage("ali",10),10*(1.0-count*0.05)),"additive five percent per piece "+item)
		check(Armor.defense(item)==1 and "免伤5%" in s.inventory.Catalog.ITEMS[item].description,"catalog describes defense and reduction "+item)
	check(s.magic.protection_snapshot("ali").armor_reduction_percent==20,"four pieces exactly twenty percent")
	s.vitals.ensure("ali").life=10
	s.vitals.hurt("ali",1)
	check(is_equal_approx(s.vitals.ensure("ali").life,9.2),"actual one damage injury becomes point eight")
	check(s.magic.defense("heya")==0 and is_equal_approx(s.vitals.damage("heya",10),10),"armor belongs to its character")
	s.magic.ensure("ali").element="water"; s.magic.ensure("ali").level=20
	s.magic.ensure("ali").unlocked=["trunk_1","trunk_2","trunk_3","trunk_4"]
	s.magic.ensure("ali").skill_points=55
	s.vitals.ensure("ali").mana=10
	check(s.magic.skills.cast(4,s.world.active_resident.position),"real water shield cast")
	check(is_equal_approx(s.vitals.damage("ali",10),5.6),"four leather plus shield leaves fifty-six percent injury")
	check(s.magic.protection_snapshot("ali").reduction_percent==44,"combined snapshot exactly forty-four percent")
	s.vitals.ensure("ali").life=10; s.vitals.hurt("ali",10)
	check(is_equal_approx(s.vitals.ensure("ali").life,4.4),"actual shielded injury preserves four point four life")
	s.show_attributes("ali"); s.refresh_interface(); await frames()
	var ui: CanvasLayer=game.get_node("Attributes")
	check("防御 4" in ui.protection_label.text and "装备免伤 20%" in ui.protection_label.text and "总免伤 44%" in ui.protection_label.text,"attributes show armor and shield protection")
	await screenshot("full-leather-and-shield")
	s.close_attributes()
	s.magic.skills.advance(30)
	check(is_equal_approx(s.vitals.damage("ali",10),8),"shield expiration returns armor-only reduction")
	check(s.magic.equip("ali","head",""),"real unequip updates protection")
	check(s.magic.defense("ali")==3 and is_equal_approx(s.vitals.damage("ali",10),8.5),"three pieces fifteen percent")
	var original: String=s.inventory.path
	var blocked := directory+"/blocked"
	DirAccess.make_dir_recursive_absolute(blocked)
	s.inventory.path=blocked
	check(not s.magic.equip("ali","feet",""),"failed unequip save rejected")
	s.inventory.path=original
	check(s.magic.defense("ali")==3 and s.magic.ensure("ali").equipment.feet=="leather_boots","failed save preserves gear-derived defense")
	check(s.inventory.exchange("ali",{}, {"iron_helmet":1}),"iron gear available")
	check(s.magic.equip("ali","head","iron_helmet"),"iron can still equip")
	check(s.magic.defense("ali")==3 and Armor.defense("iron_helmet")==0,"undefined iron defense not invented")
	check(s.magic.equip("ali","head",""),"remove iron before gift")
	var record := {"item":"leather_helmet","count":1}
	record.merge(Origin.gifted("armor-probe","earth"))
	check(s.inventory.insert_record("ali",record),"gifted leather record enters bag")
	var index := -1
	for i in range(21):
		if s.inventory.ensure_bag("ali")[i].get("gift_event_id","")=="armor-probe": index=i; break
	check(s.magic.equip("ali","head","leather_helmet",index),"real gifted leather equips")
	check(s.magic.defense("ali")==4 and s.magic.ensure("ali").equipment_records.head.magic_attribute=="earth","gift adds same protection and retains magic origin")
	s.show_attributes("ali"); s.refresh_interface(); await frames()
	check("装备免伤 20%" in ui.protection_label.text,"full set restored in UI")
	await screenshot("full-leather-protection")
	s.close_attributes()
	check(s.persistence.save_now(),"gear and fractional life saved")
	var saved_life: float=s.vitals.ensure("ali").life
	game.queue_free(); await frames()
	await load_game()
	check(s.magic.defense("ali")==4 and is_equal_approx(s.vitals.damage("ali",10),8),"real restart derives armor protection without double-counting")
	check(is_equal_approx(s.vitals.ensure("ali").life,saved_life),"fractional life survives restart")
	check(s.magic.ensure("ali").equipment_records.head.magic_attribute=="earth","gift attribute survives restart")
	var legacy: Dictionary=s.magic.Catalog.restore_state({"equipment":{"armor":"armor","head":"hood","legs":"leggings","feet":"boots"}})
	check(Armor.total_defense(legacy.equipment)==4,"legacy leather gear automatically gains defined protection")
	check(Armor.total_defense({"weapon":"leather_armor","armor":"leather_boots"})==0,"wrong slots cannot grant defense")
	check(s.vitals.damage("ali",0)==0,"zero injury remains zero")
	game.queue_free(); await frames()
	if failures.is_empty(): print("LEATHER_ARMOR_OK checks=",checks); get_tree().quit(0)
	else: print(failures); get_tree().quit(1)
