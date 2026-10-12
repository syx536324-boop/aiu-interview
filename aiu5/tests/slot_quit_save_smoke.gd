# Verifies independent menu-selected slots survive paused window close and another process resumes them.
extends SceneTree

const POINTER := "res://.runtime/slot-quit-pointer.json"
var menu: Node

func _initialize() -> void:
	OS.set_environment("AIU5_SAVES_DIR", "res://.runtime/slot-quit")
	OS.set_environment("AIU5_LEGACY_PATH", "res://.runtime/slot-quit/no-legacy.json")
	OS.set_environment("AIU5_LEGACY_PROFILE_PATH", "res://.runtime/slot-quit/no-names.cfg")
	create_timer(30, true).timeout.connect(func() -> void: push_error("SLOT_QUIT_TIMEOUT"); quit(2))
	call_deferred("run")

func run() -> void:
	menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	var verify := "verify" in OS.get_cmdline_user_args()
	if verify:
		var pointer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POINTER))
		menu.continue_game(pointer.id)
	else: menu.create_game("退出续存验证")
	for i in range(4): await process_frame
	var game: Node = menu.game
	game.get_node("Simulation").set_process(false)
	var world: Node2D = game.get_node("World")
	var inventory: Node = game.get_node("Inventory")
	var farm: Node = game.get_node("Homestead")
	var herd: Node = game.get_node("Livestock")
	for actor in world.residents: actor.set_physics_process(false)
	if verify:
		var good: bool = world.settlement == "starter" and world.houses.size() == 10 and world.controllable.size() == 3
		good = good and world.active_resident.room_id == "kitchen" and world.active_resident.position == Vector2(95, 109)
		good = good and world.founder_names() == {"male": "砂砾", "female": "青芽"}
		good = good and game.get_node("Vitals").ensure("ali").hunger == 6 and game.get_node("Vitals").ensure("ali").need_time == 123.25
		var revived: Dictionary = game.get_node("Vitals").ensure("heya")
		good = good and game.get_node("Vitals").ensure("ali").mana == 6 and game.get_node("Vitals").ensure("chief_priest").mana == 4
		good = good and revived.life == 10 and revived.hunger == 10 and revived.thirst == 10 and revived.health == 10 and revived.mana == 10 and not revived.ill and revived.need_time == 73.5 and revived.active_time == 0
		good = good and inventory.ensure_container("altar:display")[1].get("count", 0) == 1 and not world.controllable[1].dead and world.controllable[1].room_id == ""
		good = good and farm.plots[0].crop == "rice" and farm.plots[0].growth == 123.75 and farm.plots[0].age == 67.5
		good = good and inventory.ensure_container("altar:display")[0].get("item", "") == "book" and game.get_node("AltarDisplay").icons[0].item == "book"
		good = good and herd.find_animal("cow:3").growth == 143.25 and game.get_node("Mining").progress.get("surface:1") == 2
		good = good and not paused and not game.get_node("Session").menu_paused
		var magic: Dictionary = game.get_node("Magic").ensure("ali")
		# 237 awarded points plus two first-item discoveries (leather_armor, leather_helmet, 25 each) = 287, so lv.3 with 87 xp.
		good = good and magic.element == "earth" and magic.level == 3 and magic.xp == 87 and magic.skill_points == 0 and magic.unlocked == ["trunk_1"] and magic.equipment.head == "leather_helmet" and not magic.gear_claimed
		good = good and not inventory.has_item("ali", "leather_helmet") and inventory.has_item("ali", "leather_armor")
		good = good and game.get_node("Combat").enemies["tribe:1"].hp==0 and game.get_node("Production").smelting.remaining==12.5
		good = good and game.get_node("Construction").records["built:0"].hp==91 and world.home_data("built:0").name=="中级石屋"
		if good: print("SLOT_QUIT_SAVE_RELOAD_OK")
		else: push_error("SLOT_QUIT_SAVE_RELOAD_FAILED")
		quit(0 if good else 1)
	else:
		# Commit a real sacrifice before the paused exit; another process must keep it once.
		var session: Node = game.get_node("Session")
		world.active_resident.position = Vector2(548, 244)
		session._sync_view()
		var revived: Dictionary = game.get_node("Vitals").ensure("heya")
		revived.life = 0
		revived.ill = true
		revived.mana = 0
		game.get_node("Vitals")._sync_actors()
		inventory.ensure_container("altar:display")[1] = {"item": "bread", "count": 2}
		session.interact()
		inventory.selection = {"side": "storage", "index": 1}
		var ritual: Dictionary = session.offerings.sacrifice("heya")
		if not ritual.ok:
			push_error("SLOT_QUIT_RESURRECTION_FAILED")
			quit(1)
			return
		game.get_node("Vitals").ensure("heya").need_time = 73.5
		game.get_node("Vitals").ensure("ali").mana = 6
		game.get_node("Vitals").ensure("chief_priest").mana = 4
		inventory.close()
		world.active_resident.position = Vector2(548, 332)
		var magic: Node = game.get_node("Magic")
		inventory.exchange("ali", {}, {"leather_armor":1, "leather_helmet":1}) # Prepared crafted equipment.
		if not magic.awaken("ali", "earth") or not magic.award_points("ali", 237) or not magic.unlock("ali", "trunk_1") or not magic.equip("ali", "head", "leather_helmet"):
			push_error("SLOT_QUIT_MAGIC_SETUP_FAILED")
			quit(1)
			return
		game.get_node("Session").rename_founders("砂砾", "青芽")
		game.get_node("Interiors").enter(world.active_resident, world.home_data("kitchen"))
		world.active_resident.position = Vector2(95, 109)
		game.get_node("Session")._sync_view()
		menu.pause_game()
		game.get_node("Vitals").ensure("ali").hunger = 6
		game.get_node("Vitals").ensure("ali").need_time = 123.25
		farm.plots[0].crop = "rice"
		farm.plots[0].dry = false
		farm.plots[0].growth = 123.75
		farm.plots[0].age = 67.5
		farm.refresh()
		inventory.exchange("ali", {"book": 1}, {})
		inventory.ensure_container("altar:display")[0] = {"item": "book", "count": 1}
		inventory.changed.emit()
		herd._spawn("cow:3", "cow", "female", 143.25, Vector2(104, 460))
		herd.next_ids.cow = 4
		game.get_node("Mining").restore({"progress": {"surface:1": 2}})
		game.get_node("Construction").records["built:0"]={"id":"built:0","kind":"stone_house","at":[850,900],"hp":91.0,"max_hp":100.0,"defense":10}
		game.get_node("Construction").next_id=1
		game.get_node("Construction")._attach("built:0")
		game.get_node("Combat").enemies["tribe:1"].hp=0
		game.get_node("Combat").enemies["tribe:1"].refresh()
		game.get_node("Production").smelting.remaining=12.5
		var file := FileAccess.open(POINTER, FileAccess.WRITE)
		file.store_string(JSON.stringify({"id": menu.active_slot.id}))
		file.close()
		menu.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		print("SLOT_QUIT_NOTIFICATION_SAVED_OK")
