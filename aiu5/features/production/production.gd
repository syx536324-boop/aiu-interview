# Owns proximity-checked workshop recipes, iron-bucket sand collection and online smelting transactions.
extends Node
signal message(text: String)
const Categories := preload("res://features/inventory/categories.gd")
const CraftQueue := preload("res://features/production/craft_queue.gd")
const Herbs := preload("res://features/forest/catalog.gd")
const Smith := preload("res://features/production/smith_catalog.gd")
const Repairs := preload("res://features/production/repairs.gd")
const RECIPES := {
	"campfire":{"name":"篝火","cost":{"stone":2,"wood":1,"coal":1},"gain":{"campfire":1}},
	"iron_knife":{"name":"铁刀","cost":{"wood":1,"crude_iron":1},"gain":{"iron_knife":1}},
	"hoe":{"name":"锄头","cost":{"wood":2,"stone":1},"gain":{"hoe":1}},
	"watering_can":{"name":"水壶","cost":{"wood":2},"gain":{"watering_can":1}},
	"bread":{"name":"面包","cost":{"wheat":3},"gain":{"bread":1}},
	"bucket":{"name":"水桶","cost":{"wood":3},"gain":{"bucket":1}},
	"wooden_cup":{"name":"木质水杯","cost":{"wood":1},"gain":{"wooden_cup":1}},
	"workbench":{"name":"工作台","cost":{"wood":3,"stone":1},"gain":{"workbench":1}},
	"fence":{"name":"围栏","cost":{"wood":4},"gain":{"fence":1}},
	"bed":{"name":"床","cost":{"wool":4,"wood":4},"gain":{"bed":1}},
	"cabinet":{"name":"柜子","cost":{"wood":5},"gain":{"cabinet":1}},
	"table":{"name":"桌子","cost":{"wood":4},"gain":{"table":1}},
	"chair":{"name":"椅子","cost":{"wood":4},"gain":{"chair":1}},
	"chest":{"name":"箱子","cost":{"wood":5},"gain":{"chest":1}},
	"knife":{"name":"石头刀","cost":{"wood":1,"stone":1},"gain":{"knife":1}},
	"bowl":{"name":"木碗","cost":{"wood":2},"gain":{"bowl":1}},
	"scissors":{"name":"剪刀","cost":{"wood":1,"crude_iron":2},"gain":{"scissors":1}},
	"pickaxe": {"name":"镐子","cost":{"wood":1,"stone":2},"gain":{"pickaxe":1}},
	"building_bench": {"name":"建筑台","cost":{"wood":4,"stone":5},"gain":{"building_bench":1}},
	"iron_bucket": {"name":"铁桶","cost":{"crude_iron":3},"gain":{"iron_bucket":1}},
	"bow": {"name":"弓","cost":{"wood":5,"crude_iron":2},"gain":{"bow":1}},
	"stone_axe":{"name":"石斧","cost":{"wood":1,"stone":2},"gain":{"stone_axe":1}},
	"stone_sword":{"name":"石剑","cost":{"wood":1,"stone":2},"gain":{"stone_sword":1}},
	"wood_sword":{"name":"木剑","cost":{"wood":3},"gain":{"wood_sword":1}},
	"iron_sword":{"name":"铁剑","cost":{"wood":1,"crude_iron":2},"gain":{"iron_sword":1}},
	"iron_axe":{"name":"铁斧","cost":{"wood":1,"crude_iron":2},"gain":{"iron_axe":1}},
	"arrow":{"name":"箭×10","cost":{"wood":2,"crude_iron":1},"gain":{"arrow":10}}}
var crafts := CraftQueue.new()
var session: Node
var smelting := {"remaining":0.0,"ready":0}
var smith_smelting := {"remaining":0.0,"ready":0}
var opened := false
var mode := ""
var fixture: Node2D
func start(controller: Node) -> void:
	session = controller
func allowed(actor: CharacterBody2D) -> bool:
	return not actor.dead and not session.overview and not session.menu_paused and session.persistence.ready_to_save and not session.persistence.restoring and not session.persistence.restore_queued
func commit(before: Dictionary, text: String) -> bool:
	if not session.persistence.save_now():
		session.inventory.apply_data(before)
		session.persistence.restore_session(before.session)
		message.emit("保存失败，本次材料、建筑和物品变化已撤销。")
		return false
	session.inventory.changed.emit()
	message.emit(text)
	return true
func context() -> Dictionary:
	var actor: CharacterBody2D = session.world.active_resident
	return session.grounds.nearby(actor) if actor.room_id == "" else session.interiors.context(actor)
func open_near() -> void:
	if not allowed(session.world.active_resident): return
	var near := context()
	var kind := str(near.get("id",""))
	if kind not in ["workbench","building_bench","stove"]:
		message.emit("靠近工作台按 E 合成；灶台旁 T 冶炼；建筑台旁 E 建造。")
		return
	fixture = near.fixture
	mode = "smelt" if kind == "stove" else ("build" if kind == "building_bench" else "craft")
	if kind == "workbench" and session.world.active_resident.room_id in ["herb_house", "forest_herb_house"]: mode = "herbs"
	opened = true
	session.refresh_interface()
func close() -> void:
	opened = false
	fixture = null
	if is_instance_valid(session): session.refresh_interface()
func _valid(expected: String) -> bool:
	if not opened or mode != expected or not allowed(session.world.active_resident) or not is_instance_valid(fixture): return false
	var near := context()
	return near.get("fixture") == fixture
func perform(id: String) -> bool:
	if is_instance_valid(session.simulation): session.simulation.flush()
	if id == "craft:collect":
		if not _valid(mode): return false
		return crafts.collect(self,station_id(),session.world.active_resident.resident_id)
	if mode == "build":
		if not _valid("build"): return false
		var ok: bool = session.construction.build(session.world.active_resident,fixture,id)
		if ok: close()
		return ok
	if mode == "smelt":
		if not _valid("smelt"): return false
		if id.begins_with("repair:"): return Repairs.perform(session,id)
		if id.begins_with("smith:"):
			if session.world.active_resident.room_id!="blacksmith" or not Smith.RECIPES.has(id): return false
			return crafts.start(self,station_id(),id,Smith.RECIPES[id])
		return _smelt(id)
	var source: Dictionary = Herbs.RECIPES if mode == "herbs" else RECIPES
	if not _valid("herbs" if mode=="herbs" else "craft") or not source.has(id): return false
	return crafts.start(self,station_id(),id,source[id])
func station_id() -> String:
	return str(fixture.fixture_id) if is_instance_valid(fixture) else ""
func can_remove_fixture(item: Node2D) -> bool:
	return not crafts.jobs.has(str(item.fixture_id))
func all_recipes() -> Dictionary:
	var result := RECIPES.duplicate(true)
	result.merge(Herbs.RECIPES)
	result.merge(Smith.RECIPES)
	return result
func furnace_state() -> Dictionary:
	return smith_smelting if session.world.active_resident.room_id == "blacksmith" else smelting
func _smelt(id: String) -> bool:
	var furnace := furnace_state()
	var before: Dictionary = session.inventory.export_data()
	var actor_id: String = session.world.active_resident.resident_id
	if id == "collect":
		if furnace.ready <= 0 or not session.inventory.exchange(actor_id,{}, {"crude_iron":1}): return false
		furnace.ready -= 1
	elif id == "smelt":
		if furnace.remaining > 0 or furnace.ready > 0:
			message.emit("当前冶炼尚未结束或粗铁尚未领取。")
			return false
		if not session.inventory.exchange(actor_id,{"iron_ore":1},{}): return false
		furnace.remaining = 30.0
	else: return false
	return commit(before,"开始冶炼铁矿，需30在线秒。" if id == "smelt" else "领取粗铁×1。")
func elapse(delta: float) -> void:
	crafts.elapse(self,maxf(0,delta))
	for furnace: Dictionary in [smelting, smith_smelting]:
		if furnace.remaining <= 0: continue
		furnace.remaining = maxf(0,float(furnace.remaining)-maxf(0,delta))
		if furnace.remaining <= 0:
			furnace.ready += 1
			message.emit("粗铁已炼好，请到投入铁矿的炉旁领取。")
func gather_sand() -> bool:
	var actor: CharacterBody2D = session.world.active_resident
	if not allowed(actor) or actor.room_id != "": return false
	if actor.position.x < 0:
		message.emit("森林没有可装取的沙子，请到沙漠或河东岸取沙。")
		return false
	var bounds := Rect2(actor.position-Vector2(2,2),Vector2(4,4))
	if session.grounds.land_error(bounds,actor,false) != "" and session.world.nearest_point(actor.position) != "river":
		message.emit("在沙漠空沙地或河岸用铁桶装沙，不能在建筑或农田中挖取。")
		return false
	var before: Dictionary = session.inventory.export_data()
	if not session.inventory.exchange(actor.resident_id,{"iron_bucket":1},{"sand_bucket":1}):
		message.emit("需要一个空铁桶。")
		return false
	return commit(before,"获得一桶沙子，铁桶内已装满。")
func _cost_text(cost: Dictionary) -> String:
	var names: PackedStringArray = []
	for id: String in cost: names.append("%s×%d" % [session.inventory.Catalog.ITEMS[id].name,cost[id]])
	return "＋".join(names)
func snapshot() -> Dictionary:
	var recipes: Array = []
	var furnace := furnace_state()
	if not opened: return {"open":false}
	var source: Dictionary = session.construction.Catalog.BUILDINGS if mode == "build" else (Herbs.RECIPES if mode=="herbs" else RECIPES)
	if mode == "smelt":
		recipes = [{"id":"smelt","name":"开始冶炼","detail":"铁矿×1 → 粗铁×1 · 30在线秒","enabled":furnace.remaining<=0 and furnace.ready==0},
			{"id":"collect","name":"领取粗铁","detail":"剩余 %.1f 秒 · 可领%d个" % [furnace.remaining,furnace.ready],"enabled":furnace.ready>0}]
		if session.world.active_resident.room_id == "blacksmith":
			recipes.append({"id":"repair_hint","name":"损坏武器修复","detail":"石制（含镐子）：石头×1；铁制：粗铁×1","enabled":false})
			recipes.append_array(Repairs.options(session))
			for id: String in Smith.RECIPES:
				var r: Dictionary = Smith.RECIPES[id]
				recipes.append({"id":id,"name":"合成"+str(r.name),"detail":_cost_text(r.cost),"enabled":true})
	else:
		for id: String in source:
			var r: Dictionary = source[id]
			recipes.append({"id":id,"name":r.name,"detail":_cost_text(r.cost),"enabled":true})
	var job: Dictionary = crafts.jobs.get(station_id(),{}).duplicate(true)
	var registered := all_recipes()
	for r: Dictionary in recipes:
		var recipe: Dictionary = registered.get(str(r.id),{})
		var group := "material" if str(r.id) in ["smelt","collect"] else "weapon"
		if mode == "build": group = "furniture"
		elif not recipe.is_empty(): group = Categories.group(str(recipe.gain.keys()[0]))
		r["category"] = group
		if not recipe.is_empty():
			r["ingredients"] = []
			for item: String in recipe.cost:
				var have := 0
				for slot: Dictionary in session.inventory.ensure_bag(session.world.active_resident.resident_id):
					if slot.get("item","")==item: have += int(slot.count)
				r.ingredients.append({"item":item,"name":session.inventory.Catalog.ITEMS[item].name,"need":recipe.cost[item],"have":have})
			r["duration"] = 60
			r.enabled = job.is_empty() and session.inventory.exchange(session.world.active_resident.resident_id,recipe.cost,recipe.gain,false)
	if not job.is_empty() and float(job.remaining)<=0:
		recipes.append({"id":"craft:collect","name":"领取："+str(job.name),"detail":"背包满时暂存的成品；不再扣材料。","category":"all","enabled":true})
	return {"open":true,"mode":mode,"station":station_id(),"job":job,"title":"建筑台 · 投入背包材料建造" if mode=="build" else ("草药屋 · 汤剂合成（返还空杯）" if mode=="herbs" else (("铁匠铺 · 冶炼、修复与装备" if session.world.active_resident.room_id == "blacksmith" else "灶台 · 粗铁冶炼") if mode=="smelt" else "工作台 · 合成")),"recipes":recipes}
func export_state() -> Dictionary:
	var data := smelting.duplicate(true)
	data["blacksmith"] = smith_smelting.duplicate(true)
	data["craft_jobs"] = crafts.jobs.duplicate(true)
	return data
func restore(data: Dictionary) -> void:
	opened = false
	fixture = null
	crafts.restore(data.get("craft_jobs",{}),all_recipes())
	smelting = {"remaining":clampf(float(data.get("remaining",0)),0,30),"ready":clampi(int(data.get("ready",0)),0,1)}

	var smith: Dictionary = data.get("blacksmith", {})
	smith_smelting = {"remaining":clampf(float(smith.get("remaining",0)),0,30),"ready":clampi(int(smith.get("ready",0)),0,1)}
