# Checks deterministic biome generation, exclusion masks, bounded streaming and durable partial/exhausted resource state.
extends SceneTree

const Generator := preload("res://features/world_resources/generator.gd")
const PATH := "res://.runtime/seeded-world-smoke.json"
var failures: Array[String] = []
var game: Node
var world: Node2D
var resources: Node
var items: Node
var mining: Node
var harvesting: Node
var catalogue: Array = []
var partial_tree := ""
var depleted_tree := ""
var partial_ore := ""
var depleted_ore := ""
var original_at := Vector2.ZERO
var blocked_record: Dictionary = {}

func _initialize() -> void:
	OS.set_environment("AIU5_STATE_PATH", PATH)
	OS.set_environment("AIU5_PROFILE_PATH", "res://.runtime/seeded-world-names.cfg")
	OS.set_environment("AIU5_WORLD_PROFILE", "starter")
	OS.set_environment("AIU5_WORLD_SEED", "48151623")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH).get_base_dir())
	for suffix in ["", ".altar"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	create_timer(90, true).timeout.connect(func() -> void: push_error("WORLD_RESOURCES_TIMEOUT"); quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("CHECK FAILED: " + label)

func frames(count := 3) -> void:
	for i in range(count):
		await process_frame
		if is_instance_valid(resources): check(resources.built_last_frame <= 2, "generated resource creation respects frame count budget")

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func load_game() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	world = game.get_node("World")
	resources = game.get_node("WorldResources")
	items = game.get_node("Inventory")
	mining = game.get_node("Mining")
	harvesting = game.get_node("Harvesting")
	game.get_node("Simulation").set_process(false)
	game.get_node("Persistence").set_process(false)
	for actor in world.residents: actor.set_physics_process(false)
	for animal in game.get_node("Livestock").animals: animal.set_physics_process(false)
	await frames(35)

func move_to(at: Vector2) -> void:
	world.active_resident.position = at
	game.get_node("Streaming").focus(true)
	await frames(36)
	check(resources.descriptors.size() <= 25 and resources.loaded.size() <= 25 * Generator.MAX_PER_CHUNK, "distant chunks retain no unbounded resource node or descriptor cache")

func count(item: String) -> int:
	var result := 0
	for slot: Dictionary in items.ensure_bag("ali"):
		if slot.get("item", "") == item: result += int(slot.count)
	return result

func run() -> void:
	await load_game()
	check(world.resource_seed == 48151623, "new world uses its configured seed")
	var trees_dry := 0
	var trees_oasis := 0
	var stones_foothill := 0
	var stones_arid := 0
	var ids: Dictionary = {}
	for y in range(8):
		for x in range(8):
			var cell := Vector2i(x, y)
			var chunk: Array = resources.generator.chunk(cell)
			check(chunk.size() <= Generator.MAX_PER_CHUNK, "per-chunk quantity cap")
			check(chunk == resources.generator.chunk(cell), "same seed generates identical resource records")
			catalogue.append_array(chunk)
			for record: Dictionary in chunk:
				check(not ids.has(record.id), "stable resource IDs are unique")
				ids[record.id] = true
				check(resources.generator.allowed(record.at, record.kind), "resource avoids static buildings roads water spawn farm and facilities")
				if record.kind == "tree" and x in [3, 4]: trees_dry += 1
				if record.kind == "tree" and x in [0, 1]: trees_oasis += 1
				if record.kind == "stone" and x == 6: stones_foothill += 1
				if record.kind == "stone" and x == 4: stones_arid += 1
	check(trees_dry > trees_oasis and stones_foothill > stones_arid, "arid regions favor wood and foothills favor stone")
	var reverse: Array = []
	for y in range(7, -1, -1):
		for x in range(7, -1, -1): reverse.append_array(resources.generator.chunk(Vector2i(x, y)))
	var lookup: Dictionary = {}
	for record: Dictionary in reverse: lookup[record.id] = record
	for record: Dictionary in catalogue: check(lookup[record.id] == record, "chunk visiting order has no effect")
	var other := Generator.new()
	other.configure(48151624, resources.generator.blocked)
	check(other.chunk(Vector2i(3, 4)) != resources.generator.chunk(Vector2i(3, 4)), "different seeds change resource distribution")
	# Preload data two chunks away without creating resource nodes there.
	for record: Dictionary in resources.loaded.values(): check(world.terrain.distance(record.cell, resources.center) <= 1, "preload outer ring has data without full scene nodes")
	await move_to(Vector2(1120, 900))
	var trees: Array[String] = []
	var ores: Array[String] = []
	for id: String in resources.loaded:
		if resources.loaded[id].node.get_parent() == null: continue
		if id.contains(":tree:"): trees.append(id)
		else: ores.append(id)
	check(trees.size() >= 2 and ores.size() >= 2, "explored region supplies both resource types")
	if trees.size() < 2 or ores.size() < 2: quit(1); return
	partial_tree = trees[0]
	depleted_tree = trees[1]
	partial_ore = ores[0]
	depleted_ore = ores[1]
	original_at = harvesting.procedural[partial_tree].position
	check(game.get_node("Grounds").land_error(Rect2(original_at - Vector2(8, 8), Vector2(16, 16)), world.active_resident) != "", "generated resources block overlapping player construction")
	check(game.get_node("Persistence").save_checkpoint(), "pre-harvest checkpoint saved")
	items.exchange("ali", {}, {"stone_axe":1, "pickaxe":1}) # Prepared crafted gathering tools.
	check(game.get_node("Magic").equip_weapon("ali","stone_axe"),"equip axe before generated wood")
	var previous_wood := count("wood")
	world.active_resident.position = original_at + Vector2(0, 20)
	harvesting.cooldown = 0
	await key(KEY_E)
	harvesting.cooldown = 0
	await key(KEY_E)
	check(items.resource_hits.get(partial_tree) == 2 and count("wood") == previous_wood + 1, "real E chops generated tree and awards one wood on second hit")
	world.active_resident.position = harvesting.procedural[depleted_tree].position + Vector2(0, 20)
	for i in range(4):
		harvesting.cooldown = 0
		check(harvesting.chop(depleted_tree, world.active_resident), "generated tree supports complete harvesting")
	check(game.get_node("Magic").equip_weapon("ali","pickaxe"),"equip pickaxe before generated stone")
	world.active_resident.position = mining.procedural[partial_ore].position + Vector2(0, 20)
	mining.cooldown = 0
	await key(KEY_E)
	check(mining.progress.get(partial_ore) == 1, "real E partially mines generated stone")
	var previous_stone := count("stone")
	world.active_resident.position = mining.procedural[depleted_ore].position + Vector2(0, 20)
	for i in range(3):
		mining.cooldown = 0
		check(mining.strike(world.active_resident, mining.procedural[depleted_ore]), "generated stone supports complete mining")
	check(count("stone") == previous_stone + 3, "generated stone uses existing balanced reward")
	await move_to(Vector2(2080, 1400))
	check(not resources.loaded.has(partial_tree) and not resources.loaded.has(partial_ore), "far resource nodes are freed, not kept for the entire map")
	await move_to(Vector2(1120, 900))
	check(harvesting.procedural[partial_tree].hits == 2 and harvesting.procedural[partial_tree].position == original_at, "reload recreates same tree with partial hits")
	check(mining.procedural[partial_ore].hits == 1, "reload retains partial mining")
	check(not resources.loaded.has(depleted_tree) and not resources.loaded.has(depleted_ore), "depleted resources stay absent on chunk reload")
	check(not world.points.has("wood:" + depleted_tree) and not world.points.has("ore:" + depleted_ore), "depleted resources have no phantom interactions")
	# A legacy farm at a newly generated resource location is retained and its exclusion persists.
	var candidates: Array = resources.generator.chunk(Vector2i(1, 6))
	check(not candidates.is_empty(), "migration protection sample exists")
	blocked_record = candidates[0]
	game.get_node("Homestead").plots.append({"x": blocked_record.at.x - 8, "y": blocked_record.at.y - 8, "w": 16.0, "h": 16.0, "age": 0.0, "dry": true, "crop": "", "growth": 0.0})
	game.get_node("Homestead").refresh()
	await move_to(Vector2(480, 1300))
	check(resources.suppressed.has(blocked_record.id) and not resources.loaded.has(blocked_record.id), "existing player farmland prevents generated overlap")
	game.get_node("Homestead").plots.pop_back()
	game.get_node("Homestead").refresh()
	# Legacy depletion also must not alter deterministic candidate placement after restart.
	items.resource_hits.deadwood_01 = 4
	harvesting.restore()
	check(game.get_node("Persistence").save_now(), "seed, exclusions and remote depletion saved")
	var before: Dictionary = items.export_data()
	game.queue_free()
	await frames(4)
	OS.set_environment("AIU5_WORLD_SEED", "999")
	await load_game()
	check(world.resource_seed == 48151623, "saved seed overrides later startup defaults")
	var regenerated: Array = []
	for y in range(8):
		for x in range(8): regenerated.append_array(resources.generator.chunk(Vector2i(x, y)))
	check(regenerated == catalogue, "legacy chopping and restart do not shift generated locations or IDs")
	check(resources.suppressed.has(blocked_record.id), "migration exclusion survives save and restart")
	check(mining.progress.get(depleted_ore) == 3 and items.resource_hits.get(depleted_tree) == 4, "unloaded exhausted records survive restart")
	await move_to(Vector2(1120, 900))
	check(harvesting.procedural[partial_tree].hits == 2 and mining.procedural[partial_ore].hits == 1, "restart restores partially harvested nodes")
	check(not resources.loaded.has(depleted_tree) and not resources.loaded.has(depleted_ore), "restart cannot respawn exhausted resources")
	world.active_resident.position = original_at + Vector2(0, 20)
	check(game.get_node("Persistence").save_now(), "save while standing beside a partially chopped tree")
	game.queue_free()
	await frames(4)
	await load_game()
	check(world.active_resident.position == original_at + Vector2(0, 20) and harvesting.procedural.has(partial_tree), "resuming beside a resource restores it without requiring the player to walk away")
	# Old altar checkpoints have no generator field; the save's seed must remain stable.
	game.get_node("Persistence").checkpoint.session.erase("resource_world")
	check(game.get_node("Persistence").restore_checkpoint(), "old-style altar snapshot remains compatible")
	await move_to(Vector2(1120, 900))
	check(world.resource_seed == 48151623 and resources.loaded.has(depleted_tree) and resources.loaded.has(depleted_ore), "intentional altar rollback restores harvest state without changing seed")
	check(harvesting.procedural[partial_tree].hits == 0 and mining.procedural[partial_ore].hits == 0, "checkpoint restores pre-harvest progress")
	await key(KEY_M)
	var pending: Array = [resources.prepare_queue.duplicate(), resources.spawn_queue.duplicate(), resources.loaded.keys()]
	await create_timer(0.15, true).timeout
	check(paused and pending == [resources.prepare_queue, resources.spawn_queue, resources.loaded.keys()], "full map pauses resource generation as well as gameplay")
	await key(KEY_ESCAPE)
	game.queue_free()
	await frames(4)
	if failures.is_empty(): print("WORLD_RESOURCES_SMOKE_OK resources=", catalogue.size(), " arid_trees=", trees_dry, " oasis_trees=", trees_oasis, " foothill_stones=", stones_foothill, " arid_stones=", stones_arid)
	else: print("WORLD_RESOURCES_SMOKE_FAILED ", failures)
	quit(0 if failures.is_empty() else 1)
