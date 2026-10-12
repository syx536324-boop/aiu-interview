# Owns grain feeding, sex-aware breeding, online growth/cooldowns and persistent herd identity.
extends Node

signal message(text: String)
const Herd := preload("res://features/livestock/herd_catalog.gd")
const Fauna := preload("res://features/livestock/fauna_catalog.gd")
const Animal := preload("res://features/actors/animal.gd")
const Shed := preload("res://features/livestock/shed.gd")
const Trough := preload("res://features/village/trough.gd")
const COW := preload("res://assets/ninja_adventure/Actor/Animal/Cow/SpriteSheetWhiteSide.png")
const MATURITY := 300.0
const BREED_COOLDOWN := 300.0
const FEED_BOOST := 60.0
var world: Node2D
var inventory: Node
var animals: Array[CharacterBody2D] = []
var pending_delta := 0.0
var next_event := 0.0
var active_animals: Array[CharacterBody2D] = []
var settling := false
var clock_driven := false
var next_ids := {"pig": 4, "cow": 3, "sheep":3, "dog": 2, "bird": 2}

func start(village: Node2D, items: Node) -> void:
	world = village
	inventory = items
	animals.assign(world.pigs)
	_build_shed()
	_spawn("cow:1", "cow", "male", MATURITY, Vector2(82, 451))
	_spawn("cow:2", "cow", "female", MATURITY, Vector2(126, 455))
	for r: Dictionary in Herd.initial_sheep()+Fauna.initial_records(): _spawn(r.id,r.species,r.sex,MATURITY,Vector2(r.position[0],r.position[1]))
	world._label("羊群",Vector2(314,404))
	world.points.sheep_trough={"position":Herd.SHEEP_FEEDING,"radius":23.0,"label":"羊群喂食处","action":"喂羊 · 1谷物"}
	world.points.trough.label = "猪圈食槽"
	world.points.trough.action = "喂猪 · 1谷物"
	_refresh_points()
	world.refresh_obstacles()

func _build_shed() -> void:
	var shelter := Shed.new()
	shelter.name = "CattleShed"
	world.add_child(shelter)
	world.move_child(shelter, 2)
	world._body(shelter, Vector2(108, 407), Vector2(108, 7))
	for x in [57, 161]: world._body(shelter, Vector2(x, 425), Vector2(4, 20))
	for x in [48, 168]: world._fence(Vector2(x, 406), 80, true)
	world._fence(Vector2(48, 486), 48, false)
	world._fence(Vector2(120, 486), 48, false)
	var trough := Trough.new()
	trough.position = Vector2(154, 433)
	world.objects.add_child(trough)
	world._body(trough, Vector2(0, -5), Vector2(20, 8))
	world._label("牛棚", Vector2(65, 397))
	world.points.cow_trough = {"position": Vector2(155, 444), "radius": 23.0, "label": "牛棚食槽", "action": "喂牛 · 1谷物"}

func _spawn(id: String, kind: String, gender: String, age: float, at: Vector2) -> CharacterBody2D:
	# A newly created animal must not inherit time accumulated before its birth.
	if not settling: settle()
	var animal := Animal.new()
	animal.animal_id = id
	animal.species = kind
	animal.sex = gender
	animal.growth = age
	animal.pig_seed = 100 + id.hash() % 10000
	animal.sheet = COW if kind == "cow" else world.PINK_PIG
	if Fauna.TYPES.has(kind):
		animal.sheet = Fauna.TYPES[kind].sheet
		animal.pen_bounds = Fauna.TYPES[kind].bounds
	if kind == "cow":
		animal.pen_bounds = Shed.PASTURE
		animal.feeding_point = Shed.FEEDING
	if kind=="sheep":
		animal.pen_bounds=Herd.SHEEP_PASTURE
		animal.feeding_point=Herd.SHEEP_FEEDING
	animal.position = at.clamp(animal.pen_bounds.position, animal.pen_bounds.end)
	world.objects.add_child(animal)
	animals.append(animal)
	if kind == "cow": world.cows.append(animal)
	elif kind == "pig": world.pigs.append(animal)
	return animal

func _process(delta: float) -> void:
	if is_instance_valid(world) and not clock_driven: advance(delta)

func elapse(delta: float) -> void:
	pending_delta += maxf(0, delta)
	if pending_delta + 0.00001 >= next_event: settle()
	# Only nearby juvenile bars need repainting between maturity events.
	for animal in active_animals:
		if not is_instance_valid(animal): continue
		animal.growth_preview = minf(MATURITY, animal.growth + pending_delta)
		if not animal.adult(): animal.queue_redraw()

func settle() -> void:
	if settling: return
	advance(0)

func _next_event() -> float:
	var result := INF
	for animal in animals:
		if not animal.adult(): result = minf(result, MATURITY - animal.growth)
		if animal.cooldown > 0: result = minf(result, animal.cooldown)
	return result

func advance(delta: float) -> void:
	if settling: return
	settling = true
	var remaining := maxf(0, delta) + pending_delta
	pending_delta = 0
	# Jump between growth/cooldown deadlines; a long interval never loops once per second.
	while remaining > 0.00001:
		var step := minf(remaining, maxf(0.00001, _next_event()))
		remaining -= step
		for animal in animals:
			var was_adult: bool = animal.adult()
			animal.growth = minf(MATURITY, animal.growth + step)
			animal.growth_preview = animal.growth
			animal.cooldown = maxf(0, animal.cooldown - step)
			if animal.cooldown < 0.00001: animal.cooldown = 0.0
			if animal.growth > MATURITY - 0.00001: animal.growth = MATURITY
			if was_adult != animal.adult(): animal.sync_visual()
		_try_breed()
	next_event = _next_event()
	_refresh_points()
	settling = false

func _try_breed() -> void:
	for kind in Herd.NAMES:
		var males: Array = []
		var females: Array = []
		for animal in animals:
			if animal.species != kind or not animal.adult() or not animal.fed or animal.cooldown > 0: continue
			if animal.sex == "male": males.append(animal)
			else: females.append(animal)
		for i in range(mini(males.size(), females.size())):
			for parent: CharacterBody2D in [males[i], females[i]]:
				parent.fed = false
				parent.cooldown = BREED_COOLDOWN
			var number := int(next_ids[kind])
			next_ids[kind] = number + 1
			_spawn(kind + ":" + str(number), kind, "male" if number % 2 else "female", 0, (males[i].position + females[i].position) / 2 + Vector2(0, 6))
			message.emit("诞生了一只" + ("小"+str(Herd.NAMES[kind])) + "！5分钟成年，喂一份谷物缩短1分钟。")

func label(animal: CharacterBody2D) -> String:
	if Fauna.TYPES.has(animal.species): return str(Fauna.TYPES[animal.species].name)
	return ("公" if animal.sex == "male" else "母") + str(Herd.NAMES[animal.species]) + (" · 成年" if animal.adult() else " · 幼崽")

func detail(animal: CharacterBody2D) -> String:
	if Fauna.TYPES.has(animal.species):
		var provenance: Dictionary = animal.get_meta("gift_origin", {})
		var source := "魔法赐予 · 属性待定 · " if provenance.get("is_magical", false) else ""
		return source + "动物 · 在村庄附近活动，暂不繁殖或产出物品。"
	if not animal.adult(): return "成长还需%d秒 · 喂1谷物减60秒" % ceili(maxf(0, MATURITY - animal.growth - pending_delta))
	return ("已喂食" if animal.fed else "未喂食") + (" · 繁殖冷却%d秒" % ceili(maxf(0, animal.cooldown - pending_delta)) if animal.cooldown > 0 else " · 等待同种异性都喂食")

func _refresh_points() -> void:
	for animal in animals:
		world.points["animal:" + animal.animal_id] = {"position": animal.position, "radius": 13.0, "label": label(animal), "action": "观察" if Fauna.TYPES.has(animal.species) else "喂食 · 1谷物", "description": detail(animal), "source": animal}

func find_animal(id: String) -> CharacterBody2D:
	for animal in animals:
		if animal.animal_id == id: return animal
	return null

func damage_animal(animal: CharacterBody2D, raw: float, actor_id: String) -> Dictionary:
	# Caller owns the outer snapshot: drops, death, weapon wear and magic reward commit together.
	if not is_instance_valid(animal) or not animals.has(animal) or animal.hp<=0 or raw<=0: return {"ok":false}
	settle()
	var killed: bool=animal.hp<=raw
	var drops: Dictionary=Herd.drops(animal.species,animal.adult()) if killed else {}
	if killed and not inventory.exchange(actor_id,{},drops):
		message.emit("背包放不下全部掉落物，本次击杀未执行。")
		return {"ok":false}
	var name := label(animal)
	animal.hp=maxf(0,animal.hp-raw)
	if animal.hp>0:
		animal.queue_redraw()
		return {"ok":true,"killed":false,"text":"击中%s，剩余生命%.0f/10。" % [name,animal.hp]}
	world.points.erase("animal:"+animal.animal_id)
	animals.erase(animal)
	active_animals.erase(animal)
	world.cows.erase(animal)
	world.pigs.erase(animal)
	if animal.get_parent()!=null: animal.get_parent().remove_child(animal)
	animal.queue_free()
	next_event=_next_event()
	var names: PackedStringArray=[]
	for item: String in drops: names.append("%s×%d" % [inventory.Catalog.ITEMS[item].name,drops[item]])
	return {"ok":true,"killed":true,"text":"击杀%s%s。" % [name,"，获得"+"、".join(names) if not names.is_empty() else ""]}
func damage_cow(animal: CharacterBody2D, raw: float, actor_id: String) -> Dictionary:
	return damage_animal(animal,raw,actor_id)

func feed_animal(actor: CharacterBody2D, id: String, preferred := "") -> bool:
	var animal := find_animal(id)
	if actor.dead or actor.room_id != "" or animal == null or actor.position.distance_to(animal.position) > 24: return false
	if Fauna.TYPES.has(animal.species):
		message.emit(label(animal)+"："+detail(animal))
		return false
	return _feed(actor, animal, preferred)

func feed_species(actor: CharacterBody2D, kind: String, preferred := "") -> bool:
	var point: Vector2 = world.points["sheep_trough" if kind=="sheep" else ("cow_trough" if kind == "cow" else "trough")].position
	if actor.dead or actor.room_id != "" or actor.position.distance_to(point) > 26: return false
	var candidates: Array = []
	for animal in animals:
		if animal.species == kind and (not animal.adult() or not animal.fed): candidates.append(animal)
	if candidates.is_empty():
		message.emit("成年动物都已喂食，等待繁殖或冷却结束。")
		return false
	candidates.sort_custom(func(a: CharacterBody2D, b: CharacterBody2D) -> bool: return _priority(a) < _priority(b))
	var success := _feed(actor, candidates[0], preferred)
	if success:
		for animal in animals:
			if animal.species == kind: animal.feed()
	return success

func _priority(animal: CharacterBody2D) -> int:
	return 0 if not animal.adult() else (1 if animal.cooldown <= 0 else 2)

func feed_near(actor: CharacterBody2D, preferred := "") -> bool:
	var nearest: String = world.nearest_point(actor.position) if actor.room_id == "" else ""
	if nearest.begins_with("animal:"): return feed_animal(actor, nearest.trim_prefix("animal:"), preferred)
	if nearest in ["trough", "cow_trough", "sheep_trough"]: return feed_species(actor,"sheep" if nearest=="sheep_trough" else ("cow" if nearest=="cow_trough" else "pig"),preferred)
	message.emit("靠近猪、牛、羊或喂食处，再使用小麦或稻谷喂食。")
	return false

func _feed(actor: CharacterBody2D, animal: CharacterBody2D, preferred: String) -> bool:
	settle()
	if animal.adult() and animal.fed:
		message.emit("这只动物已经喂过，等待配对；没有消耗谷物。")
		return false
	var grain := preferred if preferred in ["wheat", "rice"] else ("wheat" if inventory.has_item(actor.resident_id, "wheat") else "rice")
	if not inventory.exchange(actor.resident_id, {grain: 1}, {}):
		message.emit("喂食需要1份收获的小麦或稻谷，种子不能当饲料。")
		return false
	animal.feed()
	if animal.adult(): animal.fed = true
	else:
		animal.growth = minf(MATURITY, animal.growth + FEED_BOOST)
		animal.sync_visual()
	message.emit("已用1份" + str(inventory.Catalog.ITEMS[grain].name) + "喂食：" + label(animal) + "。")
	_try_breed()
	next_event = _next_event()
	_refresh_points()
	return true

func export_state() -> Dictionary:
	settle()
	var records: Array = []
	for animal in animals:
		records.append({"gift_origin":animal.get_meta("gift_origin",{}), "id": animal.animal_id, "species": animal.species, "sex": animal.sex, "growth": animal.growth, "cooldown": animal.cooldown, "fed": animal.fed, "hp":animal.hp,
			"position": [animal.position.x, animal.position.y], "target": [animal.target.x, animal.target.y], "feeding": animal.feeding_time, "pause": animal.pause_time})
	return {"animals": records, "next_ids": next_ids.duplicate(), "fauna_version":1,"herd_version":2}

func restore(data: Dictionary, legacy_pigs: Array = []) -> void:
	pending_delta = 0
	var records: Array = data.get("animals", _legacy_records(legacy_pigs)).duplicate(true)
	if int(data.get("fauna_version",0))<1:
		var ids: Array = records.map(func(r: Dictionary) -> String: return str(r.get("id","")))
		for r: Dictionary in Fauna.initial_records():
			if r.id not in ids: records.append(r)
	if int(data.get("herd_version",0))<2:
		var ids: Array=records.map(func(r: Dictionary) -> String: return str(r.get("id","")))
		for r: Dictionary in Herd.initial_sheep():
			if r.id not in ids: records.append(r)
	var wanted: Dictionary = {}
	for record: Dictionary in records:
		if record.get("species", "") in ["pig", "cow", "sheep", "dog", "bird"]: wanted[str(record.id)] = record
	for animal in animals.duplicate():
		if wanted.has(animal.animal_id): continue
		world.points.erase("animal:" + animal.animal_id)
		animals.erase(animal)
		world.pigs.erase(animal)
		world.cows.erase(animal)
		if animal.get_parent() != null: animal.get_parent().remove_child(animal)
		animal.queue_free()
	next_ids = {"pig": 4, "cow": 3, "sheep":3, "dog": 2, "bird": 2}
	for kind: String in next_ids: next_ids[kind] = maxi(next_ids[kind], int(data.get("next_ids", {}).get(kind, next_ids[kind])))
	for id: String in wanted:
		var record: Dictionary = wanted[id]
		var at := Vector2(float(record.position[0]), float(record.position[1]))
		var animal := find_animal(id)
		if animal == null: animal = _spawn(id, record.species, record.get("sex", "female"), float(record.get("growth", MATURITY)), at)
		animal.set_meta("gift_origin", record.get("gift_origin",{}))
		animal.sex = "male" if record.get("sex", "female") == "male" else "female"
		animal.hp = clampf(float(record.get("hp",10)),0.01,10)
		animal.growth = clampf(float(record.get("growth", MATURITY)), 0, MATURITY)
		animal.cooldown = clampf(float(record.get("cooldown", 0)), 0, BREED_COOLDOWN)
		animal.fed = bool(record.get("fed", false)) and animal.adult()
		animal.position = at.clamp(animal.pen_bounds.position, animal.pen_bounds.end)
		var target: Array = record.get("target", record.position)
		animal.target = Vector2(float(target[0]), float(target[1])).clamp(animal.pen_bounds.position, animal.pen_bounds.end)
		animal.feeding_time = float(record.get("feeding", 0))
		animal.pause_time = float(record.get("pause", 0))
		animal.sync_visual()
		next_ids[animal.species] = maxi(int(next_ids[animal.species]), int(id.get_slice(":", 1)) + 1)
	next_event = _next_event()
	_refresh_points()

func _legacy_records(pigs: Array) -> Array:
	var records: Array = []
	for i in range(3):
		var record: Dictionary = pigs[i].duplicate(true) if i < pigs.size() else {"position": [406 + i * 20, 247]}
		record.merge({"id": "pig:" + str(i + 1), "species": "pig", "sex": "male" if i == 0 else "female", "growth": MATURITY}, true)
		records.append(record)
	for i in range(2): records.append({"id": "cow:" + str(i + 1), "species": "cow", "sex": "male" if i == 0 else "female", "growth": MATURITY, "position": [82 + i * 44, 451 + i * 4]})
	return records

func gift_animal(kind: String, record: Dictionary) -> bool:
	if not Fauna.TYPES.has(kind) or animals.size() >= 100: return false
	var id := kind + ":" + str(next_ids[kind])
	next_ids[kind] += 1
	var animal := _spawn(id, kind, "female", MATURITY, Fauna.TYPES[kind].at)
	animal.set_meta("gift_origin", record.duplicate(true))
	_refresh_points()
	return true
