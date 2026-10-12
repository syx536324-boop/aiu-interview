# Streams seeded resources near the player while keeping depletion and migration exclusions as persistent data.
extends Node

const Generator := preload("res://features/world_resources/generator.gd")
const Land := preload("res://features/homestead/land.gd")
var generator := Generator.new()
var world: Node2D
var inventory: Node
var harvesting: Node
var mining: Node
var farming: Node
var grounds: Node2D
var descriptors: Dictionary = {}
var loaded: Dictionary = {}
var suppressed: Dictionary = {}
var prepare_queue: Array[Vector2i] = []
var spawn_queue: Array[Dictionary] = []
var center := Vector2i(-100, -100)
var inside := false
var built_last_frame := 0

func start(village: Node2D, items: Node, woodcutting: Node, digging: Node, crops: Node, outdoor: Node2D) -> void:
	world = village
	inventory = items
	harvesting = woodcutting
	mining = digging
	farming = crops
	grounds = outdoor
	# Capture immutable colliders before player-deployed furniture is restored.
	generator.configure(world.resource_seed, world.logical_obstacles(false))

func export_state() -> Dictionary:
	return {"seed": world.resource_seed, "version": Generator.VERSION, "suppressed": suppressed.keys()}

func restore(data: Dictionary) -> void:
	for id: String in loaded.keys(): _release(id)
	descriptors.clear()
	prepare_queue.clear()
	spawn_queue.clear()
	suppressed.clear()
	for id in data.get("suppressed", []):
		if id is String and id.begins_with("gen1:"): suppressed[id] = true
	# Old altar snapshots lack a seed; retain this save's original world seed.
	world.resource_seed = maxi(1, int(data.get("seed", world.resource_seed)))
	generator.seed = world.resource_seed
	center = Vector2i(-100, -100)
	world.refresh_obstacles()

func focus(at: Vector2, indoors: bool) -> void:
	var next: Vector2i = world.terrain.cell(at)
	if next == center and indoors == inside: return
	center = next
	inside = indoors
	prepare_queue.clear()
	spawn_queue.clear()
	var changed := false
	for id: String in loaded.keys():
		var record: Dictionary = loaded[id]
		var gap: int = world.terrain.distance(record.cell, center)
		if gap > 2:
			_release(id)
			changed = true
		else:
			var node: Node2D = record.node
			if not inside and gap <= 1 and node.get_parent() == null: world.objects.add_child(node)
			elif (inside or gap > 1) and node.get_parent() == world.objects: world.objects.remove_child(node)
	for cell: Vector2i in descriptors.keys():
		if world.terrain.distance(cell, center) > 2: descriptors.erase(cell)
	if not inside:
		for y in range(maxi(0, center.y - 2), mini(8, center.y + 3)):
			for x in range(maxi(-8, center.x - 2), mini(8, center.x + 3)):
				var cell := Vector2i(x, y)
				if not descriptors.has(cell): prepare_queue.append(cell)
				elif world.terrain.distance(cell, center) <= 1: _enqueue(cell)
		prepare_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_squared_to(Vector2(center)) < Vector2(b).distance_squared_to(Vector2(center)))
	if changed: world.refresh_obstacles()

func _enqueue(cell: Vector2i) -> void:
	for record: Dictionary in descriptors[cell]:
		if not loaded.has(record.id) and not suppressed.has(record.id) and not _depleted(record):
			spawn_queue.append(record)

func _depleted(record: Dictionary) -> bool:
	return int(inventory.resource_hits.get(record.id, 0)) >= 4 if record.kind == "tree" else int(mining.progress.get(record.id, 0)) >= 3

func _occupied(record: Dictionary) -> bool:
	var footprint := Rect2(record.at - Vector2(28, 54 if record.kind == "tree" else 24), Vector2(56, 62 if record.kind == "tree" else 32))
	for plot: Dictionary in farming.plots:
		if footprint.intersects(Land.bounds(plot).grow(4)): return true
	for home: Dictionary in world.homes:
		if home.get("built",false) and footprint.intersects(Rect2(home.at,home.region.size).grow(8)): return true
	for fixture in grounds.fixtures:
		if footprint.intersects(fixture.visual_bounds().grow(4)): return true
	return false

func _actor_near(record: Dictionary) -> bool:
	# Check feet against the actual trunk/rock, so resuming beside a resource does not hide it.
	var size := Vector2(12, 9) if record.kind == "tree" else Vector2(20, 10)
	var bounds := Rect2(record.at - Vector2(size.x / 2, size.y), size)
	for actor in world.residents:
		if actor.room_id == "" and not actor.dead and bounds.grow(6).has_point(actor.position + Vector2(0, -3)): return true
	for animal in world.pigs + world.cows:
		if bounds.grow(8).has_point(animal.position + Vector2(0, -3)): return true
	return false

func _spawn(record: Dictionary) -> void:
	var node: Node2D
	if record.kind == "tree": node = harvesting.add_procedural(record)
	else: node = mining.add_procedural(record)
	node.set_meta("procedural_resource", true)
	loaded[record.id] = {"node": node, "cell": world.terrain.cell(record.at)}

func _release(id: String) -> void:
	var node: Node2D = loaded[id].node
	if is_instance_valid(node):
		world.obstacle_bodies.erase(node.body.get_instance_id())
		if harvesting.procedural.has(id): harvesting.procedural.erase(id)
		if mining.procedural.has(id): mining.procedural.erase(id)
		world.points.erase(("wood:" if id.contains(":tree:") else "ore:") + id)
		node.free()
	loaded.erase(id)

func _process(_delta: float) -> void:
	built_last_frame = 0
	if not is_instance_valid(world) or inside: return
	var started := Time.get_ticks_usec()
	if not prepare_queue.is_empty():
		var cell: Vector2i = prepare_queue.pop_front()
		descriptors[cell] = generator.chunk(cell)
		if world.terrain.distance(cell, center) <= 1: _enqueue(cell)
	var attempts := mini(8, spawn_queue.size())
	while attempts > 0 and not spawn_queue.is_empty() and built_last_frame < 2:
		attempts -= 1
		var record: Dictionary = spawn_queue.pop_front()
		if loaded.has(record.id) or suppressed.has(record.id) or _depleted(record): continue
		if _occupied(record):
			suppressed[record.id] = true
			continue
		if _actor_near(record):
			spawn_queue.append(record)
			continue
		_spawn(record)
		built_last_frame += 1
		if Time.get_ticks_usec() - started >= 2000: break
	if built_last_frame > 0: world.refresh_obstacles()

func _exit_tree() -> void:
	# Own detached resource nodes; SceneTree alone cannot free parked objects.
	for record: Dictionary in loaded.values():
		var node: Node2D = record.node
		if is_instance_valid(node) and node.get_parent() == null: node.free()
