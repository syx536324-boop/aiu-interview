# Owns persistent constructed buildings, conversion, interiors, armor and safe collapse into searchable ruins.
extends Node
signal message(text: String)
const Catalog := preload("res://features/construction/catalog.gd")
const Building := preload("res://features/construction/building.gd")
const Room := preload("res://features/interiors/room.gd")
const Roof := preload("res://features/construction/roof.gd")
var session: Node
var records: Dictionary = {}
var nodes: Dictionary = {}
var next_id := 0
func start(controller: Node) -> void:
	session = controller
func build(actor: CharacterBody2D, bench: Node2D, kind: String) -> bool:
	if not Catalog.BUILDINGS.has(kind) or not session.production.allowed(actor): return false
	if actor.room_id != "" or not session.grounds.fixtures.has(bench) or bench.kind != "building_bench": return false
	if actor.position.distance_to(bench.position) > 36: return false
	var at: Vector2 = bench.visual_bounds().position
	var definition: Dictionary = Catalog.BUILDINGS[kind]
	var before: Dictionary = session.inventory.export_data()
	var rewards := {"iron_bucket": 5} if kind == "iron_house" else {}
	if not session.inventory.exchange(actor.resident_id, definition.cost, rewards):
		message.emit("材料不足或背包无法收回5个铁桶；材料未扣除。")
		return false
	var id := "built:" + str(next_id)
	next_id += 1
	records[id] = {"id": id, "kind": kind, "at": [at.x, at.y], "hp": definition.hp, "max_hp": definition.hp, "defense": definition.defense}
	session.grounds.remove_fixture(bench)
	_attach(id)
	session.world.refresh_obstacles()
	return session.production.commit(before, "建成%s，建筑台已消耗。" % definition.name)
func _attach(id: String) -> void:
	var record: Dictionary = records[id]
	var at := Vector2(record.at[0], record.at[1])
	var definition: Dictionary = Catalog.BUILDINGS[record.kind]
	var ruined := float(record.hp) <= 0
	var name := str(definition.name) + ("废墟" if ruined else "")
	var home := {"id": id, "name": name, "at": at, "region": Rect2(Vector2.ZERO, Catalog.FOOTPRINT), "door": at + Vector2(48, 91),
		"description": "%s · 生命 %.1f/%.0f · 防御%d（减伤%d%%）" % [name, record.hp, record.max_hp, record.defense, record.defense], "built": true, "tower": record.kind == "arrow_tower" and not ruined, "ruined": ruined}
	session.world.homes.append(home)
	session.world.points[id] = {"position": home.door, "radius": 25.0, "label": name, "action": "搜寻废墟" if ruined else ("登上顶部" if home.tower else "进屋"), "description": home.description}
	session.interiors.special_rooms[id] = _make_room.bind(id)
	var node := Building.new()
	node.record = record
	node.position = at + Vector2(48, 79)
	node.name = id.replace(":", "_")
	session.world.objects.add_child(node)
	if not ruined: session.world._body(node, Vector2(0,-38), Vector2(90,72))
	nodes[id] = node
	session.world.houses.append(node)
func _make_room(id: String) -> Node2D:
	var home: Dictionary = session.world.home_data(id)
	var tower: bool = home.tower
	var room: Node2D = Roof.new() if tower else Room.new()
	var saved: Array = session.interiors.layout_overrides.get(id, [{"missing": true}])
	room.configure(home, {"size": Vector2(96,80) if tower else Vector2(208,144), "floor": Color("ba9362") if not home.ruined else Color("8d806a"),
		"mats": [] if tower else [Rect2(18,94,38,20)],
		"furniture": [] if tower else [["bed",Vector2(18,34),Vector2(32,48),0],["chest",Vector2(155,39),Vector2(28,20),1],["table",Vector2(87,42),Vector2(48,24),2],["chair",Vector2(102,78),Vector2(14,18),0]]}, saved)
	if tower:
		room.set_meta("outdoor_roof", true)
		room.z_index = 20
	return room
func hit(id: String, raw: float, consume_tool := false) -> bool:
	if not records.has(id) or records[id].hp <= 0 or raw <= 0 or session.overview or session.menu_paused: return false
	var before: Dictionary = session.inventory.export_data()
	if consume_tool and not session.magic.consume_weapon(session.world.active_resident.resident_id): return false
	var record: Dictionary = records[id]
	record.hp = maxf(0, float(record.hp) - Catalog.damage(raw, int(record.defense)))
	if record.hp <= 0:
		var home: Dictionary = session.world.home_data(id)
		for actor in session.world.residents:
			if actor.room_id == id: session.interiors.leave(actor, session.world.objects, home.door + Vector2(0,16))
		_remove_home(id)
		_attach(id)
		session._sync_view()
	else:
		nodes[id].queue_redraw()
		var home: Dictionary = session.world.home_data(id)
		home.description = "%s · 生命 %.1f/%.0f · 防御%d（减伤%d%%）" % [home.name,record.hp,record.max_hp,record.defense,record.defense]
		session.world.points[id].description = home.description
	session.world.refresh_obstacles()
	return session.production.commit(before, "建筑生命 %.1f/%.0f%s" % [record.hp,record.max_hp," · 已倒塌，人物撤出，可搜寻废墟取回物品。" if record.hp <= 0 else ""])
func _remove_home(id: String) -> void:
	session.world.points.erase(id)
	session.world.homes = session.world.homes.filter(func(h: Dictionary) -> bool: return h.id != id)
	session.interiors.special_rooms.erase(id)
	var node: Variant = nodes.get(id)
	if is_instance_valid(node):
		session.world.houses.erase(node)
		if node.get_parent() != null: node.get_parent().remove_child(node)
		node.free()
	nodes.erase(id)
func demolish(actor: CharacterBody2D) -> bool:
	if not session.production.allowed(actor) or actor.room_id != "": return false
	var weapon: String = session.magic.ensure(actor.resident_id).equipment.weapon
	if weapon not in session.magic.Catalog.Gear.AXES:
		message.emit("拆毁自建建筑需要装备石斧或铁斧，靠近门口按 X。")
		return false
	var id: String = session.world.nearest_point(actor.position)
	return hit(id,session.magic.Catalog.Gear.damage(weapon),true) if records.has(id) else false
func export_state() -> Dictionary:
	return {"next_id": next_id, "records": records.duplicate(true)}
func restore(data: Dictionary) -> void:
	for id: String in nodes.keys(): _remove_home(id)
	records.clear()
	next_id = maxi(0,int(data.get("next_id",0)))
	for id: String in data.get("records",{}):
		var source: Dictionary = data.records[id]
		if not id.begins_with("built:") or not Catalog.BUILDINGS.has(source.get("kind","")): continue
		var definition: Dictionary = Catalog.BUILDINGS[source.kind]
		records[id] = {"id":id,"kind":source.kind,"at":source.at,"hp":clampf(float(source.hp),0,definition.hp),"max_hp":definition.hp,"defense":definition.defense}
		next_id = maxi(next_id,int(id.trim_prefix("built:"))+1)
		_attach(id)
	session.world.refresh_obstacles()
