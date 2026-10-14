# Integrates real SceneTree frames with the production/foraging clock and workshop UI.
# Shortened deadlines are fixtures; this test never calls a domain elapse or clock _process.
extends Node

const BENCH_ID := "outdoors:craft-clock-probe"
var game: Node
var s: Node
var ui: Node
var directory := ""
var failures: Array[String] = []
var checks := 0
var capture := false

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var base := OS.get_environment("AIU5_PROBE_DIRECTORY")
	assert(base != "" and base.is_absolute_path(), "Supply an absolute isolated probe directory")
	# Never overwrite an earlier test or a real player's state.
	directory = base.path_join("crafting-clock-" + str(Time.get_ticks_usec()))
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	OS.set_environment("AIU5_STATE_PATH", directory.path_join("state.json"))
	OS.set_environment("AIU5_PROFILE_PATH", directory.path_join("names.cfg"))
	OS.set_environment("AIU5_WORLD_PROFILE", "starter_v2")
	OS.set_environment("AIU5_WORLD_SEED", "91091")
	capture = OS.get_environment("AIU5_CAPTURE") == "true"
	get_tree().create_timer(55, true).timeout.connect(func() -> void:
		push_error("Crafting real-clock probe timed out")
		get_tree().quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func frames(n := 3) -> void:
	for i in range(n): await get_tree().process_frame

func wait_real(seconds: float) -> void:
	# This timer wakes the probe while the pausable game is frozen.
	await get_tree().create_timer(seconds, true).timeout
	await frames()

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func count(item: String) -> int:
	var result := 0
	for slot: Dictionary in s.inventory.ensure_bag("ali"):
		if slot.get("item", "") == item: result += int(slot.count)
	return result

func remaining() -> float:
	return float(s.production.crafts.jobs.get(BENCH_ID, {}).get("remaining", -1))

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(game)
	s = game.get_node("Session")
	ui = game.get_node("Workshop")
	# Keep actors still, but retain the real Simulation and every timed domain.
	for actor: Node in s.world.residents: actor.set_physics_process(false)
	s.pause_requested.connect(pause_menu)
	await frames()
	check(s.simulation.is_processing() and s.simulation.can_process(), "real Simulation is enabled")
	check(s.production.is_processing(), "production is registered with the external clock")
	check(s.foraging.is_processing(), "foraging is registered with the external clock")
	check(s.world.settlement == "starter_v2", "isolated starter_v2 profile")
	check(s.inventory.path.begins_with(directory), "inventory uses only the unique isolated path")

func pause_menu() -> void:
	# The main-scene fixture supplies the exact StartMenu.pause_game pause contract.
	s.simulation.flush()
	s.menu_paused = true
	s.refresh_interface()
	get_tree().paused = true

func resume_menu() -> void:
	get_tree().paused = false
	s.menu_paused = false
	s.refresh_interface()

func find_bench() -> Node2D:
	for fixture: Node2D in s.grounds.fixtures:
		if fixture.fixture_id == BENCH_ID: return fixture
	return null

func open_bench(bench: Node2D) -> void:
	s.world.active_resident.position = bench.position + Vector2(0, 14)
	s.production.open_near()
	await frames()
	check(s.production.opened and s.production.mode == "craft" and ui.root.visible,
		"workbench opens the live crafting UI")
	check(s.production.station_id() == BENCH_ID, "proximity selects the test workbench")
	check(not get_tree().paused, "opening crafting does not pause the tree")

func screenshot(name: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(name)) == OK,
		"save crafting progress screenshot")

func run() -> void:
	await load_game()
	s.inventory.bags.ali = s.inventory._sanitize_slots([
		{"item": "wood", "count": 40}, {"item": "stone", "count": 40},
		{"item": "iron_ore", "count": 3}])
	var bench: Node2D = s.grounds.add_fixture({"id": BENCH_ID, "kind": "workbench",
		"at": [740, 1010], "size": [36, 24]})
	await open_bench(bench)
	check(s.production.perform("pickaxe"), "normal perform starts the paid pickaxe job")
	check(count("wood") == 39 and count("stone") == 38 and count("pickaxe") == 0,
		"materials reserved exactly once with no early output")
	check(remaining() > 59 and remaining() <= 60, "job initially reserves sixty online seconds")
	var initial := remaining()
	await wait_real(2.2)
	print("CRAFTING_CLOCK_PROGRESS initial=", initial, " remaining=", remaining(),
		" progress=", ui.progress.value, " tree_paused=", get_tree().paused)
	check(remaining() < initial - 1.0 and remaining() > initial - 4.0,
		"real clock advances the job while workshop stays open")
	check(ui.root.visible and ui.progress.visible and ui.progress.value > 0.5,
		"state snapshots visibly advance the progress bar")
	check(ui.job_label.text.contains("剩余") and not ui.job_label.text.contains("剩余60.0秒"),
		"live UI countdown leaves sixty seconds")
	check(not s.production.perform("pickaxe"), "busy table rejects a second reservation")
	check(count("wood") == 39 and count("stone") == 38,
		"time and rejected confirmation do not charge materials again")
	await screenshot("crafting-clock-progress.png")

	s.production.close()
	await key(KEY_ESCAPE)
	check(s.menu_paused and get_tree().paused, "Esc requests the menu pause contract")
	var paused_remaining := remaining()
	var paused_forage: float = s.foraging.online
	await wait_real(0.9)
	check(is_equal_approx(remaining(), paused_remaining), "menu pause freezes paid jobs")
	check(is_equal_approx(s.foraging.online, paused_forage), "menu pause freezes foraging time")
	resume_menu()
	await wait_real(0.8)
	check(remaining() < paused_remaining, "menu resume restarts the real clock")
	await key(KEY_M)
	check(s.overview and get_tree().paused, "actual M path pauses the full map")
	paused_remaining = remaining()
	paused_forage = s.foraging.online
	await wait_real(0.9)
	check(is_equal_approx(remaining(), paused_remaining), "full map freezes paid jobs")
	check(is_equal_approx(s.foraging.online, paused_forage), "full map freezes foraging time")
	await key(KEY_M)
	check(not s.overview and not get_tree().paused, "actual M path resumes from the full map")

	check(s.persistence.save_now(), "normal save persists fractional job progress")
	var saved_remaining := remaining()
	var saved_forage: float = s.foraging.online
	game.queue_free()
	await frames(4)
	await wait_real(0.8) # No game exists: this wall time must not advance its saved job.
	await load_game()
	check(remaining() <= saved_remaining + 0.001 and remaining() > saved_remaining - 0.75,
		"real restart preserves the paid job without charging offline wall time")
	print("CRAFTING_CLOCK_RESTART saved_forage=", saved_forage, " restored_forage=", s.foraging.online)
	check(s.foraging.online >= saved_forage - 0.001 and s.foraging.online < saved_forage + 0.75,
		"real restart restores the foraging clock")
	check(count("wood") == 39 and count("stone") == 38 and count("pickaxe") == 0,
		"reload retains one reservation and no early output")
	bench = find_bench()
	check(bench != null, "restart restores the same stable workbench ID")
	if bench == null:
		finish()
		return
	await open_bench(bench)
	# Shorten only this paid fixture's deadline; completion still uses genuine clock frames.
	s.production.crafts.jobs[BENCH_ID].remaining = 1.2
	await wait_real(0.15)
	check(count("pickaxe") == 0, "no output before the shortened deadline")
	await wait_real(1.7)
	check(count("pickaxe") == 1 and not s.production.crafts.jobs.has(BENCH_ID),
		"real clock completes and credits exactly one pickaxe")
	await wait_real(0.7)
	check(count("pickaxe") == 1, "later real ticks cannot credit a duplicate output")
	check(count("wood") == 39 and count("stone") == 38,
		"completion never spends the reserved materials twice")

	check(s.production.perform("pickaxe"), "second paid job starts for full-bag recovery")
	check(count("wood") == 38 and count("stone") == 36, "second job has its own single payment")
	var bag: Array = s.inventory.ensure_bag("ali")
	for i in range(bag.size()): bag[i] = {"item": "book", "count": 10}
	bag[0] = {"item": "pickaxe", "count": 1}
	s.production.crafts.jobs[BENCH_ID].remaining = 0.8
	await wait_real(1.6)
	check(remaining() == 0 and count("pickaxe") == 1,
		"full bag retains a finished job without dropping or duplicating output")
	check(ui.job_label.text.contains("成品待领"), "UI presents held finished output")
	await wait_real(0.7)
	check(count("pickaxe") == 1 and remaining() == 0, "held output is stable across real ticks")
	s.inventory.ensure_bag("ali")[20] = {}
	check(s.production.perform("craft:collect"), "normal collect delivers the held output after freeing a slot")
	check(count("pickaxe") == 2 and not s.production.crafts.jobs.has(BENCH_ID),
		"held output is delivered exactly once")
	check(not s.production.perform("craft:collect"), "duplicate collection is rejected")
	s.production.close()

	s.inventory.bags.ali = s.inventory._sanitize_slots([{"item": "iron_ore", "count": 3}])
	var actor: CharacterBody2D = s.world.active_resident
	s.interiors.enter(actor, s.world.home_data("blacksmith"))
	s._sync_view()
	var stove: Node2D
	for fixture: Node2D in s.interiors.rooms.blacksmith.fixtures:
		if fixture.kind == "stove": stove = fixture
	check(stove != null, "starter blacksmith has its real furnace")
	if stove == null:
		finish()
		return
	actor.position = Vector2(stove.collision_bounds().end.x + 7,
		stove.collision_bounds().get_center().y)
	s.production.open_near()
	check(s.production.mode == "smelt" and s.production.is_smith(), "real furnace interaction selects smelting")
	check(s.production.perform("smelt"), "normal perform reserves one iron ore")
	var furnace: Dictionary = s.production.furnace_state()
	check(count("iron_ore") == 2 and furnace.remaining > 29 and furnace.remaining <= 30,
		"smelting reserves thirty seconds and exactly one ore")
	var furnace_initial: float = furnace.remaining
	await wait_real(0.9)
	print("CRAFTING_CLOCK_SMELT initial=", furnace_initial, " remaining=", furnace.remaining)
	check(furnace.remaining < furnace_initial, "real clock advances smelting with its UI open")
	furnace.remaining = 0.8
	await wait_real(1.6)
	check(furnace.remaining == 0 and furnace.ready == 1 and count("crude_iron") == 0,
		"real furnace completes one held ingot")
	await wait_real(0.7)
	check(furnace.ready == 1, "later ticks cannot produce another ingot")
	check(s.production.perform("collect") and count("crude_iron") == 1,
		"normal furnace collect delivers one ingot")
	check(not s.production.perform("collect") and count("iron_ore") == 2,
		"duplicate furnace collect neither delivers nor charges")
	s.production.close()

	var pickup: Node2D = s.foraging.nodes["desert:0"]
	s.interiors.leave(actor, s.world.objects, pickup.position)
	s._sync_view()
	check(s.foraging.gather("desert:0"), "normal gather starts the resource regrowth deadline")
	check(not pickup.available and not s.world.points.has("forage:desert:0"),
		"gathered resource and its interaction point disappear")
	var regrowth_before := float(s.foraging.collected["desert:0"]) - float(s.foraging.online)
	await wait_real(0.9)
	var regrowth_after := float(s.foraging.collected["desert:0"]) - float(s.foraging.online)
	print("CRAFTING_CLOCK_FORAGING initial=", regrowth_before, " remaining=", regrowth_after)
	check(regrowth_after < regrowth_before, "real clock decreases foraging time remaining")
	s.foraging.collected["desert:0"] = s.foraging.online + 0.8
	await wait_real(1.6)
	check(pickup.available and s.world.points.has("forage:desert:0"),
		"real clock restores the resource and interaction point")
	finish()

func finish() -> void:
	get_tree().paused = false
	if is_instance_valid(game): game.queue_free()
	print("CRAFTING_CLOCK_FAILURES=" + JSON.stringify(failures))
	if failures.is_empty(): print("CRAFTING_CLOCK_PROBE_OK checks=" + str(checks))
	get_tree().quit(0 if failures.is_empty() else 1)
