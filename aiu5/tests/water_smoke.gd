# Verifies fractional bucket drinking, reusable cups, full-bucket irrigation and saved water states.
extends SceneTree

const PATH := "res://.runtime/test-water.json"
var failures: Array[String] = []
var game: Node
var world: Node2D
var session: Node
var inventory: Node
var vitals: Node
var farm: Node
var persistence: Node
var ui: CanvasLayer

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-water-names.cfg")
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(35).timeout.connect(func() -> void: push_error("WATER_TIMEOUT"); quit(2))
	call_deferred("run_checks")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("CHECK FAILED: " + label)

func frames(count := 2) -> void:
	for i in range(count): await physics_frame
	await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func count_item(id: String, item: String) -> int:
	var result := 0
	for slot: Dictionary in inventory.ensure_bag(id):
		if slot.get("item", "") == item: result += int(slot.count)
	return result

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	inventory = game.get_node("Inventory")
	vitals = game.get_node("Vitals")
	farm = game.get_node("Homestead")
	persistence = game.get_node("Persistence")
	ui = game.get_node("Belongings")
	vitals.set_process(false)
	farm.set_process(false)
	persistence.set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for pig in world.pigs: pig.set_physics_process(false)
	await frames()

func run_checks() -> void:
	await load_game()
	for actor in world.controllable:
		check(count_item(actor.resident_id, "wooden_cup") == 0, "new characters have no free wooden cup")
		inventory.grant_supplies(actor.resident_id)
		check(count_item(actor.resident_id, "wooden_cup") == 0, "supply migration does not grant crafted containers")
	inventory.exchange("ali", {}, {"bucket": 1, "wooden_cup": 1}) # Prepared crafted vessels.
	var actor: CharacterBody2D = world.active_resident
	var s: Dictionary = vitals.ensure("ali")
	actor.position = Vector2(334, 207)
	await key(KEY_E)
	check(inventory.has_item("ali", "water_bucket") and inventory.has_item("ali", "water_cup"), "actual well E fills both the bucket and wooden cup")
	var before: Array = inventory.ensure_bag("ali").duplicate(true)
	check(not vitals.use_food("ali", "water_bucket") and not vitals.use_food("ali", "water_cup") and before == inventory.ensure_bag("ali"), "full thirst consumes neither bucket water nor cup water")
	s.thirst = 0
	await key(KEY_B)
	var index := -1
	for i in range(21):
		if inventory.ensure_bag("ali")[i].get("item", "") == "water_bucket": index = i
	check(index >= 0, "full bucket is selectable in the bag")
	if index >= 0:
		await click(ui.bag_buttons[index])
		check(ui.use_button.text.contains("1/4"), "bag action explains quarter-bucket consumption")
		await click(ui.use_button)
	check(s.thirst == 4 and inventory.has_item("ali", "water_bucket_3") and not inventory.has_item("ali", "water_bucket"), "actual bag use drinks one quarter and restores exactly four")
	check(session.snapshot().water_text.contains("桶3/4"), "HUD reports fractional water instead of an empty bucket")
	await key(KEY_B)
	for pair: Array in [["water_bucket_3", "water_bucket_2"], ["water_bucket_2", "water_bucket_1"], ["water_bucket_1", "bucket"]]:
		s.thirst = 1
		check(vitals.use_food("ali", pair[0]) and s.thirst == 5 and inventory.has_item("ali", pair[1]) and not inventory.has_item("ali", pair[0]), "each remaining quarter restores four and keeps the rest: " + str(pair[0]))
	check(not vitals.use_food("ali", "bucket") and count_item("ali", "bucket") == 1, "empty bucket cannot yield a fifth drink")
	s.thirst = 3
	check(vitals.use_food("ali", "water_cup") and s.thirst == 7 and inventory.has_item("ali", "wooden_cup") and not inventory.has_item("ali", "water_cup"), "one cup is drunk completely, restores four and keeps the wooden cup")
	check(not vitals.use_food("ali", "wooden_cup"), "empty wooden cup cannot be drunk")
	check(vitals.ensure("heya").thirst == 10, "drinking changes only the current character's thirst")
	actor.position = Vector2(157, 205)
	await key(KEY_E)
	check(inventory.has_item("ali", "water_cup") and inventory.has_item("ali", "water_bucket"), "actual lake E refills reusable vessels")
	s.thirst = 9
	check(vitals.use_food("ali", "water_cup") and s.thirst == 10, "cup restoration clamps at the ten-point limit")
	# Every partial level and a full cup must reject irrigation without consuming anything.
	farm.plots = [{"x": 650.0, "y": 390.0, "w": 16.0, "h": 16.0, "age": 27.5, "dry": true, "crop": ""}]
	farm.refresh()
	actor.position = Vector2(658, 398)
	var normal_bag: Array = inventory.ensure_bag("ali").duplicate(true)
	for item: String in ["water_bucket_3", "water_bucket_2", "water_bucket_1", "water_cup", "bucket"]:
		inventory.bags.ali = inventory._sanitize_slots([{ "item": item, "count": 1 }])
		before = inventory.ensure_bag("ali").duplicate(true)
		check(not farm.water(actor) and farm.plots[0].dry and farm.plots[0].age == 27.5 and before == inventory.ensure_bag("ali"), "irrigation rejects a non-full bucket or a cup without loss: " + item)
	inventory.bags.ali = normal_bag
	check(farm.water(actor) and not farm.plots[0].dry and inventory.has_item("ali", "bucket"), "only a full bucket irrigates and returns one empty bucket")
	# At full capacity, replacing a vessel state still succeeds and retains every other item.
	for i in range(21): inventory.bags.ali[i] = {"item": "book", "count": 10}
	inventory.bags.ali[6] = {"item": "water_bucket", "count": 1}
	inventory.bags.ali[7] = {"item": "water_cup", "count": 1}
	s.thirst = 2
	check(vitals.use_food("ali", "water_bucket") and s.thirst == 6 and inventory.has_item("ali", "water_bucket_3"), "quarter drinking succeeds even in a full 21-slot bag")
	check(count_item("ali", "book") == 190 and inventory.ensure_bag("ali").filter(func(slot: Dictionary) -> bool: return not slot.is_empty()).size() == 21, "water conversion conserves other items and capacity")
	s.thirst = 1
	check(vitals.use_food("ali", "water_cup") and s.thirst == 5 and inventory.has_item("ali", "wooden_cup"), "cup also returns its empty container in a full bag")
	check(farm.fill_bucket(actor) and inventory.has_item("ali", "water_bucket") and inventory.has_item("ali", "water_cup") and count_item("ali", "book") == 190, "partial bucket and empty cup refill together without an extra free slot")
	check(not farm.fill_bucket(actor), "already-full vessels are left unchanged")
	s.thirst = 1
	vitals.use_food("ali", "water_bucket")
	s.thirst = 1
	vitals.use_food("ali", "water_bucket_3")
	check(persistence.save_checkpoint(false), "checkpoint saves half a bucket and a full cup")
	check(persistence.save_now(), "fractional bucket is saved to auto-save")
	game.queue_free()
	await frames()
	await load_game()
	actor = world.active_resident
	s = vitals.ensure("ali")
	check(count_item("ali", "water_bucket_2") == 1 and count_item("ali", "water_cup") == 1 and s.thirst == 5 and count_item("ali", "book") == 190, "fresh game restores exact fractional water, cup and thirst")
	# Storage transfers the complete vessel state; another character may drink its water.
	inventory.open_container("ali", actor.resident_name, "water-test-chest", "木杯柜")
	for i in range(21):
		if inventory.ensure_bag("ali")[i].get("item", "") == "water_bucket_2": inventory.slot_clicked("bag", i, true)
	check(inventory.ensure_container("water-test-chest")[0].get("item", "") == "water_bucket_2", "storage preserves the half-bucket state")
	session.select_resident(1)
	inventory.open_container("heya", world.controllable[1].resident_name, "water-test-chest", "木杯柜")
	inventory.slot_clicked("storage", 0, true)
	vitals.ensure("heya").thirst = 2
	check(vitals.use_food("heya", "water_bucket_2") and vitals.ensure("heya").thirst == 6 and inventory.has_item("heya", "water_bucket_1"), "another character drinks a stored half-bucket and retains a quarter")
	inventory.close()
	session.select_resident(0)
	s.thirst = 1
	vitals.use_food("ali", "water_cup")
	check(persistence.restore_checkpoint(), "altar checkpoint restores water states")
	check(inventory.has_item("ali", "water_bucket_2") and inventory.has_item("ali", "water_cup") and not inventory.has_item("heya", "water_bucket_1") and vitals.ensure("ali").thirst == 5, "altar rewinds water, storage transfers and thirst together")
	# Legacy bucket IDs remain valid, and old checkpoints do not receive free crafted cups.
	var legacy: Dictionary = inventory.export_data()
	legacy.version = 1
	legacy.bags.ali = [{"item": "water_bucket", "count": 1}]
	legacy.containers["legacy-water"] = [{"item": "bucket", "count": 1}]
	legacy.grants.ali.erase("wooden_cup")
	persistence.checkpoint = legacy
	check(persistence.restore_checkpoint() and inventory.has_item("ali", "water_bucket") and count_item("ali", "wooden_cup") == 0 and inventory.ensure_container("legacy-water")[0].item == "bucket", "legacy full/empty buckets and old altar supplies remain compatible")
	inventory.grant_supplies("ali")
	check(count_item("ali", "wooden_cup") == 0, "cup migration remains idempotent without freebies")
	game.queue_free()
	await frames()
	if failures.is_empty():
		print("WATER_SMOKE_OK: four quarter-bucket drinks, +4 thirst, reusable wooden cups, real B/use/E, full-bucket-only irrigation, full capacity conservation, shared storage, restart, altar and legacy saves")
		quit(0)
	else:
		print("WATER_SMOKE_FAILED: ", failures)
		quit(1)
