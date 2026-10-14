# Owns persistent constructed buildings, conversion, interiors, armor and safe collapse into searchable ruins.
extends Node
signal message(text: String)
const HouseRules := preload("res://features/construction/house_rules.gd")
const Catalog := preload("res://features/construction/catalog.gd")
const Building := preload("res://features/construction/building.gd")
const Ladder := preload("res://features/construction/ladder.gd")
const Layout := preload("res://features/village/layout.gd")
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
	var ladder: bool = bool(definition.get("ladder", false))
	var spot := at
	var wall := "cliff"
	if ladder:
		# Ladders lean on whichever wall the builder stands beside: the southern cliff or the eastern ridge.
		if actor.position.x > Layout.RIDGE.position.x - 170.0 and actor.position.y < 0.0:
			wall = "ridge"
			spot = Vector2(Layout.RIDGE.get_center().x, clampf(actor.position.y, Layout.RIDGE.position.y + 24, Layout.RIDGE.end.y - 24))
		else:
			spot = Vector2(clampf(actor.position.x, Layout.CLIFF.position.x + 24, Layout.CLIFF.end.x - 24), Layout.CLIFF.end.y)
	records[id] = {"id": id, "kind": kind, "at": [spot.x, spot.y], "hp": definition.hp, "max_hp": definition.hp, "defense": definition.defense, "wall": wall}
	if kind=="herb_house": records[id]["job"]={"level":1,"initial":true,"duration":30.0,"remaining":30.0,"boost_left":0.0,"boost_rate":1.0}
	if HouseRules.is_house(kind):
		var level := int(HouseRules.HOUSE_LEVELS[kind])
		records[id].merge({"level":level,"crystals":{},"job":{"level":level,"initial":true,"duration":30.0,"remaining":30.0,"boost_left":0.0,"boost_rate":1.0}})
	if not ladder: session.grounds.remove_fixture(bench)
	_attach(id)
	session.world.refresh_obstacles()
	return session.production.commit(before, "%s%s%s。" % ["开始建设" if HouseRules.is_house(kind) or kind=="herb_house" else "建成",definition.name,"，需30在线秒，建筑台已消耗" if HouseRules.is_house(kind) or kind=="herb_house" else ("" if ladder else "，建筑台已消耗")])
func _attach(id: String) -> void:
	var record: Dictionary = records[id]
	var at := Vector2(record.at[0], record.at[1])
	var definition: Dictionary = Catalog.BUILDINGS[record.kind]
	if bool(definition.get("ladder", false)):
		var ladder := Ladder.new()
		ladder.name = id.replace(":", "_")
		ladder.position = at
		if str(record.get("wall", "cliff")) == "ridge":
			ladder.rotation = PI / 2.0
			session.world.open_ridge(at.y)
		else:
			session.world.open_cliff(at.x)
		session.world.objects.add_child(ladder)
		nodes[id] = ladder
		return
	var ruined := float(record.hp) <= 0
	var building: bool=record.get("job",{}).get("initial",false)
	var name := str(definition.name) + (" Lv.%d" % int(record.get("level",1)) if HouseRules.is_house(record.kind) else "") + ("废墟" if ruined else ("（施工中）" if building else ""))
	var home := {"id": id, "name": name, "at": at, "region": Rect2(Vector2.ZERO, Catalog.FOOTPRINT), "door": at + Vector2(48, 91),
		"description": "%s · 生命 %.1f/%.0f · 防御%d（减伤%d%%）" % [name, record.hp, record.max_hp, record.defense, record.defense], "function":"herb_house" if record.kind=="herb_house" else "", "built": true, "tower": record.kind == "arrow_tower" and not ruined, "ruined": ruined, "building":building}
	session.world.homes.append(home)
	home.description=describe(record)
	session.world.points[id] = {"position": home.door, "radius": 25.0, "label": name, "action": "搜寻废墟" if ruined else ("登上顶部" if home.tower else "进屋"), "description": home.description}
	session.interiors.special_rooms[id] = _make_room.bind(id)
	var node := Building.new()
	node.record = record
	node.position = at + Vector2(48, 79)
	node.name = id.replace(":", "_")
	session.world.objects.add_child(node)
	if not ruined:
		var body: Node=session.world._body(node, Vector2(0,-38), Vector2(90,72)); body.set_meta("constructed_home",id)
	nodes[id] = node
	session.world.houses.append(node)
func _make_room(id: String) -> Node2D:
	var home: Dictionary = session.world.home_data(id)
	var tower: bool = home.tower
	var room: Node2D = Roof.new() if tower else Room.new()
	var saved: Array = session.interiors.layout_overrides.get(id, [{"missing": true}])
	if records[id].kind=="herb_house":
		room.configure(home,{"size":Vector2(224,160),"floor":Color("8b7954"),"mats":[],"furniture":[["workbench",Vector2(24,36),Vector2(48,28),1],["bed",Vector2(152,48),Vector2(32,48),0]]},saved)
		return room
	room.configure(home, {"size": Vector2(96,80) if tower else Vector2(208,144), "floor": Color("ba9362") if not home.ruined else Color("8d806a"),
		"mats": [] if tower else [Rect2(18,94,38,20)],
		"furniture": [] if tower else [["bed",Vector2(18,34),Vector2(32,48),0],["chest",Vector2(155,39),Vector2(28,20),1],["table",Vector2(87,42),Vector2(48,24),2],["chair",Vector2(102,78),Vector2(14,18),0]]}, saved)
	if tower:
		room.set_meta("outdoor_roof", true)
		room.z_index = 20
	return room
func hit(id: String, raw: float, consume_tool := false, element := "") -> bool:
	if not records.has(id) or records[id].hp <= 0 or raw <= 0 or session.overview or session.menu_paused: return false
	var before: Dictionary = session.inventory.export_data()
	if consume_tool and not session.magic.consume_weapon(session.world.active_resident.resident_id): return false
	var record: Dictionary = records[id]
	record.hp = maxf(0, float(record.hp) - Catalog.damage(raw, int(record.defense))*(1.0-HouseRules.resistance(record.get("crystals",{}),element)))
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
		home.description = describe(record)
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
	return hit(id,session.magic.attack_damage(actor.resident_id),true) if records.has(id) else false
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
		var record := {"id":id,"kind":source.kind,"at":source.at,"hp":clampf(float(source.hp),0,definition.hp),"max_hp":definition.hp,"defense":definition.defense}
		# Extra per-record fields (a ladder remembers which wall it leans on) survive a reload.
		if source.has("wall"): record["wall"] = str(source.wall)
		if HouseRules.is_house(str(source.kind)):
			var level := clampi(int(source.get("level",HouseRules.HOUSE_LEVELS[source.kind])),1,HouseRules.MAX_LEVEL)
			var stats := HouseRules.stats(level)
			record.merge({"level":level,"crystals":{},"max_hp":stats.hp,"hp":clampf(float(source.hp),0,float(stats.hp)),"defense":stats.defense,"job":{}},true)
			for element: String in HouseRules.ELEMENTS:
				var count := clampi(int(source.get("crystals",{}).get(element,0)),0,4)
				if count>0: record.crystals[element]=count
			var job: Variant=source.get("job",{})
			if job is Dictionary and not job.is_empty():
				var target := clampi(int(job.get("level",level)),level,mini(HouseRules.MAX_LEVEL,level+1))
				var duration := HouseRules.duration(target,bool(job.get("initial",false)))
				record.job={"level":target,"initial":bool(job.get("initial",false)),"duration":duration,"remaining":clampf(float(job.get("remaining",duration)),0,duration),"boost_left":clampf(float(job.get("boost_left",0)),0,20),"boost_rate":clampf(float(job.get("boost_rate",1)),1,1.5),"crystal":str(job.get("crystal","")) if str(job.get("crystal","")) in HouseRules.ELEMENTS and HouseRules.needs_crystal(target) else ""}
		if source.kind=="herb_house" and source.get("job",{}) is Dictionary and not source.get("job",{}).is_empty():
			record.job={"level":1,"initial":true,"duration":30.0,"remaining":clampf(float(source.job.get("remaining",30)),0,30),"boost_left":0.0,"boost_rate":1.0}
		records[id] = record
		next_id = maxi(next_id,int(id.trim_prefix("built:"))+1)
		_attach(id)
	session.world.refresh_obstacles()

func target_job(actor: Node, at: Vector2) -> String:
	var result := ""
	var nearest := INF
	if actor.room_id!="": return ""
	for id: String in records:
		var r: Dictionary=records[id]
		if float(r.hp)<=0 or r.get("job",{}).is_empty(): continue
		var bounds := Rect2(Vector2(r.at[0],r.at[1]),Catalog.FOOTPRINT).grow(8)
		var point := at.clamp(bounds.position,bounds.end)
		var door := Vector2(r.at[0]+48,r.at[1]+91)
		if point.distance_to(at)<=12 and actor.global_position.distance_to(door)<=120 and actor.global_position.distance_to(at)<=120 and magic_line(actor,door):
			var gap := bounds.get_center().distance_squared_to(at)
			if gap<nearest: result=id; nearest=gap
	return result
func magic_line(actor: Node, at: Vector2) -> bool:
	return session.magic.skills._visible(actor,at,120) and session.magic.skills._line_clear(actor,at)
func near_house() -> String:
	var actor: Node=session.world.active_resident
	if records.has(actor.room_id) and HouseRules.is_house(str(records[actor.room_id].kind)): return actor.room_id
	if actor.room_id!="": return ""
	var result := ""
	var nearest := 36.000001
	for id: String in records:
		if not HouseRules.is_house(str(records[id].kind)): continue
		var distance: float=actor.position.distance_to(Vector2(records[id].at[0]+48,records[id].at[1]+91))
		if distance<nearest: result=id; nearest=distance
	if result!="": return result
	return ""
func upgrade_near(element: String) -> bool:
	if is_instance_valid(session.simulation): session.simulation.flush()
	var actor: Node=session.world.active_resident
	if not session.production.allowed(actor): return false
	var id := near_house()
	if id=="": return false
	var r: Dictionary=records[id]
	if r.hp<=0 or not r.get("job",{}).is_empty() or int(r.level)>=HouseRules.MAX_LEVEL:
		message.emit("房屋已到最高级、正在施工或已倒塌，暂不能升级。"); return false
	var level := int(r.level)+1
	if HouseRules.needs_crystal(level) and element not in HouseRules.ELEMENTS: return false
	var before: Dictionary=session.inventory.export_data()
	var cost := HouseRules.costs(level,element)
	if not session.inventory.exchange(actor.resident_id,cost,{}): message.emit("升级材料不足，尚未扣除。"); return false
	var crystal := element if HouseRules.needs_crystal(level) else ""
	var duration := HouseRules.duration(level)
	r.job={"level":level,"initial":false,"duration":duration,"remaining":duration,"boost_left":0.0,"boost_rate":1.0,"crystal":crystal}
	_refresh_record(id)
	return session.production.commit(before,"开始升级至%d级，需%.1f在线秒；材料已投入。" % [level,duration])
func describe(r: Dictionary) -> String:
	var text := "%s · Lv.%d · 生命 %.1f/%.0f · 防御%d%%" % [Catalog.BUILDINGS[r.kind].name,int(r.get("level",1)),r.hp,r.max_hp,r.defense]
	var job: Dictionary=r.get("job",{})
	if not job.is_empty(): text+=" · %s%d级 %.0f%%／剩余%.1f秒" % ["建设" if job.initial else "升级",job.level,(1.0-float(job.remaining)/float(job.duration))*100.0,job.remaining]
	for element: String in HouseRules.ELEMENTS:
		var count := int(r.get("crystals",{}).get(element,0))
		if count>0: text+=" · %s元素免伤%d%%" % [session.magic.Catalog.ELEMENTS[element].name,count*2]
	return text
func upgrade_snapshot() -> Dictionary:
	var id := near_house()
	if id=="": return {"open":true,"mode":"upgrade","station":"","title":"房屋升级 · 请靠近自建房","recipes":[],"job":{}}
	var r: Dictionary=records[id]
	var recipes: Array=[]
	var level := int(r.level)+1
	var elements: Array=HouseRules.ELEMENTS if HouseRules.needs_crystal(level) else [""]
	if level<=HouseRules.MAX_LEVEL:
		for element: String in elements:
			var cost := HouseRules.costs(level,element)
			var ingredients: Array=[]
			for item: String in cost:
				var have := 0
				for slot: Dictionary in session.inventory.ensure_bag(session.world.active_resident.resident_id):
					if slot.get("item","")==item: have+=int(slot.count)
				ingredients.append({"item":item,"name":session.inventory.Catalog.ITEMS[item].name,"need":cost[item],"have":have})
			var title := "升级至%d级" % level
			if element!="": title+=" · "+str(session.magic.Catalog.ELEMENTS[element].name)+"晶石"
			recipes.append({"id":"upgrade:"+element,"name":title,"detail":describe(r)+"\n材料逐级＋15%；耗时逐级＋30%。晶石抗性在升级完成后生效。","duration":HouseRules.duration(level),"ingredients":ingredients,"category":"furniture","enabled":r.hp>0 and r.get("job",{}).is_empty() and session.inventory.exchange(session.world.active_resident.resident_id,cost,{},false)})
	var progress: Dictionary=r.get("job",{}).duplicate(true)
	if not progress.is_empty(): progress["name"]="房屋施工"
	return {"open":true,"mode":"upgrade","station":id,"title":"自建房升级 [U] · 最高10级","recipes":recipes,"job":progress}
func _refresh_record(id: String) -> void:
	var home: Dictionary=session.world.home_data(id)
	if not home.is_empty():
		home.description=describe(records[id])
		if session.world.points.has(id): session.world.points[id].description=home.description
	if is_instance_valid(nodes.get(id)): nodes[id].queue_redraw()
func finish_job(id: String) -> void:
	if not records.has(id) or records[id].get("job",{}).is_empty() or records[id].hp<=0: return
	var r: Dictionary=records[id]
	if r.kind=="herb_house":
		r.job={}; _remove_home(id); _attach(id); session.world.refresh_obstacles(); message.emit("草药屋建设完成。"); return
	var crystal: String=str(r.job.get("crystal",""))
	if crystal in HouseRules.ELEMENTS: r.crystals[crystal]=int(r.crystals.get(crystal,0))+1
	var target := int(r.job.level)
	var stats := HouseRules.stats(target)
	r.merge({"level":target,"kind":HouseRules.kind(target),"max_hp":stats.hp,"hp":stats.hp,"defense":stats.defense,"job":{}},true)
	_remove_home(id); _attach(id); session.world.refresh_obstacles()
	message.emit("房屋%d级施工已完成。" % target)
func progress_job(id: String, fraction: float) -> void:
	if not records.has(id) or records[id].get("job",{}).is_empty(): return
	var job: Dictionary=records[id].job
	job.remaining=maxf(0,float(job.remaining)-float(job.duration)*fraction)
	if job.remaining<=0: finish_job(id)
	else: _refresh_record(id)
func boost_job(id: String, duration: float, rate: float) -> void:
	if not records.has(id) or records[id].get("job",{}).is_empty(): return
	records[id].job.boost_left=duration; records[id].job.boost_rate=rate
func advance(delta: float) -> void:
	for id: String in records.keys():
		var r: Dictionary=records[id]
		if r.hp<=0 or r.get("job",{}).is_empty(): continue
		var job: Dictionary=r.job
		var boosted := minf(delta,float(job.get("boost_left",0)))
		job.remaining=maxf(0,float(job.remaining)-delta-boosted*(float(job.get("boost_rate",1))-1.0))
		job.boost_left=maxf(0,float(job.get("boost_left",0))-delta)
		if job.remaining<=0: finish_job(id)
		else: _refresh_record(id)
func skill_hit(id: String, raw: float, element: String) -> void:
	if not records.has(id) or records[id].hp<=0: return
	var r: Dictionary=records[id]
	r.hp=maxf(0,float(r.hp)-Catalog.damage(raw,int(r.defense))*(1.0-HouseRules.resistance(r.get("crystals",{}),element)))
	if r.hp<=0:
		var home: Dictionary=session.world.home_data(id)
		for actor in session.world.residents:
			if actor.room_id==id: session.interiors.leave(actor,session.world.objects,home.door+Vector2(0,16))
		_remove_home(id); _attach(id); session.world.refresh_obstacles(); session._sync_view()
	else: _refresh_record(id)
