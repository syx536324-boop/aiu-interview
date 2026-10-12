# Exercises seed selection, all growth boundaries, drought, harvest and durable crop saves.
extends SceneTree

const PATH := "res://.runtime/test-crops.json"
var failures: Array[String] = []
var game: Node
var world: Node2D
var session: Node
var inventory: Node
var farm: Node
var persistence: Node
var ui: CanvasLayer

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-crops-names.cfg")
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(40).timeout.connect(func() -> void: push_error("CROPS_TIMEOUT"); quit(2))
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
	var count := 0
	for slot: Dictionary in inventory.ensure_bag(id):
		if slot.get("item", "") == item: count += int(slot.count)
	return count

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	inventory = game.get_node("Inventory")
	farm = game.get_node("Homestead")
	persistence = game.get_node("Persistence")
	ui = game.get_node("Belongings")
	farm.set_process(false)
	persistence.set_process(false)
	game.get_node("Vitals").set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for pig in world.pigs: pig.set_physics_process(false)
	await frames()

func run_checks() -> void:
	await load_game()
	for actor in world.controllable:
		check(count_item(actor.resident_id, "seeds") == 3 and count_item(actor.resident_id, "rice_seeds") == 3, "each character receives both seed types")
		inventory.grant_supplies(actor.resident_id)
		check(count_item(actor.resident_id, "rice_seeds") == 3, "rice supplies are not duplicated")
	inventory.exchange("ali", {}, {"bucket": 1}) # Prepared crafted container.
	var actor: CharacterBody2D = world.active_resident
	farm.plots = [
		{"x": 650.0, "y": 390.0, "w": 16.0, "h": 16.0, "dry": true, "age": 0.0, "crop": ""},
		{"x": 698.0, "y": 390.0, "w": 16.0, "h": 16.0, "dry": false, "age": 0.0, "crop": ""}
	]
	farm.refresh()
	actor.position = Vector2(658, 398)
	check(not farm.plant(actor) and count_item("ali", "seeds") == 3, "dry plot rejects seed consumption")
	farm.fill_bucket(actor)
	await key(KEY_E)
	await key(KEY_G)
	check(farm.plots[0].crop == "wheat" and count_item("ali", "seeds") == 2, "real G plants wheat after irrigation")
	actor.position = Vector2(658, 340)
	await key(KEY_B)
	var index := -1
	for i in range(21):
		if inventory.ensure_bag("ali")[i].get("item", "") == "rice_seeds": index = i
	check(index >= 0, "rice seeds appear in the bag")
	if index >= 0:
		await click(ui.bag_buttons[index])
		await click(ui.use_button)
	check(not inventory.opened and farm.seed_for(actor) == "rice_seeds" and count_item("ali", "rice_seeds") == 3, "actual bag use selects rice without consuming away from farmland")
	actor.position = Vector2(706, 398)
	await key(KEY_G)
	check(farm.plots[1].crop == "rice" and count_item("ali", "rice_seeds") == 2, "G plants selected rice")
	check(farm.seed_for(world.controllable[1]) == "seeds", "seed selection is independent per character")
	check(not farm.harvest(actor), "immature crops cannot be harvested")
	var elapsed := 0.0
	for boundary: Array in [[119.9, 1, false], [120.0, 2, false], [239.9, 2, false], [240.0, 3, false], [359.9, 3, false], [360.0, 4, false], [479.9, 4, false], [480.0, 4, true]]:
		var target: float = boundary[0]
		farm.advance(target - elapsed)
		elapsed = target
		for p: Dictionary in farm.plots:
			check(p.stage == boundary[1] and p.mature == boundary[2], "both crops respect phase and maturity boundary at " + str(target))
		if target == 240.0:
			farm.fill_bucket(actor)
			farm.water(actor)
			check(farm.plots[1].growth == 240 and farm.plots[1].age == 0, "watering resets only drought clock")
		if target == 359.9:
			check(persistence.save_now(), "partial crop growth saved")
			game.queue_free()
			await frames()
			await load_game()
			actor = world.active_resident
			check(is_equal_approx(farm.plots[0].growth, target) and farm.plots[1].crop == "rice" and farm.seed_for(actor) == "rice_seeds", "restart preserves species, elapsed time and seed choice without offline growth")
	check(farm.nearby(actor).description.contains("已成熟"), "nearby HUD explains mature harvest")
	var saved_bag: Array = inventory.ensure_bag("ali").duplicate(true)
	for i in range(21): inventory.ensure_bag("ali")[i] = {"item": "book", "count": 10}
	check(not farm.harvest(actor) and farm.plots[1].mature, "full bag leaves mature crop in the soil")
	inventory.bags.ali = saved_bag
	await key(KEY_G)
	check(farm.plots[1].crop == "" and count_item("ali", "rice") == 1 and count_item("ali", "rice_seeds") == 4, "real G collects ripe rice plus two rice seeds and empties the plot")
	await key(KEY_G)
	check(farm.plots[1].crop == "rice" and farm.plots[1].growth == 0 and count_item("ali", "rice_seeds") == 3, "wet harvested soil can reuse the returned seed with a fresh timer")
	actor.position = Vector2(658, 398)
	await key(KEY_G)
	check(farm.plots[0].crop == "" and count_item("ali", "wheat") == 1 and count_item("ali", "seeds") == 4, "wheat harvest yields wheat and two seeds even with rice selected")
	# Shared storage accepts seeds and grain without altering their species or counts.
	inventory.open_container("ali", actor.resident_name, "crop-test-chest", "种子箱")
	for i in range(21):
		if inventory.ensure_bag("ali")[i].get("item", "") == "rice": inventory.slot_clicked("bag", i, true)
	check(inventory.ensure_container("crop-test-chest")[0].get("item", "") == "rice", "harvested grain uses normal 21-slot storage")
	inventory.close()
	# Save a growing rice crop; altar restores this exact clock and chosen seed.
	farm.advance(125.5)
	check(persistence.save_checkpoint(false), "growing crop altar checkpoint saved")
	farm.advance(400)
	farm.selected_seeds.ali = "seeds"
	check(persistence.restore_checkpoint(), "altar restores crop snapshot")
	check(farm.plots[1].crop == "rice" and farm.plots[1].growth == 125.5 and farm.plots[1].stage == 2 and farm.seed_for(actor) == "rice_seeds", "altar rewinds species, stage, time and seed choice together")
	# Large frame steps cross drought safely; watering never revives the old plant.
	actor.position = Vector2(706, 398)
	farm.plots[1].age = 7199.9
	farm.plots[1].growth = 479.8
	farm.refresh()
	farm.advance(0.1)
	check(not farm.plots[1].dry and not farm.plots[1].mature, "exact drought boundary does not dry early or add excess growth")
	farm.advance(0.1)
	check(farm.plots[1].dry and farm.plots[1].crop == "dead" and not farm.plots[1].mature, "drought kills crops and prevents harvest")
	var stopped := float(farm.plots[1].growth)
	farm.advance(500)
	check(farm.plots[1].growth == stopped and not farm.harvest(actor), "dead crops do not continue to grow")
	farm.fill_bucket(actor)
	farm.water(actor)
	check(farm.plots[1].crop == "" and farm.plots[1].growth == 0, "rewatering clears dead growth instead of resurrecting it")
	check(farm.plant(actor) and farm.plots[1].crop == "rice", "recovered soil accepts selected seed")
	# Legacy IDs and generic seedlings migrate without losing stored quantities.
	var legacy: Dictionary = inventory.export_data()
	for i in range(21):
		if legacy.bags.ali[i].get("item", "") == "seeds": legacy.bags.ali[i] = {}
	legacy.bags.ali[10] = {"item": "seeds", "count": 7}
	for id: String in legacy.bags:
		for i in range(21):
			if legacy.bags[id][i].get("item", "") == "rice_seeds": legacy.bags[id][i] = {}
		legacy.grants[id].erase("rice_seeds")
	legacy.session.homestead.plots[0].crop = "seedling"
	legacy.session.homestead.plots[0].erase("growth")
	legacy.session.homestead.erase("selected_seeds")
	persistence.checkpoint = legacy
	check(persistence.restore_checkpoint(), "pre-expansion altar still loads")
	check(farm.plots[0].crop == "wheat" and farm.plots[0].growth == 0 and count_item("ali", "seeds") == 7, "old seedlings become wheat and existing seed quantity is retained")
	check(count_item("ali", "rice_seeds") == 3, "pre-expansion altar grants new rice supplies once")
	inventory.grant_supplies("ali")
	check(count_item("ali", "rice_seeds") == 3, "restored supplies remain idempotent")
	game.queue_free()
	await frames()
	if failures.is_empty():
		print("CROPS_SMOKE_OK: both seeds, real UI/G input, four 120-second stages, 480-second maturity, irrigation, full-bag harvest protection, storage, partial restart, altar rollback and legacy saves")
		quit(0)
	else:
		print("CROPS_SMOKE_FAILED: ", failures)
		quit(1)
