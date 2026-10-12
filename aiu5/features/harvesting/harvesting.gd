# Owns woodcutting rules and connects persistent resource progress with outdoor tree visuals.
extends Node

signal message(text: String)
const Gear := preload("res://features/combat/weapon_catalog.gd")
var equipment: Node
const DeadTree := preload("res://features/harvesting/dead_tree.gd")
const TREES := [
	{"id": "deadwood_01", "at": Vector2(366, 152)},
	{"id": "deadwood_02", "at": Vector2(145, 355)},
	{"id": "deadwood_03", "at": Vector2(355, 405)},
	{"id": "deadwood_04", "at": Vector2(506, 115)},
	{"id": "deadwood_05", "at": Vector2(875, 285)},
	{"id": "deadwood_06", "at": Vector2(747, 488)}
]
var world: Node2D
var inventory: Node
var trees: Dictionary = {}
var procedural: Dictionary = {}
var cooldown := 0.0

func start(village: Node2D, belongings: Node) -> void:
	world = village
	inventory = belongings
	for i in range(TREES.size()):
		var data: Dictionary = TREES[i]
		var tree := DeadTree.new()
		tree.resource_id = data["id"]
		tree.name = data["id"]
		tree.position = data["at"]
		tree.variant = i % 3
		tree.hits = inventory.resource_hits.get(tree.resource_id, 0)
		world.objects.add_child(tree)
		trees[tree.resource_id] = tree
		_update_point(tree)
	world.refresh_obstacles()

func add_procedural(record: Dictionary) -> Node2D:
	var tree := DeadTree.new()
	tree.resource_id = record.id
	tree.name = str(record.id).replace(":", "_")
	tree.position = record.at
	tree.variant = record.variant
	tree.hits = int(inventory.resource_hits.get(record.id, 0))
	world.objects.add_child(tree)
	procedural[record.id] = tree
	_update_point(tree)
	return tree

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)

func _update_point(tree: Node2D) -> void:
	var key: String = "wood:" + tree.resource_id
	if tree.hits >= 4:
		world.points.erase(key)
	else:
		world.points[key] = {"position": tree.position, "radius": 25.0, "label": "枯木", "action": "装备斧砍伐 %d/4" % tree.hits}

func chop(id: String, actor: CharacterBody2D) -> bool:
	if actor.dead: return false
	if (not trees.has(id) and not procedural.has(id)) or actor.room_id != "" or cooldown > 0:
		return false
	var tree: Node2D = trees.get(id, procedural.get(id))
	if tree.hits >= 4 or actor.global_position.distance_to(tree.global_position) >= 25:
		return false
	if not is_instance_valid(equipment) or equipment.ensure(actor.resident_id).equipment.weapon not in Gear.AXES:
		message.emit("请先装备石斧或铁斧，再砍树。")
		return false
	if not equipment.weapon_usable(actor.resident_id): return false
	var before: Dictionary = inventory.export_data()
	var next_hit: int = tree.hits + 1
	var reward := 1 if next_hit % 2 == 0 else 0
	if reward > 0 and not inventory.exchange(actor.resident_id,{}, {"wood":reward}):
		message.emit("背包装不下木头，先腾出空间再继续砍。")
		return false
	inventory.resource_hits[id] = next_hit
	equipment.consume_weapon(actor.resident_id)
	if not equipment.session.production.commit(before,"砍伐枯木。"):
		return false
	cooldown = 0.35
	tree.apply_hit(next_hit, actor.global_position)
	_update_point(tree)
	if next_hit == 4:
		world.refresh_obstacles()
		message.emit("枯木已砍完，获得木头 ×1；这棵枯木共采得 2 个木头。")
	elif reward == 1:
		message.emit("获得木头 ×1，已放入背包（砍伐 2/4）。")
	else:
		message.emit("砍伐枯木 %d/4，再砍 1 次可获得木头。" % next_hit)
	return true

func restore() -> void:
	cooldown = 0
	for tree: Node2D in trees.values() + procedural.values():
		var id: String = tree.resource_id
		tree.hits = int(inventory.resource_hits.get(id, 0))
		tree.hit_time = 0.0
		tree.visible = tree.hits < 4
		tree.body.collision_layer = 1 if tree.hits < 4 else 0
		tree.queue_redraw()
		_update_point(tree)
	world.refresh_obstacles()
