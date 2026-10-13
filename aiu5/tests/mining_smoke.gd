# Exercises expanded terrain, real mine transitions, finite deposits, workbench crafting and saves.
extends SceneTree

const PATH := "res://.runtime/test-mining.json"
const Ore := preload("res://features/mining/ore.gd")
var failures: Array[String] = []
var game: Node
var world: Node2D
var mining: Node
var inventory: Node
var session: Node
var interiors: Node2D
var iron_id := ""

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-mining-names.cfg")
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(45).timeout.connect(func() -> void: push_error("MINING_TIMEOUT"); quit(2))
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

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	mining = game.get_node("Mining")
	inventory = game.get_node("Inventory")
	session = game.get_node("Session")
	interiors = game.get_node("Interiors")
	for id in ["Livestock", "Vitals", "Homestead", "Persistence", "Mining"]: game.get_node(id).set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for animal in game.get_node("Livestock").animals: animal.set_physics_process(false)
	await frames()

func count_item(item: String) -> int:
	var result := 0
	for slot: Dictionary in inventory.ensure_bag("ali"):
		if slot.get("item", "") == item: result += int(slot.count)
	return result

func blocked(at: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.5
	query.shape = shape
	query.transform = Transform2D(0, at + Vector2(0, -3))
	query.collision_mask = 1
	return not world.get_world_2d().direct_space_state.intersect_shape(query).is_empty()

func run_checks() -> void:
	await load_game()
	mining.restore({"cave_version":2,"cave_seed":42},42)
	check(world.SIZE == Vector2(4800, 1600) and world.BOUNDS.size == Vector2(7200, 3200), "expanded map has ample space for future tribes")
	check(blocked(Vector2(45, 840)) and not blocked(Vector2(45, 900)), "river has physical water barrier with a passable bridge gap")
	check(blocked(Vector2(2200, 500)) and not blocked(mining.DOOR), "high mountains block movement while cave approach stays open")
	check(not world.navigation.find_path(Vector2(322, 224), mining.DOOR).is_empty(), "long eastern route reaches mine")
	check(mining.surface.size() == 10, "ten surface stone deposits are distributed across desert")
	var grounds: Node2D = game.get_node("Grounds")
	check(grounds.land_error(Rect2(1200, 1050, 16, 16), world.active_resident) == "", "new wilderness is walkable and usable for future construction")
	check(grounds.land_error(Rect2(48, 840, 16, 16), world.active_resident) != "", "western river rejects construction and tilling")
	check(grounds.land_error(Rect2(2200, 500, 16, 16), world.active_resident) != "", "mountains reject construction and tilling")
	check(grounds.land_error(Rect2(500, 320, 16, 16), world.active_resident) != "", "expanded altar grounds remain open")
	world.active_resident.position = Vector2(111, 840)
	inventory.exchange("ali", {}, {"bucket":1, "wooden_cup":1, "pickaxe":1}) # Prepared crafted tools.
	await key(KEY_E)
	check(inventory.has_item("ali", "water_bucket") and inventory.has_item("ali", "water_cup"), "real river interaction fills both water containers")
	check(game.get_node("Magic").equip_weapon("ali","pickaxe"),"equip pickaxe before mining")
	var ore: Node2D = mining.surface["surface:1"]
	world.active_resident.position = ore.position + Vector2(0, 15)
	for i in range(3):
		mining.cooldown = 0
		await key(KEY_E)
	check(count_item("stone") == 3 and not ore.visible and ore.body.collision_layer == 0, "three real E strikes yield stone and clear surface collider")
	check(not world.points.has("ore:surface:1"), "exhausted surface deposit removes interaction point")
	# A deployed outdoor workbench can consume exactly the requested recipe.
	inventory.exchange("ali", {}, {"wood": 3})
	var bench: Node2D = grounds.add_fixture({"id": "outdoors:testbench", "kind": "workbench", "at": [678, 390], "size": [36, 24], "orientation": 0, "variant": 0})
	world.active_resident.position = Vector2(696, 425)
	var before_pickaxes := count_item("pickaxe")
	await key(KEY_E)
	check(session.production.perform("pickaxe"),"outdoor recipe confirmed")
	session.production.elapse(60)
	check(count_item("pickaxe") == before_pickaxes + 1 and count_item("wood") == 2 and count_item("stone") == 1, "real outdoor workbench E crafts pickaxe with one wood and two stones")
	var before: Array = inventory.ensure_bag("ali").duplicate(true)
	await key(KEY_E)
	check(inventory.ensure_bag("ali") == before, "missing ingredients never partially consume wood")
	for i in range(21): inventory.bags.ali[i] = {"item": "wood", "count": 99}
	inventory.bags.ali[0] = {"item": "stone", "count": 99}
	check(not session.production.perform("pickaxe") and inventory.bags.ali[0].count == 99 and inventory.bags.ali[1].count == 99, "full bag crafting is atomic")
	inventory.bags.ali = before
	session.production.close()
	world.active_resident.position = mining.DOOR
	await key(KEY_E)
	check(world.active_resident.room_id == "mine" and not world.visible and interiors.rooms.mine.camera.enabled, "real E cave entry switches to underground camera")
	var room: Node2D = interiors.rooms.mine
	var iron: Node2D
	for candidate in room.objects.get_children():
		if candidate is Ore and candidate.kind == "iron_ore":
			iron = candidate
			iron_id = candidate.resource_id
			break
	world.active_resident.position = iron.position + Vector2(0, 15)
	for i in range(3):
		mining.cooldown = 0
		await key(KEY_E)
	check(iron.hits == 3 and count_item("iron_ore") == 0, "iron requires all four strikes")
	before = inventory.ensure_bag("ali").duplicate(true)
	for i in range(21): inventory.bags.ali[i] = {"item": "wood", "count": 99}
	inventory.bags.ali[0] = {"item": "pickaxe", "count": 1}
	mining.cooldown = 0
	await key(KEY_E)
	check(iron.hits == 3 and iron.visible, "full bag preserves last iron strike and reward")
	inventory.bags.ali = before
	mining.cooldown = 0
	await key(KEY_E)
	check(count_item("iron_ore") == 2 and not iron.visible, "final strike grants two iron ore once")
	check(not mining.strike(world.active_resident, iron), "exhausted vein cannot be farmed again")
	var saved_position: Vector2 = world.active_resident.position
	check(game.get_node("Persistence").save_now(), "underground autosave writes")
	game.queue_free()
	await frames(3)
	await load_game()
	check(world.active_resident.room_id == "mine" and world.active_resident.position == saved_position and count_item("iron_ore") == 2, "relaunch resumes underground position and ore inventory")
	check(mining.progress.get(iron_id,0) == 4 and not mining.surface["surface:1"].visible, "underground and surface depletion both survive relaunch")
	room = interiors.rooms.mine
	world.active_resident.position = room.exit_point()
	await key(KEY_E)
	check(world.active_resident.room_id == "" and world.active_resident.position.distance_to(mining.DOOR) < 25 and world.camera.enabled, "real E stairs return to the saved surface entrance")
	# Room workbenches use the same transaction, and checkpoint rollback restores deposits.
	interiors.enter(world.active_resident, world.home_data("house"))
	room = interiors.rooms.house
	bench = room.add_fixture({"id": "house:testbench", "kind": "workbench", "at": [120, 84], "size": [36, 24], "orientation": 0, "variant": 1})
	inventory.exchange("ali", {}, {"stone": 2})
	world.active_resident.position = Vector2(139, 121)
	before_pickaxes = count_item("pickaxe")
	await key(KEY_E)
	check(session.production.perform("pickaxe"),"indoor recipe confirmed")
	session.production.elapse(60)
	check(count_item("pickaxe") == before_pickaxes + 1, "indoor workbench E opens timed crafting")
	session.production.close()
	interiors.leave(world.active_resident, world.objects, Vector2(548, 334))
	session._sync_view()
	game.get_node("Persistence").save_checkpoint(false)
	ore = mining.surface["surface:2"]
	world.active_resident.position = ore.position + Vector2(0, 15)
	mining.cooldown = 0
	mining.strike(world.active_resident, ore)
	check(ore.hits == 1, "post-checkpoint strike advances deposit")
	check(game.get_node("Persistence").restore_checkpoint() and ore.hits == 0 and ore.visible, "altar rollback restores surface veins and their collider")
	game.queue_free()
	await frames(3)
	if failures.is_empty(): print("MINING_SMOKE_OK")
	else: print("MINING_FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)
