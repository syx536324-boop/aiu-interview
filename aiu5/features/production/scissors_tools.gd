# Owns nonlethal sheep shearing, independent grass-vine harvests and hide cutting transactions.
extends RefCounted
var production: Node
var shear_left: Dictionary={}
var vine_left: Dictionary={}
func available() -> bool:
	var s: Node=production.session
	var id: String=s.world.active_resident.resident_id
	return s.inventory.has_item(id,"scissors") or s.inventory.has_item(id,"magic_scissors") or s.magic.ensure(id).equipment.weapon=="magic_scissors"
func options() -> Array:
	var s: Node=production.session
	var actor: Node=s.world.active_resident
	var choices: Array=[{"id":"scissors:hide","name":"裁剪牛皮 → 皮革×2","category":"tool","detail":"需要随身剪刀、牛皮×1；不消耗剪刀。","enabled":available() and s.inventory.exchange(actor.resident_id,{"cowhide":1},{"leather":2},false)}]
	if actor.room_id=="":
		for animal: Node in s.livestock.animals:
			if animal.species!="sheep" or animal.hp<=0 or actor.position.distance_to(animal.position)>24: continue
			var remaining := float(shear_left.get(animal.animal_id,0))
			choices.append({"id":"scissors:shear:"+animal.animal_id,"name":"剪羊毛×2 · "+s.livestock.label(animal),"category":"tool","detail":"成年羊，不伤害羊；每只每5在线分钟一次。剩余%.1f秒。" % remaining,"enabled":available() and animal.adult() and remaining<=0 and s.inventory.exchange(actor.resident_id,{}, {"wool":2},false)})
		for key: String in s.forest.loaded:
			var node: Node=s.forest.loaded[key]
			if node.record.kind!="grass" or actor.position.distance_to(node.position)>23: continue
			var remaining := float(vine_left.get(key,0))
			choices.append({"id":"scissors:vine:"+key,"name":"剪藤条×1","category":"tool","detail":"草丛每2在线分钟一次，与种子刷新独立。剩余%.1f秒。" % remaining,"enabled":available() and remaining<=0 and s.inventory.exchange(actor.resident_id,{}, {"vine":1},false)})
	return choices
func perform(action: String) -> bool:
	var s: Node=production.session
	var actor: Node=s.world.active_resident
	if not production.allowed(actor) or not available(): return false
	var valid := false
	for option: Dictionary in options():
		if option.id==action and option.enabled: valid=true; break
	if not valid: production.message.emit("缺少材料、未成年、目标太远或尚在采集冷却中，未消耗物品。"); return false
	var before: Dictionary=s.inventory.export_data()
	var text := ""
	if action=="scissors:hide":
		if not s.inventory.exchange(actor.resident_id,{"cowhide":1},{"leather":2}): return false
		text="裁剪牛皮×1，得到皮革×2。"
	elif action.begins_with("scissors:shear:"):
		var id := action.trim_prefix("scissors:shear:")
		if not s.inventory.exchange(actor.resident_id,{}, {"wool":2}): return false
		shear_left[id]=300.0
		var animal: Node=s.livestock.find_animal(id)
		if is_instance_valid(animal): animal.set_meta("sheared",true); animal.queue_redraw()
		text="剪下羊毛×2，羊未受伤；5分钟后可再次剪毛。"
	elif action.begins_with("scissors:vine:"):
		var id := action.trim_prefix("scissors:vine:")
		if not s.inventory.exchange(actor.resident_id,{}, {"vine":1}): return false
		vine_left[id]=120.0
		text="剪下藤条×1，种子刷新不受影响。"
	else: return false
	return production.commit(before,text)
func advance(delta: float) -> void:
	for timers: Dictionary in [shear_left,vine_left]:
		for id: String in timers.keys():
			timers[id]=maxf(0,float(timers[id])-maxf(0,delta))
			if timers[id]<=0.000001: timers.erase(id)
	_refresh_sheep()
func _refresh_sheep() -> void:
	for animal: Node in production.session.livestock.animals:
		if animal.species!="sheep": continue
		var next: bool=shear_left.has(animal.animal_id)
		if bool(animal.get_meta("sheared",false))!=next: animal.set_meta("sheared",next); animal.queue_redraw()
func export_state() -> Dictionary:
	return {"shear_left":shear_left.duplicate(),"vine_left":vine_left.duplicate()}
func restore(data: Dictionary) -> void:
	shear_left.clear(); vine_left.clear()
	for field: String in ["shear_left","vine_left"]:
		var timers: Variant=data.get(field,{})
		if not timers is Dictionary: continue
		var limit := 300.0 if field=="shear_left" else 120.0
		for id: String in timers:
			var remaining := clampf(float(timers[id]),0,limit)
			if remaining>0: get(field)[id]=remaining
	_refresh_sheep()
