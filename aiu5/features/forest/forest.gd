# Streams seeded western woodland and persists herb depletion plus online mulberry regrowth.
extends Node
signal message(text: String)
const Silk := preload("res://features/forest/silk_catalog.gd")
var mulberry_harvests: Dictionary={}
const Seeds := preload("res://features/forest/seed_patches.gd")
const Catalog := preload("res://features/forest/catalog.gd")
const Plant := preload("res://features/forest/plant.gd")
const Layout := preload("res://features/village/layout.gd")
const Land := preload("res://features/homestead/land.gd")
const CHUNK := Vector2(320, 200)
var session: Node
var online := 0.0
var collected: Dictionary = {}
var seed_patches: Dictionary = {}
var excluded: Dictionary = {}
var loaded: Dictionary = {}
var descriptors: Dictionary = {}
var queue: Array[Dictionary] = []
var prepare_queue: Array[Vector2i] = []
var center := Vector2i(-100, -100)
var inside := false
var refresh_left := 0.0
var chop_cooldown := 0.0
var built_last_frame := 0
func start(controller: Node) -> void:
	session = controller
func generate(cell: Vector2i) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if cell.x < -8 or cell.x >= 0 or cell.y < -8 or cell.y >= 8: return records
	var rng := RandomNumberGenerator.new()
	rng.seed = session.world.resource_seed ^ ((cell.x + 17) * 73856093) ^ ((cell.y + 1) * 19349663)
	for i in range(19):
		var at := Vector2(cell) * CHUNK + Vector2(36 + (i % 5) * 60 + rng.randi_range(-6,6), 40 + (i / 5) * 60 + rng.randi_range(-5,5))
		if i>=15: at=Vector2(cell)*CHUNK+Vector2(40+(i-15)*70,184)
		var kind: String = "grass" if i>=15 else (["ginseng", "reishi", "goji", "mulberry"][i] if i < 4 else "tree")
		var bounds := Rect2(at - Vector2(26,54),Vector2(52,60))
		if not (Layout.FOREST.grow(-18).encloses(bounds) or Layout.FOREST_NORTH.grow(-18).encloses(bounds)): continue
		if bounds.intersects(Rect2(-280,220,104,112)) or bounds.intersects(Layout.FOREST_VILLAGE): continue
		var on_path := false
		for route: Array in Layout.ROADS:
			for j in range(route.size()-1):
				if at.distance_to(Geometry2D.get_closest_point_to_segment(at,route[j],route[j+1])) < 38: on_path = true
		if on_path: continue
		records.append({"id":"forest1:%d:%d:%d" % [cell.x,cell.y,i],"kind":kind,"at":at,"cell":cell})
	return records
func focus(at: Vector2, indoors: bool) -> void:
	var next: Vector2i = session.world.terrain.cell(at)
	if center == next and inside == indoors: return
	center = next
	inside = indoors
	queue.clear()
	prepare_queue.clear()
	var changed := false
	for id: String in loaded.keys():
		var record: Dictionary = loaded[id].record
		if inside or session.world.terrain.distance(record.cell,center) > 1:
			_release(id)
			changed = true
	for cell: Vector2i in descriptors.keys():
		if session.world.terrain.distance(cell,center) > 2: descriptors.erase(cell)
	if not inside:
		for y in range(maxi(-8,center.y-2),mini(8,center.y+3)):
			for x in range(maxi(-8,center.x-2),mini(0,center.x+3)):
				var cell := Vector2i(x,y)
				if not descriptors.has(cell): prepare_queue.append(cell)
				elif session.world.terrain.distance(cell,center) <= 1:
					for record: Dictionary in descriptors[cell]:
						if not loaded.has(record.id) and not excluded.has(record.id): queue.append(record)
		queue.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.at.distance_squared_to(at) < b.at.distance_squared_to(at))
		prepare_queue.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return Vector2(a).distance_squared_to(Vector2(center)) < Vector2(b).distance_squared_to(Vector2(center)))
	if changed: session.world.refresh_obstacles()
func _occupied(record: Dictionary) -> bool:
	var bounds := Rect2(record.at-Vector2(26,54),Vector2(52,60))
	for p: Dictionary in session.homestead.plots:
		if bounds.intersects(Land.bounds(p)): return true
	for home: Dictionary in session.world.homes:
		if bounds.intersects(Rect2(home.at,home.region.size).grow(12)): return true
	for fixture in session.grounds.fixtures:
		if bounds.intersects(fixture.visual_bounds().grow(5)): return true
	return false
func available(record: Dictionary) -> bool:
	if record.kind=="grass": return online>=float(seed_state(str(record.id)).next)
	if record.kind in ["ginseng","reishi"]:
		return online >= float(collected.get(record.id,_rare_deadline(record.id,0,true)))
	return online >= float(collected.get(record.id,0)) if record.kind == "mulberry" else not collected.has(record.id)
func seed_state(id: String) -> Dictionary:
	if not seed_patches.has(id): seed_patches[id]=Seeds.schedule(session.world.resource_seed,id,0)
	return seed_patches[id]
func _rare_deadline(id: String, now: float, initial := false) -> float:
	# Geometric waiting is equivalent to independent 3% rolls each period, without far-area loops.
	var epoch := floori(now/Catalog.RARE_INTERVAL)
	var rng := RandomNumberGenerator.new()
	rng.seed = session.world.resource_seed ^ id.hash() ^ (epoch * 83492791)
	var failures := floori(log(maxf(0.0000001,1.0-rng.randf()))/log(1.0-Catalog.RARE_CHANCE))
	return (epoch+failures+(0 if initial else 1))*Catalog.RARE_INTERVAL
func _process(delta: float) -> void:
	chop_cooldown = maxf(0,chop_cooldown-delta)
	built_last_frame = 0
	if not is_instance_valid(session) or inside: return
	var started := Time.get_ticks_usec()
	if not prepare_queue.is_empty():
		var cell: Vector2i = prepare_queue.pop_front()
		descriptors[cell] = generate(cell)
		if session.world.terrain.distance(cell,center) <= 1:
			for record: Dictionary in descriptors[cell]:
				if not loaded.has(record.id) and not excluded.has(record.id): queue.append(record)
	var attempts := 0
	while not queue.is_empty() and built_last_frame < 2 and attempts < 8 and Time.get_ticks_usec()-started < 2000:
		attempts += 1
		var record: Dictionary = queue.pop_front()
		if loaded.has(record.id) or excluded.has(record.id): continue
		if record.kind in ["tree","mulberry"] and int(session.inventory.resource_hits.get(record.id,0)) >= 4: continue
		if _occupied(record):
			excluded[record.id] = true
			continue
		if record.kind in ["tree","mulberry"] and record.at.distance_to(session.world.active_resident.position) < 18:
			queue.append(record)
			continue
		var node := Plant.new()
		node.configure(self,record)
		node.available = available(record)
		session.world.objects.add_child(node)
		loaded[record.id] = node
		session.world.points["herb:"+record.id] = {"position":record.at,"radius":22.0,"label":"林木" if record.kind=="tree" else Catalog.NAMES[record.kind],"action":"采集桑叶" if record.kind=="mulberry" else "采集", "source":node}
		built_last_frame += 1
		if Time.get_ticks_usec()-started >= 2000: break
	if built_last_frame > 0: session.world.refresh_obstacles()
	refresh_left -= delta
	if refresh_left <= 0:
		refresh_left = 0.2
		for node: Node2D in loaded.values():
			var ready := available(node.record)
			if node.available != ready:
				node.available = ready
				node.queue_redraw()
			if node.record.kind in ["tree","mulberry"]:
				var weapon: String = session.magic.ensure(session.world.active_resident.resident_id).equipment.weapon
				var action := "需装备斧头"
				if weapon in session.magic.Catalog.Gear.AXES: action = "砍树 %d/4" % int(session.inventory.resource_hits.get(node.record.id,0))
				elif node.record.kind == "mulberry":
					action = "先卸下武器采桑叶" if weapon != "" else ("空手采桑叶" if ready else "桑叶恢复中（%d秒）" % ceili(float(collected[node.record.id])-online))
				session.world.points["herb:"+node.record.id].action = action
			elif node.record.kind=="grass":
				session.world.points["herb:"+node.record.id].action="采集"+str(session.inventory.Catalog.ITEMS[seed_state(str(node.record.id)).item].name) if ready else "种子 · 每2分钟20%刷新"
			else:
				session.world.points["herb:"+node.record.id].action = ("采集桑叶" if node.record.kind=="mulberry" else "采集") if ready else ("桑叶恢复中（%d秒）" % ceili(float(collected[node.record.id])-online) if node.record.kind=="mulberry" else ("暂无草药 · 每2分钟3%刷新" if node.record.kind in ["ginseng","reishi"] else "已采集"))
func gather(id: String) -> bool:
	var actor: CharacterBody2D = session.world.active_resident
	if not session.production.allowed(actor) or actor.room_id != "" or not loaded.has(id): return false
	var node: Node2D = loaded[id]
	var record: Dictionary = node.record
	if actor.position.distance_to(record.at) >= 23: return false
	var weapon: String = session.magic.ensure(actor.resident_id).equipment.weapon
	if record.kind in ["tree","mulberry"]:
		if weapon in session.magic.Catalog.Gear.AXES: return chop(id)
		if record.kind == "tree" or weapon != "":
			message.emit("空手才能采桑叶；装备斧头可以砍树。" if record.kind=="mulberry" else "请先装备石斧或铁斧，再砍树。")
			return false
	if not available(record):
		if record.kind=="grass":
			message.emit("草丛暂无种子；每2分钟在线时间20%概率刷新一种种子。")
			return false
		message.emit("桑叶还需%d秒在线时间恢复。" % ceili(float(collected[id])-online) if record.kind=="mulberry" else ("该位置暂无草药，每2分钟在线时间以3%概率刷新。" if record.kind in ["ginseng","reishi"] else "这株草药已经采完。"))
		return false
	var before: Dictionary = session.inventory.export_data()
	var item := str(seed_state(id).item) if record.kind=="grass" else ("mulberry_leaf" if record.kind=="mulberry" else str(record.kind))
	var gains := {item:1}
	var harvest := int(mulberry_harvests.get(id,0))+1
	if record.kind=="mulberry" and Silk.extra(session.world.resource_seed,id,harvest): gains["silk"]=1
	if not session.inventory.exchange(actor.resident_id,{}, gains):
		message.emit("背包已满，草药留在原地。")
		return false
	if record.kind=="mulberry": mulberry_harvests[id]=harvest
	if record.kind=="grass": seed_patches[id]=Seeds.schedule(session.world.resource_seed,id,online)
	else: collected[id] = online+Catalog.REGROW if record.kind=="mulberry" else (_rare_deadline(id,online) if record.kind in ["ginseng","reishi"] else -1.0)
	node.available = false
	node.queue_redraw()
	return session.production.commit(before,"获得%s×1%s" % [session.inventory.Catalog.ITEMS[item].name,("；额外获得蚕丝×1" if gains.has("silk") else "")+"；桑树保留，2分钟在线时间后恢复。" if record.kind=="mulberry" else "。"])
func chop(id: String) -> bool:
	var actor: CharacterBody2D = session.world.active_resident
	if not session.production.allowed(actor) or actor.room_id != "" or chop_cooldown > 0 or not loaded.has(id): return false
	var node: Node2D = loaded[id]
	if node.record.kind not in ["tree","mulberry"] or actor.position.distance_to(node.position) >= 23: return false
	if session.magic.ensure(actor.resident_id).equipment.weapon not in session.magic.Catalog.Gear.AXES: return false
	if not session.magic.weapon_usable(actor.resident_id): return false
	var hits := int(session.inventory.resource_hits.get(id,0))
	if hits >= 4: return false
	var before: Dictionary = session.inventory.export_data()
	var next := hits+1
	if next%2 == 0 and not session.inventory.exchange(actor.resident_id,{}, {"wood":1}):
		message.emit("背包已满，树木与砍伐进度保留。")
		return false
	session.inventory.resource_hits[id] = next
	session.magic.consume_weapon(actor.resident_id)
	if not session.production.commit(before,"获得木头×1。" if next%2==0 else "砍树 %d/4。" % next): return false
	chop_cooldown = 0.35
	if next == 4:
		_release(id)
		session.world.refresh_obstacles()
	return true

func elapse(delta: float) -> void:
	online += maxf(0,delta)
func drink_soup(item: String) -> bool:
	if not Catalog.RECIPES.has(item) or not session.production.allowed(session.world.active_resident): return false
	var before: Dictionary = session.inventory.export_data()
	if not session.vitals.use_food(session.world.active_resident.resident_id,item): return false
	return session.production.commit(before,"大补汤：生命与健康已回满。" if item=="restorative_soup" else "补气汤：健康+5，生命+3（不超过生命上限）。")
func export_state() -> Dictionary:
	return {"mulberry_harvests":mulberry_harvests.duplicate(),"seed_patches":seed_patches.duplicate(true),"online":online,"collected":collected.duplicate(true),"excluded":excluded.keys()}
func _release(id: String) -> void:
	var node: Node2D = loaded[id]
	if is_instance_valid(node.body): session.world.obstacle_bodies.erase(node.body.get_instance_id())
	session.world.points.erase("herb:"+id)
	node.free()
	loaded.erase(id)
func restore(data: Dictionary) -> void:
	chop_cooldown = 0
	for id: String in loaded.keys(): _release(id)
	queue.clear()
	prepare_queue.clear()
	descriptors.clear()
	center = Vector2i(-100,-100)
	online = maxf(0,float(data.get("online",0)))
	collected = data.get("collected",{}).duplicate(true)
	mulberry_harvests=data.get("mulberry_harvests",{}).duplicate(true)
	seed_patches.clear()
	for id: String in data.get("seed_patches",{}):
		var patch: Dictionary=data.seed_patches[id]
		if patch.get("item","") in Seeds.ITEMS: seed_patches[id]={"item":patch.item,"next":maxf(Seeds.INTERVAL,float(patch.get("next",Seeds.INTERVAL)))}
	excluded.clear()
	for id in data.get("excluded",[]): excluded[id] = true
