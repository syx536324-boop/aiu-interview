# Verifies independent farm cells, connected fifteen-cell watering and atomic crop/seed rewards.
extends SceneTree

const Grid := preload("res://features/homestead/farm_grid.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func count_item(items: Node, item: String) -> int:
	var count := 0
	for slot: Dictionary in items.ensure_bag("ali"):
		if slot.get("item", "") == item: count += int(slot.count)
	return count

func _initialize() -> void:
	var path := "res://.runtime/farm-cells-" + str(Time.get_ticks_usec()) + "/state.json"
	OS.set_environment("AIU5_STATE_PATH", path)
	OS.set_environment("AIU5_PROFILE_PATH", path + ".names")
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var session: Node = game.get_node("Session")
	session.simulation.reset()
	var farm: Node = game.get_node("Homestead")
	var items: Node = game.get_node("Inventory")
	var actor: CharacterBody2D = session.world.active_resident
	items.exchange("ali", {}, {"bucket": 1}) # Prepared crafted container.
	check(farm.plots.size() == 15, "starter farm contains fifteen independent cells")
	for p: Dictionary in farm.plots: check(p.w == 16 and p.h == 16, "each starter cell is 16 by 16")
	actor.position = Vector2(226, 238)
	farm.fill_bucket(actor)
	check(farm.water(actor), "one full bucket irrigates starter farm")
	check(farm.plots.all(func(p: Dictionary) -> bool: return not p.dry and p.age == 0), "all fifteen cells watered")
	check(count_item(items, "water_bucket") == 0 and count_item(items, "bucket") == 1, "exactly one full bucket used and empty bucket returned")
	# Start with empty wet cells to plant adjacent wheat and rice independently.
	for p: Dictionary in farm.plots: p.crop = ""
	farm.refresh()
	check(farm.plant(actor) and farm.plots[0].crop == "wheat", "one seed plants only the selected wheat cell")
	actor.position += Vector2(16, 0)
	check(farm.nearby(actor).index == 1, "walking one cell selects the adjacent cell")
	farm.selected_seeds.ali = "rice_seeds"
	check(farm.plant(actor) and farm.plots[1].crop == "rice" and farm.plots[2].crop == "", "adjacent cell independently plants rice")
	farm.advance(480)
	var rice_before := count_item(items, "rice")
	var seeds_before := count_item(items, "rice_seeds")
	check(farm.harvest(actor), "mature rice can be harvested")
	check(count_item(items, "rice") == rice_before + 1 and count_item(items, "rice_seeds") == seeds_before + 2, "rice yields one rice and two seeds")
	check(farm.plots[0].mature and farm.plots[1].crop == "", "harvest leaves adjacent ripe wheat intact")
	actor.position = Vector2(226, 238)
	var bag: Array = items.ensure_bag("ali").duplicate(true)
	# There is room for grain but no room for the seed: neither reward may be applied.
	for i in range(21): items.bags.ali[i] = {"item": "book", "count": 10}
	items.bags.ali[0] = {}
	var full: Array = items.bags.ali.duplicate(true)
	check(not farm.harvest(actor) and items.bags.ali == full and farm.plots[0].mature, "one free slot cannot partially harvest two rewards")
	items.bags.ali = bag
	var wheat_before := count_item(items, "wheat")
	seeds_before = count_item(items, "seeds")
	check(farm.harvest(actor) and count_item(items, "wheat") == wheat_before + 1 and count_item(items, "seeds") == seeds_before + 2, "wheat returns two wheat seeds even with rice selected")
	# Legacy large plot retains soil clocks everywhere and exactly one old crop.
	farm.restore({"plots": [{"x": 218.0, "y": 230.0, "w": 80.0, "h": 48.0,
		"dry": false, "age": 600.0, "crop": "rice", "growth": 125.5}]})
	items.exchange("ali", {}, {"bucket": 1}) # Prepared crafted container.
	check(farm.plots.size() == 15 and farm.plots[0].growth == 125.5 and farm.plots[0].crop == "rice", "legacy crop progress survives splitting")
	check(farm.plots.filter(func(p: Dictionary) -> bool: return p.crop != "").size() == 1, "migration does not duplicate old crop")
	check(farm.plots.all(func(p: Dictionary) -> bool: return not p.dry and p.age == 600), "legacy moisture age survives on every cell")
	var snapshot: Dictionary = farm.export_state()
	farm.restore(snapshot)
	check(farm.export_state() == snapshot, "cell migration is idempotent on reload")
	# A larger connected field is capped at fifteen; detached plots remain dry.
	farm.restore({"plots": [{"x": 650.0, "y": 390.0, "w": 96.0, "h": 80.0,
		"dry": true, "age": 0.0, "crop": ""}, {"x": 900.0, "y": 390.0, "w": 16.0, "h": 16.0,
		"dry": true, "age": 0.0, "crop": ""}]})
	actor.position = Vector2(658, 398)
	farm.fill_bucket(actor)
	check(farm.water(actor), "larger field can be watered")
	check(farm.plots.filter(func(p: Dictionary) -> bool: return not p.dry).size() == 15 and farm.plots[30].dry, "one bucket caps at fifteen connected cells")
	actor.position = Vector2(908, 398)
	farm.fill_bucket(actor)
	check(farm.water(actor) and not farm.plots[30].dry, "an isolated cell still accepts one full bucket")
	check(session.persistence.save_now(), "independent cells save successfully")
	var saved: Dictionary = farm.export_state()
	game.queue_free()
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var restored: Dictionary = game.get_node("Homestead").export_state()
	check(restored.plots == saved.plots and restored.selected_seeds == saved.selected_seeds, "actual game reload preserves individual cell states")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("FARM_CELLS_SMOKE_OK")
		quit(0)
	else: quit(1)
