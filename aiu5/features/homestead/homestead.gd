# Owns water collection, online crop growth/drought, planting/harvest and kitchen cooking.
extends Node

signal message(text: String)
const Land := preload("res://features/homestead/land.gd")
const Crops := preload("res://features/homestead/crop_catalog.gd")
const Grid := preload("res://features/homestead/farm_grid.gd")
const Water := preload("res://features/inventory/water_catalog.gd")
const Meat := preload("res://features/homestead/meat_catalog.gd")
const DRY_AFTER := 7200.0
var world: Node2D
var interiors: Node2D
var inventory: Node
var land: Node2D
var plots: Array = []
var selected_seeds: Dictionary = {}
var timeline := 0.0
var plot_stamps: Array[float] = []
var next_event := INF
var settling := false
var clock_driven := false
var cooking := {"remaining":0.0,"ready":0,"item":"cooked_pork"}

func start(village: Node2D, rooms: Node2D, belongings: Node) -> void:
	world = village
	interiors = rooms
	inventory = belongings
	land = Land.new()
	world.add_child(land)
	world.move_child(land, 1)
	world._body(land, Land.LAKE.get_center(), Land.LAKE.size)
	world.points.erase("farm")
	world._label("湖泊 · 取水", Vector2(118, 171))
	world.points["lake"] = {"position": Vector2(157, 205), "radius": 22.0, "label": "绿洲湖泊", "action": "装满桶与杯"}
	world.points["altar"]["action"] = "保存祭台存档"
	world.points["well"]["action"] = "装满桶与杯"
	plots = Grid.split([{"x": 218.0, "y": 230.0, "w": 80.0, "h": 48.0, "age": 0.0, "dry": true, "crop": "wheat", "growth": 0.0}])
	refresh()
	world.refresh_obstacles()

func _process(delta: float) -> void:
	if is_instance_valid(world) and not clock_driven:
		advance(delta)

func elapse(delta: float) -> void:
	timeline += maxf(0, delta)
	if cooking.remaining > 0:
		cooking.remaining = maxf(0, float(cooking.remaining) - maxf(0, delta))
		if cooking.remaining <= 0:
			cooking.ready += 1
			message.emit("灶台的肉煎熟了，回灶房按 E 领取。")
	if timeline >= next_event: settle()

func advance(delta: float) -> void:
	elapse(delta)
	settle()

func _ensure_stamps() -> void:
	while plot_stamps.size() < plots.size(): plot_stamps.append(timeline)

func _settle_plot(index: int) -> bool:
	_ensure_stamps()
	var p: Dictionary = plots[index]
	var delta := maxf(0, timeline - plot_stamps[index])
	plot_stamps[index] = timeline
	var previous_stage := int(p.get("stage", 1))
	var was_mature := bool(p.get("mature", false))
	var was_dry := bool(p.dry)
	var age := float(p.age)
	if Crops.CROPS.has(p.crop) and not p.dry:
		p.growth = minf(Crops.MATURE_AFTER, float(p.get("growth", 0)) + minf(delta, maxf(0, DRY_AFTER - age)))
	p.age += delta
	if p.age > DRY_AFTER:
		if not p.dry:
			p.dry = true
			if p.crop != "": p.crop = "dead"
		elif Crops.CROPS.has(p.crop): p.crop = "dead"
	_sync_crop(p)
	if p.mature and not was_mature:
		message.emit(str(Crops.CROPS[p.crop].name) + "成熟了，到田旁按 G 收获。")
	return was_dry != p.dry or int(p.stage) != previous_stage or bool(p.mature) != was_mature

func settle() -> void:
	if settling: return
	settling = true
	var dirty := false
	for i in range(plots.size()): dirty = _settle_plot(i) or dirty
	_schedule()
	if dirty:
		land.plots = plots
		land.queue_redraw()
	settling = false

func _schedule() -> void:
	_ensure_stamps()
	next_event = INF
	for i in range(plots.size()):
		var p: Dictionary = plots[i]
		if not p.dry or Crops.CROPS.has(p.crop):
			next_event = minf(next_event, plot_stamps[i] + maxf(0, DRY_AFTER - float(p.age)) + 0.0001)
		if not p.dry and Crops.CROPS.has(p.crop) and not p.get("mature", false):
			var growth := float(p.get("growth", 0))
			next_event = minf(next_event, plot_stamps[i] + (floorf(growth / 120) + 1) * 120 - growth)

func refresh() -> void:
	_ensure_stamps()
	_schedule()
	for p: Dictionary in plots: _sync_crop(p)
	land.plots = plots
	land.queue_redraw()

func _sync_crop(p: Dictionary) -> void:
	# Old saves used a generic seedling; it is now wheat with preserved soil moisture.
	if p.get("crop", "") == "seedling": p.crop = "wheat"
	p.growth = clampf(float(p.get("growth", 0)), 0, Crops.MATURE_AFTER)
	p.stage = Crops.stage(p.growth) if Crops.CROPS.has(p.crop) else 0
	p.mature = Crops.CROPS.has(p.crop) and Crops.mature(p.growth) and not p.dry

func nearby(actor: CharacterBody2D) -> Dictionary:
	if actor.room_id != "":
		land.focus(-1)
		return {}
	var result: Dictionary = {}
	var distance := INF
	for i in range(plots.size()):
		var rect := Land.bounds(plots[i])
		var edge := actor.position.clamp(rect.position, rect.end)
		var gap := actor.position.distance_to(edge)
		var center_gap := actor.position.distance_squared_to(rect.get_center())
		if gap < 23.0 and center_gap < distance:
			distance = center_gap
			_settle_plot(i)
			var p: Dictionary = plots[i]
			var action := "E 灌溉 · G 播种" if p.crop == "" or p.crop == "dead" else "E 灌溉 · 生长中"
			if p.mature: action = "G 收获 · E 灌溉"
			var detail := Crops.detail(p)
			if p.crop == "": detail = "已选" + str(inventory.Catalog.ITEMS[seed_for(actor)].name) + " · B 背包切换"
			result = {"index": i, "label": "田格 · " + ("干旱" if p.dry else "湿润"), "action": action, "description": detail}
	land.focus(int(result.get("index", -1)))
	return result

func fill_bucket(actor: CharacterBody2D) -> bool:
	if actor.dead: return false
	var costs: Dictionary = {}
	var rewards: Dictionary = {}
	var magical: Array[int] = []
	var bag: Array = inventory.ensure_bag(actor.resident_id)
	for i in range(bag.size()):
		var slot: Dictionary = bag[i]
		var item := str(slot.get("item", ""))
		var full := Water.filled(item)
		if full == "" or full == item: continue
		if inventory.Origin.magical(slot):
			magical.append(i)
			continue
		costs[item] = int(costs.get(item, 0)) + int(slot.count)
		rewards[full] = int(rewards.get(full, 0)) + int(slot.count)
	if costs.is_empty() and magical.is_empty():
		message.emit("随身没有需要补水的桶或木杯；B 可查看水量。")
		return false
	if not inventory.exchange(actor.resident_id, costs, rewards, true, true):
		message.emit("本次装水未完成，容器和水量保持原样。")
		return false
	for index: int in magical:
		inventory.transform_record(actor.resident_id,index,Water.filled(str(inventory.ensure_bag(actor.resident_id)[index].item)))
	message.emit("已装满随身桶与木杯；B 选中饮水，每次饥渴 +4。只有满桶可灌溉。")
	return true

func water(actor: CharacterBody2D) -> bool:
	if actor.dead: return false
	var context := nearby(actor)
	if context.is_empty(): return false
	if not inventory.exchange(actor.resident_id, {"water_bucket": 1}, {"bucket": 1}):
		message.emit("只有满桶（4/4）才能灌溉；先到水井或湖边 E 补满。")
		return false
	# Settle growth before resetting individual water clocks, including distant cells.
	settle()
	var watered := Grid.irrigation(plots, int(context.index))
	for index in watered:
		var p: Dictionary = plots[index]
		p.dry = false
		p.age = 0.0
		if p.crop == "dead":
			p.crop = ""
			p.growth = 0.0
	refresh()
	message.emit("已用一桶水灌溉 %d 格相连农田（最多15格）；两小时在线时间内需再次浇水。" % watered.size())
	return true

func plant(actor: CharacterBody2D) -> bool:
	if actor.dead: return false
	var context := nearby(actor)
	if context.is_empty():
		message.emit("先到农田旁，再按 G 播种。")
		return false
	var p: Dictionary = plots[context.index]
	if p.dry:
		message.emit("干旱土地不能种植，先用一桶水灌溉。")
		return false
	if p.crop != "":
		message.emit("这片农田已经种有庄稼。")
		return false
	var seed := seed_for(actor)
	if not inventory.exchange(actor.resident_id, {seed: 1}, {}):
		message.emit("背包里需要" + str(inventory.Catalog.ITEMS[seed].name) + "；B 选择另一种种子。")
		return false
	p.crop = Crops.SEEDS[seed]
	p.growth = 0.0
	refresh()
	message.emit("已播种" + str(Crops.CROPS[p.crop].name) + "：4阶段各2分钟，共8分钟成熟。")
	return true

func seed_for(actor: CharacterBody2D) -> String:
	return str(selected_seeds.get(actor.resident_id, "seeds"))

func select_seed(actor: CharacterBody2D, seed: String) -> void:
	if actor.dead or not Crops.SEEDS.has(seed): return
	selected_seeds[actor.resident_id] = seed
	var context := nearby(actor)
	if not context.is_empty() and plots[context.index].crop == "" and not plots[context.index].dry:
		plant(actor)
	else:
		message.emit("已选择" + str(inventory.Catalog.ITEMS[seed].name) + "，湿润空田旁按 G 播种。")

func cultivate(actor: CharacterBody2D) -> bool:
	var context := nearby(actor)
	if not context.is_empty() and plots[context.index].mature: return harvest(actor)
	return plant(actor)

func harvest(actor: CharacterBody2D) -> bool:
	if actor.dead: return false
	var context := nearby(actor)
	if context.is_empty(): return false
	var p: Dictionary = plots[context.index]
	if not p.mature:
		message.emit("庄稼尚未成熟，每个生长阶段需要2分钟在线时间。")
		return false
	var crop: Dictionary = Crops.CROPS[p.crop]
	if not inventory.exchange(actor.resident_id, {}, {str(crop.harvest): 1, str(crop.seed): 2}):
		message.emit("背包空间不足以同时收下作物和种子，庄稼留在田里。")
		return false
	p.crop = ""
	p.growth = 0.0
	refresh()
	message.emit("已收获" + str(inventory.Catalog.ITEMS[crop.harvest].name) + "×1、" + str(inventory.Catalog.ITEMS[crop.seed].name) + "×2；土壤仍湿润时可直接再播种。")
	return true

func till(actor: CharacterBody2D, ground: Node2D) -> bool:
	if actor.room_id != "" or not inventory.has_item(actor.resident_id, "hoe"):
		message.emit("带上锄头，在户外空沙地按 Q 开垦。")
		return false
	var direction: Vector2 = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT][actor.facing]
	var at: Vector2 = (actor.position + direction * 22 - Vector2(8, 8)).snapped(Vector2(16, 16))
	var rect := Rect2(at, Vector2(16, 16))
	var error: String = ground.land_error(rect, actor, false)
	for p: Dictionary in plots:
		if rect.intersects(Land.bounds(p)): error = "这里已经是农田。"
	if error != "":
		message.emit(error)
		return false
	plots.append({"x": at.x, "y": at.y, "w": 16.0, "h": 16.0, "age": 0.0, "dry": true, "crop": ""})
	refresh()
	message.emit("已开垦一片农田，先 E 灌溉，再 G 播种。")
	return true

func stove(actor: CharacterBody2D, preferred := "") -> bool:
	if actor.dead: return false
	if cooking.ready > 0:
		var cooked := str(cooking.get("item","cooked_pork"))
		if not inventory.exchange(actor.resident_id, {}, {cooked:int(cooking.ready)}):
			message.emit("背包已满，熟肉会继续保留在灶台。")
			return false
		cooking.ready = 0
		message.emit("已取出"+str(inventory.Catalog.ITEMS[cooked].name)+"，可在物品栏食用。")
		return true
	if cooking.remaining > 0:
		message.emit("正在煎肉，还需要 %d 秒在线时间。" % ceili(cooking.remaining))
		return false
	var raw := preferred
	if raw == "":
		for item: String in Meat.RAW:
			if inventory.has_item(actor.resident_id,item): raw=item; break
	if not Meat.RAW.has(raw) or not inventory.exchange(actor.resident_id,{raw:1},{}):
		message.emit("背包中需要生猪肉、生牛肉或生羊肉；B选中生肉可指定烹饪。")
		return false
	cooking.item = Meat.RAW[raw]
	cooking.remaining = 60.0
	message.emit("放入"+str(inventory.Catalog.ITEMS[raw].name)+"；60在线秒后煎熟，回灶台E领取。")
	return true

func export_state() -> Dictionary:
	settle()
	return {"plots": plots.duplicate(true), "cooking": cooking.duplicate(), "selected_seeds": selected_seeds.duplicate()}

func restore(data: Dictionary) -> void:
	timeline = 0
	plot_stamps.clear()
	if data.has("plots"): plots = Grid.split(data.plots)
	cooking = Meat.restore_cooking(data.get("cooking",{}))
	selected_seeds.clear()
	for id: String in data.get("selected_seeds", {}):
		var seed := str(data.selected_seeds[id])
		if Crops.SEEDS.has(seed): selected_seeds[id] = seed
	refresh()
