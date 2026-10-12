# Tests survival boundaries, usable farming/cooking/building and complete save/checkpoint recovery.
extends SceneTree

const PATH := "res://.runtime/test-survival.json"
const Vitals := preload("res://features/survival/vitals.gd")
var failures: Array[String] = []
var game: Node
var world: Node2D
var session: Node
var inventory: Node
var vitals: Node
var farm: Node
var persistence: Node

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-survival-names.cfg")
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(45).timeout.connect(func() -> void: push_error("SURVIVAL_TIMEOUT"); quit(2))
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

func point_at_clear(editor: Node, area: Rect2) -> bool:
	# Seeded resources can occupy former sample coordinates; exercise placement on actual free ground.
	for y in range(int(area.position.y), int(area.end.y), 8):
		for x in range(int(area.position.x), int(area.end.x), 8):
			editor.point_at(Vector2(x, y))
			if editor.ghost.preview_valid: return true
	return false

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	inventory = game.get_node("Inventory")
	vitals = game.get_node("Vitals")
	farm = game.get_node("Homestead")
	persistence = game.get_node("Persistence")
	# Time advances explicitly; NPC physics is frozen for reproducible placement checks.
	vitals.set_process(false)
	farm.set_process(false)
	persistence.set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for pig in world.pigs: pig.set_physics_process(false)
	await frames()

func run_checks() -> void:
	var rules := Vitals.new()
	var s: Dictionary = rules.ensure("test")
	rules.advance(179.9)
	check(s.hunger == 10 and s.thirst == 10, "needs remain full before 180 online seconds")
	rules.advance(0.1)
	check(s.hunger == 9 and s.thirst == 9, "both needs lose exactly one at 180 seconds")
	s.hunger = 1
	s.thirst = 1
	rules.advance(9.9)
	check(s.life == 10, "no early starvation damage")
	rules.advance(0.1)
	check(s.life == 9, "both low needs cause one total damage per ten seconds")
	s.hunger = 10
	s.thirst = 10
	s.health = 3
	rules.advance(0.1)
	check(s.life == 4 and s.low_health, "entering low health removes five life once")
	rules.advance(10)
	check(s.life == 4, "low health penalty does not repeat every frame")
	s.health = 4
	rules.advance(1)
	check(not s.low_health and s.low_time == 0, "recovering above three resets the low-health deadline")
	s.life = 10
	s.health = 3
	rules.advance(0.1)
	check(s.life == 5, "a later separate descent into low health applies five damage again")
	s.low_time = 1799
	rules.advance(1)
	check(s.life == 0, "thirty continuous minutes of low health kills")
	rules.free()
	await load_game()
	check(world.houses.size() == 14, "new eighth kitchen house exists")
	check(not inventory.has_item("ali", "bucket"), "no crafted containers are granted at startup")
	for resident in world.controllable:
		inventory.exchange(resident.resident_id, {}, {"bucket": 1, "hoe": 1, "fence": 1, "workbench": 1, "bread": 5}) # Prepared crafted supplies.
	var actor: CharacterBody2D = world.active_resident
	actor.position = Vector2(334, 207)
	await key(KEY_E)
	check(inventory.has_item("ali", "water_bucket") and not inventory.has_item("ali", "bucket"), "actual E fills one empty bucket at well")
	actor.position = Vector2(258, 284)
	await key(KEY_E)
	check(not farm.plots[0].dry and inventory.has_item("ali", "bucket"), "one bucket irrigates one field and returns empty bucket")
	actor.position = Vector2(157, 205)
	await key(KEY_E)
	check(inventory.has_item("ali", "water_bucket"), "actual E also fills at lake shore")
	s = vitals.ensure("ali")
	s.thirst = 4
	check(vitals.use_food("ali", "water_bucket") and s.thirst == 8, "drinking a quarter bucket restores four thirst")
	check(inventory.has_item("ali", "water_bucket_3") and not inventory.has_item("ali", "bucket"), "drinking preserves the other three quarters of the bucket")
	actor.position = Vector2(650, 390)
	actor.facing = 0
	await key(KEY_Q)
	check(farm.plots.size() == 16 and farm.plots[15].dry, "Q with hoe makes a new dry farm plot")
	if farm.plots.size() > 15:
		actor.position = Vector2(farm.plots[15].x + 8, farm.plots[15].y + 8)
		check(not farm.plant(actor), "dry plot rejects planting")
		farm.fill_bucket(actor)
		farm.water(actor)
		await key(KEY_G)
		check(farm.plots[15].crop == "wheat", "G plants wheat seeds in an irrigated plot")
		farm.advance(7200)
		check(not farm.plots[15].dry, "exactly two hours is not more than two hours")
		farm.advance(0.1)
		check(farm.plots[15].dry and farm.plots[15].crop == "dead", "over two hours kills crop and dries soil")
		check(not farm.plant(actor), "drought blocks replanting")
		farm.fill_bucket(actor)
		farm.water(actor)
		check(farm.plots[15].crop == "" and not farm.plots[15].dry, "irrigation restores soil without resurrecting dead crop")
		check(farm.plant(actor), "fresh seed can be planted after drought recovery")
	# Raw-food windows are independent for each character; illness applies actual run multiplier.
	inventory.exchange("ali", {}, {"pork": 5})
	s.health = 10
	for i in range(2): vitals.use_food("ali", "pork")
	check(not s.ill, "two raw meals do not cause illness")
	vitals.use_food("ali", "pork")
	check(s.ill and s.health == 7 and is_equal_approx(actor.run_multiplier, 0.7), "third raw meal causes illness, minus three health, minus thirty percent run speed")
	check(not vitals.ensure("heya").ill, "illness and meal histories are per character")
	vitals.use_food("ali", "pork")
	check(s.health == 7, "active illness is not repeatedly applied on every meal")
	inventory.exchange("ali", {}, {"cooked_pork": 1})
	vitals.use_food("ali", "cooked_pork")
	check(not s.ill and s.health == 8, "cooked meat recovers health and resolves illness")
	s.raw_meals = [s.active_time - 601, s.active_time - 601]
	vitals.use_food("ali", "pork")
	check(not s.ill, "meals older than ten minutes are excluded")
	# Kitchen interaction and offscreen, paused-offline cooking.
	inventory.exchange("ali", {}, {"pork": 1}) # One raw meal reserved for cooking.
	actor.position = world.home_data("kitchen").door
	await key(KEY_E)
	check(actor.room_id == "kitchen", "kitchen is enterable")
	actor.position = Vector2(48, 80)
	await key(KEY_E)
	check(farm.cooking.remaining == 60, "E at stove starts a sixty-second cooking job")
	farm.advance(59)
	check(farm.cooking.ready == 0, "meat is not cooked early")
	farm.advance(1)
	await key(KEY_E)
	check(inventory.has_item("ali", "cooked_pork") and farm.cooking.ready == 0, "E collects exactly one cooked pork")
	var previous_bag: Array = inventory.ensure_bag("ali").duplicate(true)
	for i in range(21): inventory.bags.ali[i] = {"item": "wood", "count": 99}
	farm.cooking.ready = 1
	check(not farm.stove(actor) and farm.cooking.ready == 1, "full bag does not lose cooked output")
	inventory.bags.ali = previous_bag
	check(farm.stove(actor) and farm.cooking.ready == 0, "cooked output remains claimable after making space")
	# Outdoor and indoor placement consumes items, blocks actors, and can be reclaimed.
	var interiors: Node2D = game.get_node("Interiors")
	var editor: Node = game.get_node("FurnitureEditor")
	session.toggle_furnishing()
	editor.choose("fence")
	editor.point_at(Vector2(92, 104))
	check(editor.place(), "inventory fence can be deployed inside kitchen")
	var room: Node2D = interiors.rooms.kitchen
	var fence: Node2D = room.fixtures.back()
	check(fence.kind == "fence" and fence.get_node("FurnitureBody").collision_layer == 1, "deployed indoor fence has a live collider")
	editor.pick(fence)
	check(editor.remove_selected(), "deployed fence can be reclaimed to bag")
	session.close_furnishing()
	interiors.leave(actor, world.objects, Vector2(650, 390))
	session._sync_view()
	session.toggle_furnishing()
	editor.choose("workbench")
	check(point_at_clear(editor, Rect2(640, 350, 48, 40)), "an actual clear outdoor location is available")
	check(editor.place(), "workbench deploys in the outdoor map")
	var grounds: Node2D = game.get_node("Grounds")
	check(grounds.fixtures.size() == 3, "outdoor deployable is registered")
	editor.choose("fence")
	editor.point_at(Vector2(710, 420))
	check(editor.place(), "fence also deploys in the outdoor map")
	var outdoor_fence: Node2D = grounds.fixtures.back()
	editor.pick(outdoor_fence)
	editor.ghost.set_placement(Vector2(716, 412), 1)
	check(editor.place() and outdoor_fence.orientation == 1, "outdoor fence can be moved and rotated without another item")
	editor.pick(outdoor_fence)
	check(editor.remove_selected(), "outdoor fence is reclaimed")
	editor.choose("fence")
	editor.point_at(world.home_data("kitchen").door)
	check(not editor.place(), "building cannot block kitchen doorway")
	session.close_furnishing()
	# Full auto save preserves rooms, inventory, timers, actor choice and cooking.
	session.select_resident(1)
	actor = world.active_resident
	interiors.enter(actor, world.home_data("house"))
	actor.position = Vector2(104, 104)
	session._sync_view()
	farm.cooking.remaining = 32.25
	vitals.ensure("heya").hunger = 5
	vitals.ensure("heya").need_time = 91.5
	check(persistence.save_now(), "full autosave writes successfully")
	var saved_clock: float = vitals.online
	game.queue_free()
	await frames(3)
	await load_game()
	actor = world.active_resident
	check(session.selected == 1 and actor.room_id == "house" and actor.position == Vector2(104, 104), "relaunch restores selected actor and exact indoor position")
	check(vitals.ensure("heya").hunger == 5 and vitals.ensure("heya").need_time == 91.5, "relaunch restores status and partial need timer")
	check(farm.cooking.remaining == 32.25 and vitals.online == saved_clock, "offline time does not advance cooking or survival")
	check(game.get_node("Grounds").fixtures.size() == 3, "outdoor workbench survives relaunch")
	# Altar checkpoint is distinct from autosave and restores the entire world after a wipe.
	interiors = game.get_node("Interiors")
	interiors.leave(actor, world.objects, Vector2(548, 334))
	session._sync_view()
	await key(KEY_E)
	check(session.gifts.opened, "E at altar opens ritual menu")
	session.gifts.save_altar()
	check(not persistence.checkpoint.is_empty(), "altar menu creates a recoverable checkpoint")
	session.gifts.close()
	var checkpoint_food: int = vitals.ensure("heya").hunger
	vitals.ensure("heya").hunger = 1
	inventory.resource_hits.deadwood_01 = 4
	game.get_node("Harvesting").restore()
	inventory.bags.heya[4] = {}
	persistence.save_now()
	for resident in world.controllable: vitals.ensure(resident.resident_id).life = 0
	vitals._sync_actors()
	vitals.deaths_changed.emit()
	await frames(3)
	check(vitals.ensure("heya").life == 10 and vitals.ensure("heya").hunger == checkpoint_food, "party wipe restores altar health and needs")
	check(inventory.resource_hits.get("deadwood_01", 0) == 0 and game.get_node("Harvesting").trees.deadwood_01.visible, "checkpoint rollback revives gathered tree and its collider")
	check(inventory.has_item("heya", "bread"), "checkpoint rollback restores inventory")
	check(world.active_resident.position.distance_to(Vector2(548, 334)) < 0.1, "checkpoint restores saved position")
	# One death switches control without rolling back living teammates.
	vitals.ensure(world.active_resident.resident_id).life = 0
	vitals._sync_actors()
	vitals.deaths_changed.emit()
	check(not world.active_resident.dead and session.selected != 1, "single death switches to a living playable resident")
	session.select_resident(1)
	check(session.selected != 1, "dead character cannot be selected")
	game.queue_free()
	await frames(3)
	if failures.is_empty(): print("SURVIVAL_SMOKE_OK")
	else: print("SURVIVAL_FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
