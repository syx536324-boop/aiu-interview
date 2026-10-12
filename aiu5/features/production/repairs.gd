# Offers and atomically repairs individual broken stone/iron weapons at the smith furnace.
extends RefCounted
const Wear := preload("res://features/combat/durability.gd")
const MATERIALS := {"knife":"stone", "iron_knife":"crude_iron", "pickaxe":"stone", "stone_axe":"stone", "stone_sword":"stone", "iron_axe":"crude_iron", "iron_sword":"crude_iron"}
static func _weapon(session: Node, id: String) -> Dictionary:
	var actor_id: String = session.world.active_resident.resident_id
	if id == "repair:equipped":
		var state: Dictionary = session.magic.ensure(actor_id)
		return {"item":state.equipment.weapon,"wear":state.weapon_wear,"index":-1,"location":"已装备"}
	var parts := id.split(":")
	if parts.size()!=3 or parts[0]!="repair" or parts[1]!="bag" or not parts[2].is_valid_int(): return {}
	var index := int(parts[2])
	var bag: Array = session.inventory.ensure_bag(actor_id)
	if index<0 or index>=bag.size() or bag[index].is_empty(): return {}
	return {"item":bag[index].item,"wear":bag[index],"index":index,"location":"背包第%d格" % (index+1)}
static func _broken(record: Dictionary) -> bool:
	return not record.is_empty() and MATERIALS.has(record.item) and Wear.normalize(record.wear).durability == 0
static func options(session: Node) -> Array:
	var result: Array = []
	var ids: Array[String] = ["repair:equipped"]
	var actor_id: String = session.world.active_resident.resident_id
	for i in range(session.inventory.ensure_bag(actor_id).size()): ids.append("repair:bag:%d" % i)
	for id: String in ids:
		var record := _weapon(session,id)
		if not _broken(record): continue
		var material: String = MATERIALS[record.item]
		result.append({"id":id,"name":"修复%s · %s" % [session.inventory.Catalog.ITEMS[record.item].name,record.location],
			"detail":"%s×1 → 耐久恢复40/40" % session.inventory.Catalog.ITEMS[material].name,
			"enabled":session.inventory.has_item(actor_id,material)})
	return result
static func perform(session: Node, id: String) -> bool:
	if session.world.active_resident.room_id!="blacksmith" or not session.production._valid("smelt"): return false
	var record := _weapon(session,id)
	if not _broken(record):
		session.production.message.emit("只能修复损坏的石制或铁制武器。")
		return false
	var before: Dictionary = session.inventory.export_data()
	var actor_id: String = session.world.active_resident.resident_id
	var material: String = MATERIALS[record.item]
	if not session.inventory.exchange(actor_id,{material:1},{}):
		session.production.message.emit("修复需要%s×1，材料不足。" % session.inventory.Catalog.ITEMS[material].name)
		return false
	# exchange replaces the bag copy; reacquire its exact slot before resetting the instance.
	if record.index<0: session.magic.ensure(actor_id).weapon_wear=Wear.normalize({"durability":40,"uses":0}.merged(Wear.Origin.fields(record.wear)))
	else: session.inventory.ensure_bag(actor_id)[record.index].merge(Wear.normalize(),true)
	return session.production.commit(before,"%s已修复，耐久恢复40/40。" % session.inventory.Catalog.ITEMS[record.item].name)
