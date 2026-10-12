# Owns finite surface/underground deposits with equipped pickaxes.
extends Node

signal message(text: String)
const Gear := preload("res://features/combat/weapon_catalog.gd")
var equipment: Node
const Ore := preload("res://features/mining/ore.gd")
const Entrance := preload("res://features/mining/entrance.gd")
const Underground := preload("res://features/mining/underground.gd")
const DOOR := Vector2(2070, 450)
const SURFACE := [
	{"id": "surface:1", "at": Vector2(500, 430), "kind": "stone"},
	{"id": "surface:2", "at": Vector2(912, 315), "kind": "stone"},
	{"id": "surface:3", "at": Vector2(1050, 580), "kind": "stone"},
	{"id": "surface:4", "at": Vector2(1180, 310), "kind": "stone"},
	{"id": "surface:5", "at": Vector2(1480, 810), "kind": "stone"},
	{"id": "surface:6", "at": Vector2(1650, 1200), "kind": "stone"},
	{"id": "surface:7", "at": Vector2(480, 1080), "kind": "stone"},
	{"id": "surface:8", "at": Vector2(820, 1340), "kind": "stone"},
	{"id": "surface:9", "at": Vector2(1850, 630), "kind": "stone"},
	{"id": "surface:10", "at": Vector2(1930, 1070), "kind": "stone"}
]
const UNDERGROUND := [
	{"id": "mine:1", "at": Vector2(44, 62), "kind": "stone"},
	{"id": "mine:2", "at": Vector2(88, 77), "kind": "stone"},
	{"id": "mine:3", "at": Vector2(44, 119), "kind": "stone"},
	{"id": "mine:4", "at": Vector2(96, 134), "kind": "stone"},
	{"id": "mine:5", "at": Vector2(132, 55), "kind": "stone"},
	{"id": "mine:6", "at": Vector2(132, 108), "kind": "stone"},
	{"id": "mine:7", "at": Vector2(212, 55), "kind": "iron_ore"},
	{"id": "mine:8", "at": Vector2(256, 77), "kind": "iron_ore"},
	{"id": "mine:9", "at": Vector2(204, 112), "kind": "iron_ore"},
	{"id": "mine:10", "at": Vector2(254, 134), "kind": "iron_ore"},
	{"id": "mine:11", "at": Vector2(174, 70), "kind": "iron_ore"},
	{"id": "mine:12", "at": Vector2(174, 130), "kind": "iron_ore"},
	{"id":"mine:13","at":Vector2(350,50),"kind":"iron_ore"},
	{"id":"mine:14","at":Vector2(394,50),"kind":"iron_ore"},
	{"id":"mine:15","at":Vector2(438,50),"kind":"iron_ore"},
	{"id":"mine:16","at":Vector2(482,50),"kind":"iron_ore"},
	{"id":"mine:17","at":Vector2(526,50),"kind":"iron_ore"},
	{"id":"mine:18","at":Vector2(570,50),"kind":"iron_ore"},
	{"id":"mine:19","at":Vector2(350,90),"kind":"iron_ore"},
	{"id":"mine:20","at":Vector2(394,90),"kind":"iron_ore"},
	{"id":"mine:21","at":Vector2(438,90),"kind":"iron_ore"},
	{"id":"mine:22","at":Vector2(482,90),"kind":"iron_ore"},
	{"id":"mine:23","at":Vector2(526,90),"kind":"iron_ore"},
	{"id":"mine:24","at":Vector2(570,90),"kind":"iron_ore"},
	{"id":"mine:25","at":Vector2(350,130),"kind":"iron_ore"},
	{"id":"mine:26","at":Vector2(394,130),"kind":"iron_ore"},
	{"id":"mine:27","at":Vector2(438,130),"kind":"iron_ore"},
	{"id":"mine:28","at":Vector2(482,130),"kind":"iron_ore"},
	{"id":"mine:29","at":Vector2(526,130),"kind":"iron_ore"},
	{"id":"mine:30","at":Vector2(570,130),"kind":"iron_ore"},
	{"id":"mine:31","at":Vector2(350,170),"kind":"iron_ore"},
	{"id":"mine:32","at":Vector2(394,170),"kind":"iron_ore"},
	{"id":"mine:33","at":Vector2(438,170),"kind":"iron_ore"},
	{"id":"mine:34","at":Vector2(482,170),"kind":"iron_ore"},
	{"id":"mine:35","at":Vector2(526,170),"kind":"iron_ore"},
	{"id":"mine:36","at":Vector2(570,170),"kind":"iron_ore"},
	{"id":"mine:37","at":Vector2(350,210),"kind":"iron_ore"},
	{"id":"mine:38","at":Vector2(394,210),"kind":"iron_ore"},
	{"id":"mine:39","at":Vector2(438,210),"kind":"iron_ore"},
	{"id":"mine:40","at":Vector2(482,210),"kind":"iron_ore"},
	{"id":"mine:41","at":Vector2(526,210),"kind":"iron_ore"},
	{"id":"mine:42","at":Vector2(570,210),"kind":"iron_ore"}
]
var world: Node2D
var interiors: Node2D
var inventory: Node
var surface: Dictionary = {}
var procedural: Dictionary = {}
var progress: Dictionary = {}
var cooldown := 0.0

func start(village: Node2D, rooms: Node2D, items: Node) -> void:
	world = village
	interiors = rooms
	inventory = items
	world.extra_homes.mine = {"id": "mine", "name": "地下矿洞", "door": DOOR, "description": "石矿与铁矿分布的地下洞穴。"}
	interiors.special_rooms.mine = _make_room
	var entrance := Entrance.new()
	entrance.position = DOOR - Vector2(0, 18)
	world.objects.add_child(entrance)
	for x in [-27, 27]: world._body(entrance, Vector2(x, -5), Vector2(16, 25))
	world._body(entrance, Vector2(0, -27), Vector2(60, 8))
	world.points.mine = {"position": DOOR, "radius": 25.0, "label": "东山矿洞", "action": "进入地下", "description": "带镐子下矿，可采石头与铁矿。"}
	world._label("东山矿洞", DOOR + Vector2(-27, -55))
	for record: Dictionary in SURFACE:
		var ore := create_ore(record)
		world.objects.add_child(ore)
		surface[record.id] = ore
		_update_point(ore)
	world.refresh_obstacles()

func add_procedural(record: Dictionary) -> Node2D:
	var ore := create_ore(record)
	ore.name = str(record.id).replace(":", "_")
	world.objects.add_child(ore)
	procedural[record.id] = ore
	_update_point(ore)
	return ore

func _make_room() -> Node2D:
	var room := Underground.new()
	room.mining = self
	room.configure(world.extra_homes.mine, {"size": Vector2(624,264), "floor": Color("66634f"), "furniture": [], "mats": []}, [])
	return room

func create_ore(record: Dictionary) -> Node2D:
	var ore := Ore.new()
	ore.resource_id = record.id
	ore.kind = record.kind
	ore.strikes = 4 if record.kind == "iron_ore" else 3
	ore.hits = clampi(int(progress.get(record.id, 0)), 0, ore.strikes)
	ore.position = record.at
	return ore

func _process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)

func _update_point(ore: Node2D) -> void:
	var key: String = "ore:" + ore.resource_id
	if ore.hits >= ore.strikes: world.points.erase(key)
	else: world.points[key] = {"position": ore.position, "radius": 26.0, "label": "地表石矿", "action": "镐子采集 %d/%d" % [ore.hits, ore.strikes], "description": "采尽获得石头×3"}

func mine_near(actor: CharacterBody2D) -> bool:
	if actor.dead: return false
	var ore: Node2D
	if actor.room_id == "mine":
		ore = interiors.context(actor).get("ore")
	elif actor.room_id == "":
		var id: String = world.nearest_point(actor.position).trim_prefix("ore:")
		ore = surface.get(id, procedural.get(id))
	if not is_instance_valid(ore):
		message.emit("靠近地表石矿或地下矿脉，按E使用镐子采集。")
		return false
	return strike(actor, ore)

func strike(actor: CharacterBody2D, ore: Node2D) -> bool:
	if actor.dead or cooldown > 0 or not is_instance_valid(ore) or ore.hits >= ore.strikes: return false
	if actor.global_position.distance_to(ore.global_position) >= 26: return false
	if not is_instance_valid(equipment) or equipment.ensure(actor.resident_id).equipment.weapon not in Gear.PICKS:
		message.emit("请先装备镐子；工作台配方为木头×1＋石头×2。")
		return false
	if not equipment.weapon_usable(actor.resident_id): return false
	var before: Dictionary = inventory.export_data()
	var next_hit: int = ore.hits + 1
	var reward := 2 if ore.kind == "iron_ore" else 3
	if next_hit == ore.strikes and not inventory.exchange(actor.resident_id, {}, {ore.kind: reward}):
		message.emit("背包已满，矿脉保留，腾出空间再采最后一下。")
		return false
	equipment.consume_weapon(actor.resident_id)
	ore.hits = next_hit
	progress[ore.resource_id] = next_hit
	ore.flash = 0.18
	ore.refresh()
	if not equipment.session.production.commit(before,"采矿 %d/%d。" % [next_hit,ore.strikes]): return false
	cooldown = 0.35
	if surface.has(ore.resource_id) or procedural.has(ore.resource_id):
		_update_point(ore)
		if not ore.visible: world.refresh_obstacles()
	message.emit("获得" + str(inventory.Catalog.ITEMS[ore.kind].name) + "×" + str(reward) if next_hit == ore.strikes else "采集 %d/%d" % [next_hit, ore.strikes])
	return true

func export_state() -> Dictionary:
	return {"progress": progress.duplicate()}

func restore(data: Dictionary) -> void:
	progress.clear()
	# Keep generated IDs even when their chunks are not loaded.
	for id: String in data.get("progress", {}):
		if id.begins_with("gen1:") and id.contains(":stone:"):
			progress[id] = clampi(int(data.progress[id]), 0, 3)
	for record: Dictionary in SURFACE + UNDERGROUND:
		progress[record.id] = clampi(int(data.get("progress", {}).get(record.id, 0)), 0, 4 if record.kind == "iron_ore" else 3)
	cooldown = 0
	for ore: Node2D in surface.values() + procedural.values():
		ore.hits = progress.get(ore.resource_id, 0)
		ore.refresh()
		_update_point(ore)
	world.refresh_obstacles()
