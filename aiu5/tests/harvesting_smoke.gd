# Verifies real chopping input, inventory rewards, obstacle removal and durable progress.
extends SceneTree

const Catalog := preload("res://features/inventory/catalog.gd")
const STATE := "res://.runtime/test-harvesting.json"
class FailingInventory extends "res://features/inventory/inventory.gd":
	func save_state() -> Error:
		return ERR_FILE_CANT_WRITE

var game: Node
var world: Node2D
var session: Node
var items: Node
var harvesting: Node
var failures: Array[String] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STATE).get_base_dir())
	OS.set_environment("AIU5_STATE_PATH", STATE)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/test-unused-names.cfg")
	create_timer(30).timeout.connect(func() -> void: push_error("HARVESTING_SMOKE_TIMEOUT"); quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OS.get_environment("AIU5_STATE_PATH") + ".altar"))
	call_deferred("run_checks")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CHECK FAILED: " + message)

func wood_count(actor: String) -> int:
	var total := 0
	for slot: Dictionary in items.ensure_bag(actor):
		if slot.get("item", "") == "wood":
			total += int(slot["count"])
	return total

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	session = game.get_node("Session")
	items = game.get_node("Inventory")
	harvesting = game.get_node("Harvesting")
	await frames(3)
	for resident: CharacterBody2D in world.residents:
		if resident != world.active_resident:
			resident.set_physics_process(false)

func run_checks() -> void:
	# A version-1 save made before harvesting must retain existing player belongings and rooms.
	var legacy_bag := Catalog.starter_slots()
	legacy_bag[4] = {"item":"bread", "count":17}
	var file := FileAccess.open(STATE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "bags": {"ali": legacy_bag}, "containers": {}, "rooms": {"stone_house": []}}))
	file.close()
	await load_game()
	check(harvesting.trees.size() == 6, "six dead trees spawn")
	check(items.ensure_bag("ali")[4]["count"] == 17 and items.layouts["stone_house"].is_empty(), "old save retains existing inventory and room layout")
	check(wood_count("ali") == 0 and Catalog.starter_slots().all(func(slot: Dictionary) -> bool: return slot.is_empty()), "tools and wood are gathered or crafted, never granted at startup")
	for tree: Node2D in harvesting.trees.values():
		check(not world.navigation.find_path(Vector2(322, 224), tree.position + Vector2(0, 16)).is_empty(), "each tree is reachable: " + tree.resource_id)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = tree.body.get_child(0).shape
		query.transform = tree.body.global_transform
		query.collision_mask = 1
		query.exclude = [tree.body.get_rid()]
		check(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "tree avoids existing solid props: " + tree.resource_id)
	var tree: Node2D = harvesting.trees["deadwood_01"]
	check(not harvesting.chop(tree.resource_id, world.active_resident), "distant actor cannot chop")
	world.active_resident.position = tree.position + Vector2(0, 20)
	await frames(2)
	Input.action_press("move_up")
	await frames(25)
	Input.action_release("move_up")
	check(world.active_resident.position.y >= tree.position.y + 6, "standing trunk physically blocks movement")
	items.ensure_bag("ali")[2] = {}
	await key(KEY_E)
	check(tree.hits == 0 and session.notice.contains("装备"), "axe must be in current actor's own bag")
	items.ensure_bag("ali")[2] = {"item": "stone_axe", "count": 1}
	check(game.get_node("Magic").equip_weapon("ali","stone_axe"),"equip axe before chopping")
	await key(KEY_B)
	await key(KEY_E)
	check(tree.hits == 0, "open inventory blocks chopping input")
	await key(KEY_ESCAPE)
	await key(KEY_E)
	check(tree.hits == 1 and wood_count("ali") == 0, "first chop gives no wood")
	await key(KEY_E)
	check(tree.hits == 1, "impact cooldown prevents duplicate hits")
	game.queue_free()
	await frames(2)
	await load_game()
	tree = harvesting.trees["deadwood_01"]
	check(tree.hits == 1, "one-chop progress survives restart")
	world.active_resident.position = tree.position + Vector2(0, 16)
	await frames(1)
	await key(KEY_E)
	check(tree.hits == 2 and wood_count("ali") == 1, "second chop adds exactly one wood")
	await frames(23)
	await key(KEY_E)
	check(tree.hits == 3 and wood_count("ali") == 1, "third chop gives no additional wood")
	await frames(23)
	var kept_bag: Array = items.ensure_bag("ali").duplicate(true)
	for i in range(21):
		items.ensure_bag("ali")[i] = {"item": "book", "count": 10}
	items.ensure_bag("ali")[0] = {"item": "wood", "count": 99}
	items.ensure_bag("ali")[2] = {"item": "stone_axe", "count": 1}
	var full_bag: Array = items.ensure_bag("ali").duplicate(true)
	await key(KEY_E)
	check(tree.hits == 3 and tree.body.collision_layer == 1 and items.ensure_bag("ali") == full_bag, "full bag preserves fourth chop and all items")
	items.bags["ali"] = kept_bag
	await key(KEY_E)
	check(tree.hits == 4 and wood_count("ali") == 2, "fourth chop gives second wood and finishes the tree")
	check(tree.body.collision_layer == 0 and not world.points.has("wood:deadwood_01"), "felled tree loses collider and interaction")
	await frames(24)
	check(not tree.visible, "felled tree disappears after impact feedback")
	check(not harvesting.chop(tree.resource_id, world.active_resident) and wood_count("ali") == 2, "felled tree cannot be harvested again")
	world.active_resident.position = tree.position + Vector2(0, 16)
	Input.action_press("move_up")
	await frames(24)
	Input.action_release("move_up")
	check(world.active_resident.position.y < tree.position.y, "player can walk through felled trunk location")
	var cell := Vector2i(floori(tree.position.x / 8), floori((tree.position.y - 3) / 8))
	check(not world.navigation.grid.is_point_solid(cell), "navigation obstacle clears immediately")
	await key(KEY_2)
	items.exchange("heya", {}, {"stone_axe":1}) # Prepared crafted axe for this independent bag.
	check(game.get_node("Magic").equip_weapon("heya","stone_axe"),"second actor equips own axe")
	world.active_resident.set_physics_process(true)
	var other: Node2D = harvesting.trees["deadwood_02"]
	world.active_resident.position = other.position + Vector2(0, 16)
	await frames(2)
	await key(KEY_E)
	await frames(23)
	await key(KEY_E)
	check(other.hits == 2 and wood_count("heya") == 1 and wood_count("ali") == 2, "wood goes to the current character, with independent tree progress")
	# Existing wood stacks still receive rewards when all 21 slots are occupied.
	await frames(23)
	for i in range(21):
		items.ensure_bag("heya")[i] = {"item": "book", "count": 10}
	items.ensure_bag("heya")[0] = {"item": "wood", "count": 98}
	items.ensure_bag("heya")[2] = {"item": "stone_axe", "count": 1}
	await key(KEY_E)
	await frames(23)
	await key(KEY_E)
	check(other.hits == 4 and wood_count("heya") == 99 and items.ensure_bag("heya").size() == 21, "wood stacks up to 99 even in a full bag")
	await key(KEY_1)
	world.active_resident.position = world.home_data("house")["door"] + Vector2(0, 4)
	await frames(2)
	await key(KEY_E)
	world.active_resident.position = Vector2(164, 70)
	await frames(2)
	await key(KEY_E)
	var storage_id: String = items.container_id
	check(storage_id != "", "cabinet still opens for gathered materials")
	for i in range(21):
		if items.ensure_bag("ali")[i].get("item", "") == "wood":
			items.slot_clicked("bag", i, true)
	check(items.ensure_container(storage_id)[0] == {"item": "wood", "count": 2}, "gathered wood can be stored")
	game.queue_free()
	await frames(2)
	await load_game()
	check(harvesting.trees["deadwood_01"].hits == 4 and not harvesting.trees["deadwood_01"].visible, "felled tree remains removed after restart")
	check(items.ensure_container(storage_id)[0]["count"] == 2 and wood_count("heya") == 99, "storage operations and restart preserve harvest state and wood")
	check(items.ensure_bag("ali")[4]["count"] == 17 and items.layouts["stone_house"].is_empty(), "legacy belongings and layout survive harvesting saves")
	var failing := FailingInventory.new()
	failing.resource_hits["test"] = 1
	var original: Array = failing.ensure_bag("ali").duplicate(true)
	var failed: Dictionary = failing.commit_resource_reward("ali", "test", 2, "wood", 1)
	check(not failed["ok"] and failing.resource_hits["test"] == 1 and failing.ensure_bag("ali") == original, "failed save rolls back both reward and resource progress")
	failing.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))
	if failures.is_empty():
		print("HARVESTING_SMOKE_OK: six reachable solid trees, axe requirement, real E input and cooldown, wood at hits 2/4, full-bag protection, 99 stack, current-character rewards, removal/collision/navigation, storage, legacy saves, restart and save-failure rollback")
		quit(0)
	else:
		print("HARVESTING_SMOKE_FAILED: ", failures)
		quit(1)
