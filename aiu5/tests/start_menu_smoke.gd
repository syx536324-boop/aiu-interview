# Exercises real menu clicks, legacy migration, independent slots, resume, pause and altar display persistence.
extends SceneTree

const Library := preload("res://features/save_slots/library.gd")
var menu: Node
var failures: Array[String] = []
var folder := ""

func _initialize() -> void:
	folder = "res://.runtime/menu-smoke-" + str(Time.get_ticks_usec())
	OS.set_environment("AIU5_SAVES_DIR", folder + "/slots")
	OS.set_environment("AIU5_LEGACY_PATH", folder + "/legacy.json")
	OS.set_environment("AIU5_LEGACY_PROFILE_PATH", folder + "/legacy-names.cfg")
	OS.set_environment("AIU5_STATE_PATH", folder + "/legacy.json")
	OS.set_environment("AIU5_PROFILE_PATH", folder + "/legacy-names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE", "expanded")
	create_timer(70, true).timeout.connect(func() -> void: push_error("START_MENU_TIMEOUT"); quit(2))
	call_deferred("run")

func frames(count := 3) -> void:
	for i in range(count): await process_frame

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("CHECK FAILED: " + label)

func button(text: String) -> Button:
	for node in menu.view.root.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func click(control: Control) -> void:
	if not is_instance_valid(control):
		push_error("EXPECTED_MENU_CONTROL_MISSING")
		quit(1)
		return
	await frames(2)
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func freeze() -> void:
	menu.game.get_node("Simulation").flush()
	menu.game.get_node("Simulation").set_process(false)
	for actor in menu.game.get_node("World").residents: actor.set_physics_process(false)

func make_new(title: String) -> void:
	await click(button("创建新存档"))
	menu.view.input.text = title
	await click(menu.view.create_button)
	await frames()
	freeze()

func run() -> void:
	# Build a representative old expanded settlement, then import a copy without modifying it.
	var legacy: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(legacy)
	legacy.get_node("Interiors").enter(legacy.get_node("World").active_resident, legacy.get_node("World").home_data("house"))
	legacy.get_node("World").active_resident.position = Vector2(95, 109)
	legacy.get_node("Vitals").ensure("ali").hunger = 6
	check(legacy.get_node("Persistence").save_now(), "legacy fixture saved")
	legacy.queue_free()
	await frames()
	# Model genuine pre-generator snapshots, including the altar, without rewriting game rules.
	for suffix in ["", ".altar"]:
		var path: String = folder + "/legacy.json" + suffix
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		data.session.erase("resource_world")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
	var legacy_bytes := FileAccess.get_file_as_bytes(folder + "/legacy.json")
	menu = load("res://scenes/start.tscn").instantiate()
	root.add_child(menu)
	await frames()
	check(menu.game == null and not paused and menu.view.screen == "home", "title loads without creating a live simulation")
	check(menu.library.slots().size() == 1 and menu.library.resolve("legacy").valid, "old save imported into one selectable slot")
	var old_metadata: Dictionary = menu.library._read(ProjectSettings.globalize_path(folder + "/slots/legacy/slot.json"))
	old_metadata.erase("seed")
	menu.library._write(ProjectSettings.globalize_path(folder + "/slots/legacy/slot.json"), old_metadata)
	var migrated_seed: int = menu.library.resolve("legacy").seed
	check(migrated_seed > 0 and menu.library.resolve("legacy").seed == migrated_seed, "pre-generator slot receives and durably keeps one random seed")
	check(FileAccess.get_file_as_bytes(folder + "/legacy.json") == legacy_bytes, "legacy source remains unchanged")
	await click(menu.view.continue_button)
	check(menu.view.screen == "slots" and menu.view.selected_id == "legacy", "continue opens save picker")
	await click(menu.view.load_button)
	freeze()
	check(menu.game.get_node("World").houses.size() == 14 and menu.game.get_node("World").residents.size() == 16, "legacy settlement retains its buildings and villagers")
	check(menu.game.get_node("World").active_resident.room_id == "house" and menu.game.get_node("World").active_resident.position == Vector2(95, 109), "continue restores the previous room and exact local position")
	menu.game.get_node("Simulation").set_process(true)
	await key(KEY_ESCAPE)
	check(paused and menu.view.screen == "pause", "Escape opens a paused in-game menu")
	var before := JSON.stringify(menu.game.get_node("Persistence").capture_session())
	await create_timer(0.7, true).timeout
	check(JSON.stringify(menu.game.get_node("Persistence").capture_session()) == before, "pause menu freezes all gameplay state")
	await click(button("保存并返回开始界面"))
	check(menu.game == null and not paused and menu.view.screen == "home", "save and return unloads simulation and returns to title")
	await make_new("沙丘甲")
	var first: Dictionary = menu.active_slot.duplicate()
	var world: Node2D = menu.game.get_node("World")
	check(int(first.seed) > 0 and world.resource_seed == int(first.seed), "new slot stores its world seed")
	check(menu.library._read(str(first.path).get_base_dir() + "/slot.json").seed == first.seed, "seed is durable in slot metadata")
	check(world.houses.size() == 9 and world.residents.size() == 6 and world.controllable.size() == 3, "new settlement has kitchen, two homes and three controllable founders")
	check(world.home_data("kitchen").size() > 0 and world.home_data("chief_house").is_empty() and world.altar != null, "new map includes requested buildings only")
	var inventory: Node = menu.game.get_node("Inventory")
	inventory.exchange("ali", {}, {"book": 1}) # Prepared camera gift for display persistence.
	world.active_resident.position = Vector2(548, 244)
	await frames(2)
	await key(KEY_E)
	check(inventory.opened and inventory.container_id == "altar:display" and inventory.slots_for("storage").size() == 21, "E opens altar display with 21 slots")
	var book_index := -1
	for i in range(21):
		if inventory.ensure_bag("ali")[i].get("item", "") == "book": book_index = i
	inventory.slot_clicked("bag", book_index, true)
	check(inventory.ensure_container("altar:display")[0].get("item", "") == "book" and menu.game.get_node("AltarDisplay").icons[0].item == "book", "display transfer updates visible world icon")
	await key(KEY_ESCAPE)
	menu.game.get_node("Interiors").enter(world.active_resident, world.home_data("round_house"))
	world.active_resident.position = Vector2(96, 103)
	menu.game.get_node("Session")._sync_view()
	menu.game.get_node("Vitals").ensure("ali").thirst = 7
	menu.game.get_node("Vitals").ensure("ali").need_time = 123.25
	check(menu.game.get_node("Persistence").save_checkpoint(), "slot-specific altar checkpoint saved")
	menu.pause_game()
	await click(button("保存并返回开始界面"))
	var first_bytes := FileAccess.get_file_as_bytes(first.path)
	await make_new("沙丘乙")
	var second: Dictionary = menu.active_slot.duplicate()
	check(int(second.seed) != int(first.seed), "new slots receive independent random world seeds")
	check(second.id != first.id and second.path != first.path, "new slots use independent files")
	check(menu.game.get_node("Inventory").container_empty("altar:display"), "new save has no display contents from another slot")
	menu.pause_game()
	await click(button("保存并返回开始界面"))
	check(FileAccess.get_file_as_bytes(first.path) == first_bytes, "saving another slot does not overwrite the first")
	await click(menu.view.continue_button)
	menu.view._select(first.id)
	await click(menu.view.load_button)
	freeze()
	world = menu.game.get_node("World")
	check(world.settlement == "starter" and world.houses.size() == 9 and world.active_resident.room_id == "round_house" and world.active_resident.position == Vector2(96, 103), "selected new save restores layout and room position")
	check(menu.game.get_node("Vitals").ensure("ali").thirst == 7 and absf(menu.game.get_node("Vitals").ensure("ali").need_time - 123.25) < 0.3, "selected new save retains status and partial clock")
	check(menu.game.get_node("Inventory").ensure_container("altar:display")[0].get("item", "") == "book", "display contents persist in selected save")
	menu.game.get_node("Inventory").ensure_container("altar:display")[0] = {}
	menu.game.get_node("Persistence").restore_checkpoint()
	check(menu.game.get_node("Inventory").ensure_container("altar:display")[0].get("item", "") == "book", "altar rollback restores its display contents")
	await key(KEY_M)
	# Inside, M is intentionally refused; leave and test overview through the new launcher root.
	menu.game.get_node("Interiors").leave(world.active_resident, world.objects, Vector2(322, 224))
	menu.game.get_node("Session")._sync_view()
	menu.game.get_node("Simulation").set_process(true)
	await key(KEY_M)
	check(paused and menu.game.get_node("Session").overview, "full map still pauses under the always-responsive launcher")
	before = JSON.stringify(menu.game.get_node("Persistence").capture_session())
	await create_timer(0.7, true).timeout
	check(JSON.stringify(menu.game.get_node("Persistence").capture_session()) == before, "launcher does not cause paused simulation to keep running")
	await key(KEY_ESCAPE)
	check(not paused and not menu.game.get_node("Session").overview and not menu.view.visible, "first Escape closes full map without opening pause menu")
	menu.pause_game()
	await menu.return_home()
	# Invalid names and corrupted save payloads must not launch or overwrite an existing slot.
	check(not menu.library.create_slot("  ").ok, "empty save names rejected")
	var corrupt: Dictionary = menu.library.create_slot("损坏样本").slot
	var file := FileAccess.open(corrupt.path, FileAccess.WRITE)
	file.store_string('{"version":2,"session":[],"bags":{}}')
	file.close()
	check(not menu.library.resolve(corrupt.id).valid, "malformed snapshot is disabled instead of crashing picker")
	menu.continue_game(corrupt.id)
	check(menu.game == null, "invalid save cannot start a new simulation over its data")
	check(FileAccess.get_file_as_bytes(folder + "/legacy.json") == legacy_bytes, "all menu actions preserve the original legacy source")
	menu.queue_free()
	await frames()
	if failures.is_empty(): print("START_MENU_SMOKE_OK")
	else: print("START_MENU_SMOKE_FAILED ", failures)
	quit(0 if failures.is_empty() else 1)
