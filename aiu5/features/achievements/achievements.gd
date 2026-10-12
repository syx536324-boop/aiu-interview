# Owns persistent, per-character achievement completion and once-only magic rewards.
extends Node
const Catalog := preload("res://features/achievements/catalog.gd")
var session: Node
var definitions: Dictionary = Catalog.entries()
var completed: Dictionary = {}
func start(controller: Node) -> void:
	session = controller
	session.inventory.save_hook = save_to
func discover(actor_id: String, item: String, held := 1) -> bool:
	var key := "item:"+Catalog.item_key(item)
	if not definitions.has(key) or not is_instance_valid(session.magic._actor(actor_id)): return false
	# The starting loadout is not a discovery; only holding more than it counts.
	if held <= Catalog.starting_count(item): return false
	var done: Dictionary = completed.get(actor_id,{})
	if done.has(key): return false
	if not session.magic.credit_points(actor_id,Catalog.REWARD): return false
	done[key] = true
	completed[actor_id] = done
	return true
func collect_discoveries() -> int:
	var count := 0
	for actor in session.world.controllable:
		var id: String = actor.resident_id
		# Compare total holdings per item against the starting grant before calling it a discovery.
		var tally: Dictionary = {}
		for record: Dictionary in session.inventory.ensure_bag(id):
			if record.is_empty(): continue
			var item_name := str(record.item)
			tally[item_name] = int(tally.get(item_name,0)) + int(record.get("count",1))
		for item_name: String in tally:
			if discover(id,item_name,int(tally[item_name])): count+=1
		var state: Dictionary = session.magic.ensure(id)
		for item in state.equipment.values():
			if str(item)!="" and discover(id,str(item)): count+=1
		if not state.torch.is_empty() and discover(id,"torch"): count+=1
	for event: Dictionary in session.inventory.gift_events.values():
		var species := str(event.get("item",""))
		# Older gift events contain only the eighteen-class model index.
		if species=="" and int(event.get("class_id",-1)) in [6,7]: species="bird" if int(event.class_id)==6 else "dog"
		if species in ["bird","dog"] and discover(str(event.get("actor","")),species): count+=1
	return count
func save_to(path: String) -> Error:
	if not is_instance_valid(session.persistence) or session.persistence.restoring:
		return session.inventory.write_file(path,session.inventory.export_data())
	if is_instance_valid(session.simulation): session.simulation.flush()
	var previous := completed.duplicate(true)
	var magic_before: Dictionary = session.magic.states.duplicate(true)
	var earned := collect_discoveries()
	var error: Error = session.inventory.write_file(path,session.inventory.export_data())
	if error!=OK:
		completed = previous
		session.magic.states = magic_before
	elif earned>0:
		session._set_notice("完成%d项首次物品成就，共获得%d魔法点。" % [earned,earned*Catalog.REWARD])
	return error
func complete(actor_id: String, achievement_id: String) -> bool:
	if not definitions.has(achievement_id) or session.magic._error(actor_id)!="": return false
	if is_instance_valid(session.simulation): session.simulation.flush()
	var entries: Dictionary = completed.get(actor_id,{})
	if entries.has(achievement_id): return false
	var before: Dictionary = session.inventory.export_data()
	if not session.magic.credit_points(actor_id,Catalog.REWARD): return false
	entries[achievement_id] = true
	completed[actor_id] = entries
	return session.production.commit(before,"完成成就，获得25魔法点。")
func snapshot(actor_id: String) -> Dictionary:
	var entries: Array = []
	var done: Dictionary = completed.get(actor_id,{})
	for id: String in definitions:
		entries.append({"id":id,"name":str(definitions[id].get("name",id)),"description":str(definitions[id].get("description","")),"completed":done.has(id),"reward":Catalog.REWARD})
	return {"entries":entries,"completed":done.size(),"total":definitions.size(),"reward":Catalog.REWARD}
func export_state() -> Dictionary:
	return {"completed":completed.duplicate(true)}
func restore(data: Dictionary) -> void:
	completed.clear()
	var records: Variant = data.get("completed",{})
	if not records is Dictionary: return
	for actor in session.world.controllable:
		var entries: Variant = records.get(actor.resident_id,{})
		if entries is Dictionary:
			var clean := {}
			for id in entries:
				if id is String and entries[id]==true: clean[id]=true
			completed[actor.resident_id] = clean
