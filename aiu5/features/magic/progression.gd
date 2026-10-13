# Owns altar awakening, persistent magic progression, skill spending and atomic equipment transfers.
extends Node

signal message(text: String)
const Catalog := preload("res://features/magic/catalog.gd")
var session: Node
var states: Dictionary = {}
const SkillRuntime := preload("res://features/magic/skills.gd")
const SkillCatalog := preload("res://features/magic/skill_catalog.gd")
var skills: Node

func start(controller: Node) -> void:
	session = controller
	for actor in session.world.controllable: ensure(actor.resident_id)
	skills=SkillRuntime.new()
	add_child(skills)
	skills.start(self)

func ensure(id: String) -> Dictionary:
	if not states.has(id): states[id] = Catalog.fresh()
	return states[id]

func defense(id: String) -> int:
	return Catalog.Armor.total_defense(ensure(id).equipment)

func damage_rate(id: String) -> float:
	return Catalog.Armor.damage_rate(ensure(id).equipment)*skills.damage_rate(id)

func protection_snapshot(id: String) -> Dictionary:
	var points := defense(id)
	return {"defense":points,"armor_reduction_percent":points*5,"reduction_percent":snappedf((1.0-damage_rate(id))*100.0,0.1),"shield_active":skills.damage_rate(id)<1.0}

func max_mana(id: String) -> int:
	return Catalog.mana_limit(int(ensure(id).level))

func _actor(id: String) -> CharacterBody2D:
	for actor in session.world.controllable:
		if actor.resident_id == id: return actor
	return null

func _error(id: String) -> String:
	var actor := _actor(id)
	if not is_instance_valid(actor): return "找不到这名可操控角色。"
	if session.overview or session.menu_paused: return "暂停期间无法修改属性。"
	if actor.dead: return "阵亡角色的属性可查看，复活后才能修改。"
	if not session.persistence.ready_to_save or session.persistence.restoring or session.persistence.restore_queued:
		return "正在恢复存档，请稍后再试。"
	return ""

func awakening_error(id: String) -> String:
	var error := _error(id)
	if error != "": return error
	var actor := _actor(id)
	if actor != session.world.active_resident: return "请先切换为该角色，再前往祭台觉醒。"
	if ensure(id).element != "": return "已经觉醒一种属性，不能重复觉醒或更换。"
	if actor.room_id == "":
		for point_id in ["altar", "forest_altar"]:
			var point: Dictionary = session.world.point_info(point_id)
			if actor.position.distance_to(point.position) <= float(point.radius): return ""
	return "请到祭台正面，按 R 选择觉醒属性。"

func _begin(id: String) -> bool:
	if is_instance_valid(session.simulation): session.simulation.flush()
	var error := _error(id)
	if error != "": return _reject(error)
	return true

func _reject(text: String) -> bool:
	message.emit(text)
	return false

func _commit(id: String, previous: Dictionary, bag: Array, text: String, vitals_before: Dictionary = {}) -> bool:
	if not session.persistence.save_now():
		states[id] = previous
		session.inventory.bags[id] = bag
		if not vitals_before.is_empty(): session.vitals.states[id]=vitals_before
		session.vitals._sync_actors()
		session.inventory.changed.emit()
		return _reject("存档失败，属性和装备操作已撤销，物品与点数保留。")
	session.inventory.changed.emit()
	message.emit(text)
	return true

func awaken(id: String, element: String) -> bool:
	if not _begin(id): return false
	var error := awakening_error(id)
	if error != "": return _reject(error)
	if not Catalog.ELEMENTS.has(element): return _reject("请选择木、水、火、土中的一种。")
	var previous := ensure(id).duplicate(true)
	var bag: Array = session.inventory.ensure_bag(id).duplicate(true)
	ensure(id).element = element
	Catalog.add_points(ensure(id),int(ensure(id).pending_points))
	ensure(id).pending_points=0
	return _commit(id, previous, bag, "%s觉醒了%s属性，魔法等级 lv.%d；已结算此前获得的魔法点。" % [_actor(id).resident_name, Catalog.ELEMENTS[element].name,ensure(id).level])

func credit_points(id: String, amount: int) -> bool:
	# This mutation deliberately does not save: the caller commits rewards with their triggering action.
	if not is_instance_valid(_actor(id)) or amount<=0: return false
	var state := ensure(id)
	if state.element=="": state.pending_points+=amount
	else: Catalog.add_points(state,amount)
	return true
func award_points(id: String, amount: int) -> bool:
	if not _begin(id): return false
	var previous := ensure(id).duplicate(true)
	var bag: Array=session.inventory.ensure_bag(id).duplicate(true)
	if not credit_points(id,amount): return false
	return _commit(id,previous,bag,"获得%d魔法点%s。" % [amount,"，觉醒后结算" if ensure(id).element=="" else ""])

func unlock(id: String, skill: String) -> bool:
	if not _begin(id): return false
	var state := ensure(id)
	var index := Catalog.TRUNK.find(skill)
	if state.element == "" or index < 0: return _reject("请先觉醒，并选择有效的主干技能。")
	if state.unlocked.has(skill): return _reject("该技能已经点亮，不会重复消耗。")
	if index != state.unlocked.size(): return _reject("必须从主干第一个技能开始，依次点亮。")
	if state.skill_points < Catalog.SKILL_COST: return _reject("技能点不足，每个技能需要10点。")
	var previous := state.duplicate(true)
	var bag: Array = session.inventory.ensure_bag(id).duplicate(true)
	var vitals_before: Dictionary=session.vitals.ensure(id).duplicate(true)
	state.skill_points -= Catalog.SKILL_COST
	state.unlocked.append(skill)
	if index==0 and state.element=="wood": session.vitals.heal(id,1)
	session.vitals._sync_actors()
	return _commit(id, previous, bag, "已点亮%s，消耗10技能点。" % SkillCatalog.entry(str(state.element),index+1).name, vitals_before)

func claim_gear(id: String) -> bool:
	if not _begin(id): return false
	return _reject("装备改为铁匠铺用皮革或粗铁制作，也可由摄像头赐予。")

func equip(id: String, slot: String, item: String, bag_index := -1) -> bool:
	if not _begin(id): return false
	if not Catalog.EQUIPMENT.has(slot) or (item != "" and not Catalog.Armor.fits(slot,item)):
		return _reject("这件装备不能放入该部位。")
	var state := ensure(id)
	var old := str(state.equipment[slot])
	if old == item and bag_index < 0: return false
	var previous := state.duplicate(true)
	var bag: Array = session.inventory.ensure_bag(id).duplicate(true)
	var outgoing: Dictionary = state.equipment_records.get(slot, {"item":old,"count":1} if old != "" else {})
	var exchanged: Dictionary = session.inventory.swap_armor(id, item, outgoing, bag_index)
	if not exchanged.ok: return _reject("缺少装备或背包已满，原装备保持不变。")
	state.equipment[slot] = item
	state.equipment_records[slot] = exchanged.record
	return _commit(id, previous, bag, "%s已%s%s。" % [_actor(id).resident_name, "卸下" if item == "" else "穿戴", Catalog.EQUIPMENT[slot].name])

func equip_weapon(id: String, item: String, bag_index := -1) -> bool:
	if not _begin(id): return false
	if item != "" and item not in Catalog.WEAPONS: return _reject("这件物品不能装备为武器。")
	var state := ensure(id)
	var old := str(state.equipment.weapon)
	if old == "" and item == "": return false
	var previous := state.duplicate(true)
	var bag: Array = session.inventory.ensure_bag(id).duplicate(true)
	var exchange: Dictionary = session.inventory.swap_weapon(id,item,old,state.weapon_wear,bag_index)
	if not exchange.ok:
		return _reject("缺少武器或背包已满，原武器保持不变。")
	state.equipment.weapon = item
	state.weapon_wear = exchange.wear
	return _commit(id,previous,bag, "已卸下武器。" if item == "" else "已装备%s，右键点击敌人 / J 攻击；E 使用采集工具。" % session.inventory.Catalog.ITEMS[item].name)

func weapon_usable(id: String) -> bool:
	if _error(id) != "": return false
	var state := ensure(id)
	if state.equipment.weapon == "": return false
	if int(state.weapon_wear.durability) <= 0:
		message.emit("武器耐久为0，已损坏，请更换武器。")
		return false
	return true

func consume_weapon(id: String) -> bool:
	if not weapon_usable(id): return false
	return Catalog.Wear.consume(ensure(id).weapon_wear)

func weapon_snapshot(id: String) -> Dictionary:
	var item := str(ensure(id).equipment.weapon)
	return {"item":item, "magical":Catalog.Wear.Origin.magical(ensure(id).weapon_wear), "name":session.inventory.Catalog.ITEMS[item].name if item != "" else "空", "attack":Catalog.Gear.damage(item)+(skills.attack_bonus(id) if item!="" else 0), "editable":_error(id)=="", "wear":ensure(id).weapon_wear.duplicate(), "durability_text":Catalog.Wear.describe(ensure(id).weapon_wear)+Catalog.Wear.Origin.describe(ensure(id).weapon_wear)}

func snapshot(id: String) -> Dictionary:
	var actor := _actor(id)
	if not is_instance_valid(actor): return {"open": false}
	var state := ensure(id)
	var result := state.duplicate(true)
	result.merge({"open": true, "id": id, "name": actor.resident_name, "sheet": actor.sheet,
		"dead": actor.dead, "editable": _error(id) == "", "required": Catalog.required(int(state.level)),
		"element_name": Catalog.ELEMENTS[state.element].name if state.element != "" else "未觉醒",
		"color": Catalog.ELEMENTS[state.element].color if state.element != "" else "a99b82",
		"awakening_available": awakening_error(id) == "", "awakening_hint": awakening_error(id)})
	var gear: Array[Dictionary] = []
	for slot: String in Catalog.EQUIPMENT:
		var item := str(Catalog.EQUIPMENT[slot].item)
		gear.append({"slot": slot, "name": Catalog.EQUIPMENT[slot].name, "item": state.equipment[slot],
			"magical":Catalog.Wear.Origin.magical(state.equipment_records.get(slot,{})),
			"available_item": item, "available": session.inventory.has_item(id, item),
			"equipped_name":(session.inventory.Catalog.ITEMS[state.equipment[slot]].name+Catalog.Wear.Origin.describe(state.equipment_records.get(slot,{}))) if state.equipment[slot]!="" else "空",
			"choices":_gear_choices(id,slot),"defense":Catalog.Armor.defense(str(state.equipment[slot])),"protection_description":Catalog.Armor.describe(str(state.equipment[slot]))})
	result["gear"] = gear
	result["protection"] = protection_snapshot(id)
	result["achievements"] = session.achievements.snapshot(id) if is_instance_valid(session.achievements) else {"entries":[],"completed":0,"total":0,"reward":25}
	var skills: Array[Dictionary] = []
	for i in range(Catalog.TRUNK.size()):
		var skill: String = Catalog.TRUNK[i]
		var entry: Dictionary=SkillCatalog.entry(str(state.element),i+1)
		entry.merge({"id":skill,"learned":state.unlocked.has(skill),"can_unlock":result.editable and state.element!="" and i==state.unlocked.size() and state.skill_points>=Catalog.SKILL_COST})
		skills.append(entry)
	result["skills"] = skills
	result["skill_effects"]=self.skills.snapshot(id)
	result["mana"]=session.vitals.ensure(id).mana
	result["max_mana"]=max_mana(id)
	result["branches_ready"] = state.unlocked.size() == Catalog.TRUNK.size()
	return result

func _gear_choices(id: String, slot: String) -> Array:
	var result: Array = []
	var bag: Array = session.inventory.ensure_bag(id)
	for item: String in Catalog.Armor.SLOTS[slot]:
		var found := false
		for i in range(bag.size()):
			if bag[i].get("item", "") != item: continue
			found = true
			result.append({"item":item,"name":session.inventory.Catalog.ITEMS[item].name+Catalog.Wear.Origin.describe(bag[i]),"available":true,"bag_index":i})
		if not found: result.append({"item":item,"name":session.inventory.Catalog.ITEMS[item].name,"available":false,"bag_index":-1})
	return result

func export_state() -> Dictionary:
	return {"version": 2, "residents": states.duplicate(true), "effects":skills.export_state()}

func restore(data: Dictionary) -> void:
	states.clear()
	var residents: Variant = data.get("residents", {})
	for actor in session.world.controllable:
		var source: Variant = residents.get(actor.resident_id, {}) if residents is Dictionary else {}
		states[actor.resident_id] = Catalog.restore_state(source if source is Dictionary else {})

	skills.restore(data.get("effects",{}))
