# Verifies a real window-close notification preserves a seeded world's unloaded resource deltas across processes.
extends SceneTree

const PATH := "res://.runtime/resource-quit.json"
const POINTER := "res://.runtime/resource-quit-pointer.json"
var game: Node
var world: Node2D
var resources: Node
var verify := false

func _initialize() -> void:
	verify = "verify" in OS.get_cmdline_user_args()
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/resource-quit-names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE", "starter")
	OS.set_environment("AIU5_WORLD_SEED", "999" if verify else "48151623")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH).get_base_dir())
	if not verify:
		for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(30, true).timeout.connect(func() -> void: push_error("RESOURCE_QUIT_TIMEOUT"); quit(2))
	call_deferred("run")

func frames(count := 35) -> void:
	for i in range(count): await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	resources = game.get_node("WorldResources")
	game.get_node("Simulation").set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for animal in game.get_node("Livestock").animals: animal.set_physics_process(false)
	var items: Node = game.get_node("Inventory")
	var harvesting: Node = game.get_node("Harvesting")
	var mining: Node = game.get_node("Mining")
	if verify:
		var pointer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POINTER))
		var good: bool = world.resource_seed == 48151623 and world.active_resident.position == Vector2(2080, 1400)
		good = good and items.resource_hits.get(pointer.tree) == 2 and mining.progress.get(pointer.stone) == 3
		world.active_resident.position = Vector2(1120, 900)
		game.get_node("Streaming").focus(true)
		await frames()
		good = good and resources.loaded.has(pointer.tree) and harvesting.procedural[pointer.tree].hits == 2
		good = good and not resources.loaded.has(pointer.stone) and not world.points.has("ore:" + str(pointer.stone))
		if good: print("RESOURCE_QUIT_RELOAD_OK")
		else: push_error("RESOURCE_QUIT_RELOAD_FAILED")
		quit(0 if good else 1)
		return
	world.active_resident.position = Vector2(1120, 900)
	game.get_node("Streaming").focus(true)
	await frames()
	var tree := ""
	var stone := ""
	for id: String in resources.loaded:
		if resources.loaded[id].node.get_parent() == null: continue
		if tree == "" and id.contains(":tree:"): tree = id
		if stone == "" and id.contains(":stone:"): stone = id
	if tree == "" or stone == "": push_error("RESOURCE_QUIT_FIXTURE_MISSING"); quit(1); return
	game.get_node("Inventory").exchange("ali", {}, {"stone_axe":1, "pickaxe":1}) # Prepared crafted tools.
	game.get_node("Magic").equip_weapon("ali","stone_axe")
	world.active_resident.position = harvesting.procedural[tree].position + Vector2(0, 20)
	for i in range(2):
		harvesting.cooldown = 0
		if not harvesting.chop(tree, world.active_resident): push_error("RESOURCE_QUIT_CHOP_FAILED"); quit(1); return
	game.get_node("Magic").equip_weapon("ali","pickaxe")
	world.active_resident.position = mining.procedural[stone].position + Vector2(0, 20)
	for i in range(3):
		mining.cooldown = 0
		if not mining.strike(world.active_resident, mining.procedural[stone]): push_error("RESOURCE_QUIT_MINE_FAILED"); quit(1); return
	world.active_resident.position = Vector2(2080, 1400)
	game.get_node("Streaming").focus(true)
	await frames()
	var file := FileAccess.open(POINTER, FileAccess.WRITE)
	file.store_string(JSON.stringify({"tree": tree, "stone": stone}))
	file.close()
	game.get_node("Session").overview = true
	world.set_overview(true)
	game.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	print("RESOURCE_QUIT_NOTIFICATION_SAVED_OK")
