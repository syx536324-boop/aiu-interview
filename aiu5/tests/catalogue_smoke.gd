# Verifies class mappings, filtered slot identity, new items and additive fauna migration.
extends SceneTree
const Categories := preload("res://features/inventory/categories.gd")
var failures: Array[String] = []
var game: Node
var s: Node
func _initialize() -> void:
	var path := "res://.runtime/catalogue-"+str(Time.get_ticks_usec())+"/state.json"
	OS.set_environment("AIU5_STATE_PATH",path)
	OS.set_environment("AIU5_PROFILE_PATH",path+".names")
	create_timer(45,true).timeout.connect(func() -> void: quit(2))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	s=game.get_node("Session")
	s.simulation.set_process(false)
	s.simulation.reset()
	s.persistence.set_process(false)
	for a in s.world.residents: a.set_physics_process(false)
	for a in s.livestock.animals: a.set_physics_process(false)
	for id: String in s.inventory.Catalog.ITEMS: check(Categories.group(id)!="","classified item "+id)
	var mapping: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://training/gifts/catalog.json"))
	check(mapping.classes.size()==18 and mapping.training_images==0 and mapping.annotation_files==0,"honest eighteen-class registry")
	for i in range(18):
		var r: Dictionary=mapping.classes[i]
		check(r.class_id==i,"contiguous class index")
		check(Categories.label(str(r.game_id))==r.category,"game classification matches "+str(r.class_name))
		if r.game_kind=="inventory": check(s.inventory.Catalog.ITEMS.has(str(r.game_id)),"valid game mapping")
		elif r.game_kind=="furniture": check(s.editor.Catalog.TYPES.has(str(r.game_id)),"valid furniture mapping")
		else: check(s.livestock.find_animal(str(r.game_id)+":1")!=null,"valid animal mapping")
	var bag: Array=s.inventory.ensure_bag("ali")
	for i in range(21): bag[i]={}
	bag[7]={"item":"apple","count":3}
	bag[12]={"item":"book","count":1}
	bag[18]={"item":"carrot","count":2}
	s.toggle_inventory()
	var ui: Node=game.get_node("Belongings")
	ui.category_filter.select(ui.filter_ids.find("food"))
	ui.category_filter.item_selected.emit(ui.filter_ids.find("food"))
	check(ui.bag_buttons[0].get_meta("slot_index")==7 and ui.bag_buttons[1].get_meta("slot_index")==18,"filter retains underlying slots")
	ui.bag_buttons[0].pressed.emit()
	check(s.inventory.selection.index==7,"filtered click selects actual slot")
	s.vitals.ensure("ali").hunger=3
	s.use_selected()
	check(s.vitals.ensure("ali").hunger==5 and s.inventory.ensure_bag("ali")[7].count==2,"apple consumes once and restores two hunger")
	s.inventory.slot_clicked("bag",18)
	s.use_selected()
	check(s.vitals.ensure("ali").hunger==7 and s.inventory.ensure_bag("ali")[18].count==1,"carrot works through session")
	check(s.inventory.exchange("ali",{}, {"knife":1,"bowl":1,"scissors":1}),"new ordinary items carried")
	check(s.magic.equip_weapon("ali","knife") and s.magic.Catalog.Gear.damage("knife")==1,"knife equips with initial damage one")
	s.close_inventory()
	var herd: Node=s.livestock
	var legacy: Dictionary=herd.export_state()
	legacy.erase("fauna_version")
	legacy.animals=legacy.animals.filter(func(r: Dictionary) -> bool: return r.species in ["pig","cow"])
	legacy.next_ids.erase("dog")
	legacy.next_ids.erase("bird")
	herd.restore(legacy)
	herd.restore(legacy)
	check(herd.animals.size()==7 and s.world.pigs.size()==3 and s.world.cows.size()==2,"old save gets dog and bird exactly once without changing herd")
	var original: Dictionary=herd.export_state()
	herd.find_animal("dog:1").position+=Vector2(3,0)
	herd.restore(original)
	check(JSON.stringify(herd.export_state())==JSON.stringify(original),"fauna exact save reload")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("CATALOGUE_SMOKE_OK")
	quit(0 if failures.is_empty() else 1)
