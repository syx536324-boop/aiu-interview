# Owns persistent, per-character achievement completion and once-only magic rewards.
extends Node
const Catalog := preload("res://features/achievements/catalog.gd")
var session: Node
var definitions: Dictionary = Catalog.ENTRIES.duplicate(true)
var completed: Dictionary = {}
func start(controller: Node) -> void:
	session = controller
func complete(actor_id: String, achievement_id: String) -> bool:
	if not definitions.has(achievement_id) or session.magic._error(actor_id)!="": return false
	if is_instance_valid(session.simulation): session.simulation.flush()
	var entries: Dictionary = completed.get(actor_id,{})
	if entries.has(achievement_id): return false
	var before: Dictionary = session.inventory.export_data()
	if not session.magic.credit_points(actor_id,Catalog.REWARD): return false
	entries[achievement_id] = true
	completed[actor_id] = entries
	return session.production.commit(before,"完成成就，获得100魔法点。")
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
